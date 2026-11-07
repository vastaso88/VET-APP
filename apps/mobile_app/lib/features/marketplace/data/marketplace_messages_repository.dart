import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../billing/data/subscription_required_signal.dart';
import '../domain/marketplace_conversation.dart';

/// The backend cannot be asked (no address, no session, network, server error).
class MessagesUnavailableException implements Exception {
  const MessagesUnavailableException();
}

/// Missing, someone else's, or an ad that cannot be written about (404).
class ConversationNotFoundException implements Exception {
  const ConversationNotFoundException();
}

/// Readable but no longer writable (409): the conversation must be read again.
class ConversationClosedException implements Exception {
  const ConversationClosedException();
}

/// Too many new conversations today (429).
class NewConversationLimitException implements Exception {
  const NewConversationLimitException(this.limit);

  final int limit;
}

/// The trial is over (402): the owner has already been sent to the paywall.
class MessagesPlanRequiredException implements Exception {
  const MessagesPlanRequiredException();
}

/// Messages live only on the backend (`/marketplace/...conversation...`), which
/// holds every rule. Nothing is kept on the phone: the only local state is the
/// unread number (marketplace_unread_store.dart), emptied at sign-out.
class MarketplaceMessagesRepository {
  MarketplaceMessagesRepository({
    http.Client? httpClient,
    AppRuntimeConfigLoader? configLoader,
    String? Function()? tokenProvider,
  })  : _http = httpClient,
        _configLoader = configLoader ?? const AppRuntimeConfigLoader(),
        _tokenProvider = tokenProvider ?? CurrentUser.accessToken;

  final http.Client? _http;
  final AppRuntimeConfigLoader _configLoader;
  final String? Function() _tokenProvider;

  static const _timeout = Duration(seconds: 20);

  Future<List<MarketplaceConversation>> listConversations() async {
    final json = await _call('GET', '/marketplace/conversations');
    return (json['conversations'] as List<dynamic>? ?? const [])
        .map((row) => MarketplaceConversation.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadTotal() async {
    final json = await _call('GET', '/marketplace/conversations/unread-count');
    return (json['unread_total'] as num?)?.toInt() ?? 0;
  }

  /// The caller's own conversation about an ad, null if they never wrote.
  Future<MarketplaceConversation?> conversationForListing(String listingId) async {
    final json = await _call('GET', '/marketplace/listings/$listingId/conversation');
    final row = json['conversation'];
    return row == null ? null : MarketplaceConversation.fromJson(row as Map<String, dynamic>);
  }

  Future<ConversationThread> readThread(String conversationId) async {
    final json = await _call('GET', '/marketplace/conversations/$conversationId');
    return ConversationThread(
      conversation:
          MarketplaceConversation.fromJson(json['conversation'] as Map<String, dynamic>),
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .map((row) => MarketplaceMessage.fromJson(row as Map<String, dynamic>))
          .toList(),
    );
  }

  /// The first message opens the conversation: nothing exists before it, so the
  /// seller never sees an empty chat and the daily limit counts real messages.
  Future<SentMarketplaceMessage> writeToSeller(String listingId, String text) async {
    return _sent(await _call(
      'POST',
      '/marketplace/listings/$listingId/conversations',
      body: {'text': text},
    ));
  }

  Future<SentMarketplaceMessage> sendMessage(String conversationId, String text) async {
    return _sent(await _call(
      'POST',
      '/marketplace/conversations/$conversationId/messages',
      body: {'text': text},
    ));
  }

  Future<void> markRead(String conversationId) async {
    await _call('POST', '/marketplace/conversations/$conversationId/read');
  }

  Future<MarketplaceConversation> block(String conversationId) async {
    final json = await _call('POST', '/marketplace/conversations/$conversationId/block');
    return MarketplaceConversation.fromJson(json['conversation'] as Map<String, dynamic>);
  }

  Future<MarketplaceConversation> unblock(String conversationId) async {
    final json = await _call('DELETE', '/marketplace/conversations/$conversationId/block');
    return MarketplaceConversation.fromJson(json['conversation'] as Map<String, dynamic>);
  }

  Future<void> report(String conversationId, String reason) async {
    await _call(
      'POST',
      '/marketplace/conversations/$conversationId/report',
      body: {'reason': reason},
    );
  }

  SentMarketplaceMessage _sent(Map<String, dynamic> json) => SentMarketplaceMessage(
        conversation:
            MarketplaceConversation.fromJson(json['conversation'] as Map<String, dynamic>),
        message: MarketplaceMessage.fromJson(json['message'] as Map<String, dynamic>),
      );

  Future<Map<String, dynamic>> _call(String method, String path, {Object? body}) async {
    final config = _configLoader.load();
    final baseUrl = config.apiBaseUrl.trim();
    final token = _tokenProvider();
    final hasToken = token != null && token.isNotEmpty;
    // Local development without Supabase has no sessions: the local backend knows
    // one user and asks for no token. A real build without a session asks nothing.
    if (baseUrl.isEmpty || (!hasToken && config.supabaseUrl.trim().isNotEmpty)) {
      throw const MessagesUnavailableException();
    }
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    if (hasToken) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await (_http ?? http.Client()).send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      throw const MessagesUnavailableException();
    }

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    if (handleSubscriptionRequired(response.statusCode)) {
      throw const MessagesPlanRequiredException();
    }
    switch (response.statusCode) {
      case 404:
        throw const ConversationNotFoundException();
      case 409:
        throw const ConversationClosedException();
      case 429:
        final limit = _dailyLimit(response);
        if (limit != null) throw NewConversationLimitException(limit);
    }
    throw const MessagesUnavailableException();
  }

  /// A 429 also comes from the general request throttle, without this field.
  int? _dailyLimit(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (json['kind'] != 'marketplace_new_conversations') return null;
      return (json['limit'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }
}
