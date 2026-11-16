import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../domain/travel_card.dart';

abstract class TravelCardsRepository {
  /// Every approved travel card. Throws [TravelCardsUnavailable] when the
  /// backend cannot be reached or refuses.
  Future<List<TravelCard>> fetchAll();
}

class TravelCardsUnavailable implements Exception {
  const TravelCardsUnavailable();
}

/// The cards come from our own backend (`GET /travel/cards`): the whole set in
/// one request with no parameter, so the countries a person looks at stay on
/// the phone and never appear in an address or a server log
/// (docs/compliance/17 A.14). The answer is kept in memory for a while (no new
/// file on the device: nothing to clear at sign-out) and shared by every
/// screen.
class BackendTravelCardsRepository implements TravelCardsRepository {
  BackendTravelCardsRepository({
    http.Client? client,
    AppRuntimeConfigLoader? configLoader,
    String? Function()? tokenProvider,
  })  : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader(),
        _tokenProvider = tokenProvider ?? CurrentUser.accessToken;

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;
  final String? Function() _tokenProvider;

  static _Cached? _cache;
  static Future<List<TravelCard>>? _inFlight;
  static const _ttl = Duration(minutes: 30);
  static const _timeout = Duration(seconds: 20);

  /// Forgets the shared answer (tests, sign-out).
  static void resetCache() {
    _cache = null;
    _inFlight = null;
  }

  @override
  Future<List<TravelCard>> fetchAll() async {
    final cached = _cache;
    if (cached != null && DateTime.now().difference(cached.at) < _ttl) return cached.cards;
    final pending = _inFlight ??= _download().whenComplete(() => _inFlight = null);
    try {
      final cards = await pending;
      _cache = _Cached(cards, DateTime.now());
      return cards;
    } on TravelCardsUnavailable {
      // An older answer beats an error page.
      if (cached != null) return cached.cards;
      rethrow;
    }
  }

  Future<List<TravelCard>> _download() async {
    final baseUrl = _configLoader.load().apiBaseUrl.trim();
    final token = _tokenProvider();
    if (baseUrl.isEmpty || token == null || token.isEmpty) throw const TravelCardsUnavailable();
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/travel/cards'), headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout);
      if (response.statusCode != 200) throw const TravelCardsUnavailable();
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return [
        for (final raw in (json['cards'] as List<dynamic>? ?? const []))
          if (TravelCard.tryParse(raw as Map<String, dynamic>) case final card?) card,
      ];
    } on TravelCardsUnavailable {
      rethrow;
    } catch (_) {
      throw const TravelCardsUnavailable();
    }
  }
}

class _Cached {
  const _Cached(this.cards, this.at);

  final List<TravelCard> cards;
  final DateTime at;
}
