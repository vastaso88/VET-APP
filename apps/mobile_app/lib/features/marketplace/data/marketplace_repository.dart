import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../l10n/l10n.dart';
import '../../location/domain/coordinates.dart';
import '../../territory/domain/territory.dart';
import '../domain/animal_policy.dart';
import '../domain/marketplace_listing.dart';
import 'listing_photo_store.dart';

/// The search radius was missing, below the minimum or above the maximum
/// ([marketplaceMinRadiusKm] to [marketplaceMaxRadiusKm]). The backend refuses such a request too; this
/// is the same rule checked before anything is asked.
class InvalidListingRadiusException implements Exception {
  const InvalidListingRadiusException(this.radiusKm);

  final double? radiusKm;

  @override
  String toString() => 'Invalid marketplace radius: $radiusKm km '
      '($marketplaceMinRadiusKm to $marketplaceMaxRadiusKm km)';
}

/// The backend (or the app's own copy of the same rule) refused the ad. The
/// message is the one to show: "Sul Mercatino si vendono solo oggetti per
/// animali, non animali." when it offers an animal.
class ListingRejectedException implements Exception {
  const ListingRejectedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// An ad cannot be published, edited or listed because the backend that
/// decides is unreachable. Ads of others are never read from the database
/// directly, so there is no fallback.
class ListingBackendUnavailableException implements Exception {
  const ListingBackendUnavailableException();

  @override
  String toString() => appL10n.marketplaceBackendUnavailable;
}

/// Thrown when someone other than the author tries to change or delete a
/// listing, or the database refused the change for that reason.
class ListingPermissionException implements Exception {
  const ListingPermissionException();

  @override
  String toString() => appL10n.marketplacePermissionDenied;
}

/// True only for the listing's author. The app-side check mirrors the
/// marketplace_listings_update_own/delete_own RLS policies, which remain
/// the real boundary.
bool canManageListing(MarketplaceListing listing, String requesterId) =>
    requesterId.isNotEmpty && listing.ownerId == requesterId;

/// Optional Supabase client; without one, a session-lifetime local list is
/// the demo/no-backend store (and the only place the demo seed appears).
/// With one, the database is the only source: no seed, and write errors
/// reach the caller instead of being swallowed.
class MarketplaceRepository {
  MarketplaceRepository({
    SupabaseClient? client,
    ListingPhotoStore? photoStore,
    http.Client? httpClient,
    AppRuntimeConfigLoader? configLoader,
    String? Function()? tokenProvider,
  })  : _client = client,
        _localOnly = false,
        _local = _sharedLocal,
        _photoStore = photoStore ?? ListingPhotoStore(client: client),
        _http = httpClient,
        _configLoader = configLoader ?? const AppRuntimeConfigLoader(),
        _tokenProvider = tokenProvider ?? CurrentUser.accessToken;

  /// Isolated local store (tests, previews): never talks to Supabase.
  MarketplaceRepository.inMemory(List<MarketplaceListing> listings)
      : _client = null,
        _localOnly = true,
        _local = List<MarketplaceListing>.of(listings),
        _photoStore = ListingPhotoStore(localOnly: true),
        _http = null,
        _configLoader = const AppRuntimeConfigLoader(),
        _tokenProvider = CurrentUser.accessToken;

  static const _table = 'marketplace_listings';
  static final List<MarketplaceListing> _sharedLocal = List<MarketplaceListing>.of(_seedListings);

  final SupabaseClient? _client;
  final bool _localOnly;
  final List<MarketplaceListing> _local;
  final ListingPhotoStore _photoStore;
  final http.Client? _http;
  final AppRuntimeConfigLoader _configLoader;
  final String? Function() _tokenProvider;

  ListingPhotoStore get photoStore => _photoStore;

  /// How long the backend gets to answer before the direct read is tried.
  static const _apiTimeout = Duration(seconds: 20);

  /// The ads a search can show: those within [radiusKm] of [center], whatever
  /// their country (near a border the ads across it count too; each one
  /// carries its seller's country). The radius must be between
  /// [marketplaceMinRadiusKm] and [marketplaceMaxRadiusKm]
  /// ([InvalidListingRadiusException] otherwise) - there is no unlimited search.
  /// In production the backend answers (`GET /marketplace/listings`, which
  /// enforces the same rules): the table is never read directly for other
  /// people's ads, so when the backend cannot be asked the search fails
  /// ([ListingBackendUnavailableException]). Without any backend or database
  /// (demo, tests) the local list answers. The result is a candidate set:
  /// `applyListingFilter` makes the exact cut.
  Future<List<MarketplaceListing>> loadNearbyListings({
    required Coordinates center,
    required double radiusKm,
  }) async {
    if (radiusKm.isNaN || radiusKm < marketplaceMinRadiusKm || radiusKm > marketplaceMaxRadiusKm) {
      throw InvalidListingRadiusException(radiusKm);
    }

    if (_localOnly) return _localNearby();

    final fromApi = await _loadNearbyFromApi(center, radiusKm);
    if (fromApi != null) return fromApi;

    if (_resolveClient() == null) return _localNearby();
    throw const ListingBackendUnavailableException();
  }

  List<MarketplaceListing> _localNearby() {
    return _local
        .where((listing) => listing.status == ListingStatus.active)
        .toList(growable: false);
  }

  /// One ad by id, through the backend (`GET /marketplace/listings/{id}`): an
  /// active ad of anyone, any ad of its author. Null when it does not exist (or
  /// is hidden from this user).
  Future<MarketplaceListing?> loadListing(String id) async {
    if (!_localOnly) {
      final result = await _callApi('GET', '/marketplace/listings/${Uri.encodeComponent(id)}');
      if (result != null) {
        if (result.statusCode == 404) return null;
        if (result.statusCode != 200) throw const ListingBackendUnavailableException();
        final json = jsonDecode(utf8.decode(result.bodyBytes)) as Map<String, dynamic>;
        return _parseRow(json['listing'] as Map<String, dynamic>);
      }
      if (_resolveClient() != null) throw const ListingBackendUnavailableException();
    }
    for (final listing in _local) {
      if (listing.id == id && listing.status == ListingStatus.active) return listing;
    }
    return null;
  }

  /// Calls the backend with the user's session; null when it cannot be asked
  /// (no address or no session) or did not answer at all (network, timeout).
  Future<http.Response?> _callApi(String method, String path, {Object? body}) async {
    final baseUrl = _configLoader.load().apiBaseUrl.trim();
    final token = _tokenProvider();
    if (baseUrl.isEmpty || token == null || token.isEmpty) return null;

    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final streamed = await (_http ?? http.Client()).send(request).timeout(_apiTimeout);
      return await http.Response.fromStream(streamed);
    } catch (_) {
      return null;
    }
  }

  /// Null when the backend can't be asked (no address or session) or didn't
  /// answer usefully (unreachable, not deployed yet, server error): the
  /// caller then reads the table directly. A refusal of the request itself
  /// (400/422) is not retried elsewhere.
  Future<List<MarketplaceListing>?> _loadNearbyFromApi(
    Coordinates center,
    double radiusKm,
  ) async {
    final query = Uri(queryParameters: {
      'latitude': center.latitude.toString(),
      'longitude': center.longitude.toString(),
      'radius_km': radiusKm.toString(),
    }).query;
    final response = await _callApi('GET', '/marketplace/listings?$query');
    if (response == null) return null;
    if (response.statusCode == 400 || response.statusCode == 422) {
      throw InvalidListingRadiusException(radiusKm);
    }
    if (response.statusCode != 200) return null;
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return _parseRows(json['listings'] as List<dynamic>? ?? const []);
    } catch (_) {
      return null;
    }
  }

  List<MarketplaceListing> _parseRows(List<dynamic> rows) {
    final listings = <MarketplaceListing>[];
    for (final row in rows) {
      final listing = _parseRow(row as Map<String, dynamic>);
      if (listing != null) listings.add(listing);
    }
    return listings;
  }

  /// The active ads this device can read without the backend: the local list
  /// (demo, tests) or, with a database, only the user's OWN ads (the database
  /// lets nobody read other people's directly). Search goes through
  /// [loadNearbyListings].
  Future<List<MarketplaceListing>> loadActiveListings() async {
    final client = _resolveClient();
    if (client == null) {
      return List<MarketplaceListing>.unmodifiable(
        _local.where((listing) => listing.status == ListingStatus.active),
      );
    }

    final response = await client.from(_table).select('*').eq('status', 'active');
    return _parseRows(response as List<dynamic>);
  }

  /// Publishes an ad. The Mercatino sells things for animals, never animals:
  /// the same rule runs here before anything is sent and, the one that decides,
  /// in the backend (`POST /marketplace/listings`), which is the only door to
  /// the table. The ad is not written to the database directly.
  Future<void> createListing(MarketplaceListing listing) async {
    _refuseAnimals(listing);
    if (!_localOnly) {
      if (await _writeViaApi('POST', '/marketplace/listings', listing)) return;
      if (_resolveClient() != null) throw const ListingBackendUnavailableException();
    }
    _local.insert(0, listing);
  }

  void _refuseAnimals(MarketplaceListing listing) {
    if (offersAnimals(listing.title, listing.description)) {
      throw ListingRejectedException(appL10n.marketplaceNoAnimalsMessage);
    }
  }

  /// The body the backend takes to publish or edit an ad.
  Map<String, dynamic> _toApiBody(MarketplaceListing listing) => {
        'title': listing.title,
        'description': listing.description,
        'category': categoryToWire(listing.category),
        'condition': _conditionToString(listing.condition),
        'price_cents': listing.priceCents,
        'photo_urls': listing.photoUrls,
        'target_species': listing.species.map(speciesToWire).toList(),
        'latitude': listing.location.latitude,
        'longitude': listing.location.longitude,
        'city_label': listing.cityLabel,
        'country': listing.country,
      };

  /// True once the backend took the ad; false when it cannot be asked (no
  /// address or session). A refusal of the content is a
  /// [ListingRejectedException] carrying the backend's own message.
  Future<bool> _writeViaApi(String method, String path, MarketplaceListing listing) async {
    final response = await _callApi(method, path, body: _toApiBody(listing));
    if (response == null) return false;
    if (response.statusCode == 200) return true;
    if (response.statusCode == 400) {
      String? detail;
      try {
        detail = (jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>)['detail']
            as String?;
      } catch (_) {}
      // The backend speaks Italian; the owner reads the message in their language.
      throw ListingRejectedException(
        detail == animalPolicyBackendMessage || detail == null
            ? (detail == null ? appL10n.marketplaceSaveFailed : appL10n.marketplaceNoAnimalsMessage)
            : detail,
      );
    }
    throw const ListingBackendUnavailableException();
  }

  /// Author only. The `owner_id` filter plus `.select()` turn an RLS
  /// refusal (which Postgres reports as "0 rows" rather than an error) into
  /// a visible [ListingPermissionException].
  Future<void> updateListing(MarketplaceListing listing, {required String requesterId}) async {
    _refuseAnimals(listing);
    if (!_localOnly && canManageListing(listing, requesterId)) {
      final path = '/marketplace/listings/${Uri.encodeComponent(listing.id)}';
      if (await _writeViaApi('PUT', path, listing)) return;
      if (_resolveClient() != null) throw const ListingBackendUnavailableException();
    }
    final client = _localOnly ? null : _resolveClient();
    if (client == null) {
      final index = _local.indexWhere((item) => item.id == listing.id);
      // The stored copy decides ownership, not the one the caller hands in.
      if (index == -1 || !canManageListing(_local[index], requesterId)) {
        throw const ListingPermissionException();
      }
      _local[index] = listing;
      return;
    }

    // A real database without the backend: ads are only written through it.
    throw canManageListing(listing, requesterId)
        ? const ListingBackendUnavailableException()
        : const ListingPermissionException();
  }

  /// Author only; the listing's photos are removed from storage afterwards.
  Future<void> deleteListing(MarketplaceListing listing, {required String requesterId}) async {
    final client = _resolveClient();
    if (client == null) {
      final index = _local.indexWhere((item) => item.id == listing.id);
      if (index == -1 || !canManageListing(_local[index], requesterId)) {
        throw const ListingPermissionException();
      }
      final removed = _local.removeAt(index);
      await _photoStore.remove(removed.photoUrls);
      return;
    }

    if (!canManageListing(listing, requesterId)) throw const ListingPermissionException();
    final deleted = await client
        .from(_table)
        .delete()
        .eq('id', listing.id)
        .eq('owner_id', requesterId)
        .select('id');
    if ((deleted as List<dynamic>).isEmpty) throw const ListingPermissionException();
    await _photoStore.remove(listing.photoUrls);
  }

  /// Report count/auto-removal after a report (ListingReportService). Local
  /// only: on Supabase a reporter can't update someone else's row, and the
  /// on_marketplace_listing_report_insert trigger already does it there.
  void applyModerationResult(MarketplaceListing listing) {
    if (_resolveClient() != null) return;
    final index = _local.indexWhere((item) => item.id == listing.id);
    if (index == -1) {
      _local.insert(0, listing);
    } else {
      _local[index] = listing;
    }
  }

  MarketplaceListing? _parseRow(Map<String, dynamic> row) {
    final category = categoryFromWire(row['category'] as String?);
    final condition = _conditionFromString(row['condition'] as String?);
    final status = _statusFromString(row['status'] as String?);
    final latitude = (row['latitude'] as num?)?.toDouble();
    final longitude = (row['longitude'] as num?)?.toDouble();
    final createdAt = DateTime.tryParse((row['created_at'] ?? '').toString());
    final updatedAt = DateTime.tryParse((row['updated_at'] ?? '').toString());
    if (category == null ||
        condition == null ||
        status == null ||
        latitude == null ||
        longitude == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    return MarketplaceListing(
      id: (row['id'] ?? '').toString(),
      ownerId: (row['owner_id'] ?? '').toString(),
      title: (row['title'] ?? '').toString(),
      description: row['description'] as String?,
      category: category,
      condition: condition,
      priceCents: (row['price_cents'] as num?)?.toInt(),
      photoUrls:
          (row['photo_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      // Missing until scripts/setup/marketplace_v2.sql has run: no species.
      species: (row['target_species'] as List<dynamic>?)
              ?.map((e) => speciesFromWire(e?.toString()))
              .whereType<ListingSpecies>()
              .toList() ??
          const [],
      location: Coordinates(latitude: latitude, longitude: longitude),
      cityLabel: row['city_label'] as String?,
      // Missing until scripts/setup/marketplace_country.sql has run: Italian.
      country: ((row['country'] as String?)?.trim().isNotEmpty ?? false)
          ? (row['country'] as String).trim().toUpperCase()
          : 'IT',
      status: status,
      reportCount: (row['report_count'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static ListingCondition? _conditionFromString(String? value) {
    switch (value) {
      case 'new':
        return ListingCondition.newItem;
      case 'like_new':
        return ListingCondition.likeNew;
      case 'good':
        return ListingCondition.good;
      case 'worn':
        return ListingCondition.worn;
      default:
        return null;
    }
  }

  static String _conditionToString(ListingCondition condition) {
    switch (condition) {
      case ListingCondition.newItem:
        return 'new';
      case ListingCondition.likeNew:
        return 'like_new';
      case ListingCondition.good:
        return 'good';
      case ListingCondition.worn:
        return 'worn';
    }
  }

  static ListingStatus? _statusFromString(String? value) {
    switch (value) {
      case 'active':
        return ListingStatus.active;
      case 'reserved':
        return ListingStatus.reserved;
      case 'sold':
        return ListingStatus.sold;
      case 'removed':
        return ListingStatus.removed;
      default:
        return null;
    }
  }

  SupabaseClient? _resolveClient() {
    if (_localOnly) return null;
    if (_client != null) return _client;

    final config = const AppRuntimeConfigLoader().load();
    if (!config.hasSupabaseCredentials) return null;

    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // Demo-only seed, shown only when no Supabase client is configured (the
  // maps demo route, local runs with an empty SUPABASE_URL). Its position
  // is already on the ~1 km grid (listing_location.dart), not a real
  // seller's address.
  static final List<MarketplaceListing> _seedListings = [
    MarketplaceListing(
      id: 'demo-listing-cuccia',
      ownerId: 'demo-seller',
      title: appL10n.marketplaceDemoBedTitle,
      description: appL10n.marketplaceDemoBedDescription,
      category: ListingCategory.kennelsCarriers,
      condition: ListingCondition.good,
      priceCents: 1500,
      species: const [ListingSpecies.dog],
      location: const Coordinates(latitude: 45.46, longitude: 9.19),
      cityLabel: appL10n.marketplaceDemoBedArea,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    MarketplaceListing(
      id: 'demo-listing-tiragraffi',
      ownerId: 'demo-seller',
      title: appL10n.marketplaceDemoScratcherTitle,
      category: ListingCategory.toys,
      condition: ListingCondition.likeNew,
      species: const [ListingSpecies.cat],
      location: const Coordinates(latitude: 45.48, longitude: 9.21),
      cityLabel: appL10n.marketplaceDemoScratcherArea,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
}

const _categoryWire = {
  ListingCategory.kennelsCarriers: 'kennels_carriers',
  ListingCategory.leashesCollars: 'leashes_collars',
  ListingCategory.toys: 'toys',
  ListingCategory.clothing: 'clothing',
  ListingCategory.feeding: 'feeding',
  ListingCategory.hygieneGrooming: 'hygiene_grooming',
  ListingCategory.aquariumsTerrariums: 'aquariums_terrariums',
  ListingCategory.cagesAviaries: 'cages_aviaries',
  ListingCategory.other: 'other',
};

/// Categories used before 2026-10-07, mapped to the closest current one so
/// older rows keep showing (marketplace_v2.sql also rewrites them in place).
const _legacyCategoryWire = {
  'transport_carriers': ListingCategory.kennelsCarriers,
  'food': ListingCategory.feeding,
  'grooming': ListingCategory.hygieneGrooming,
  'accessories': ListingCategory.other,
  'health_wellness': ListingCategory.other,
};

String categoryToWire(ListingCategory category) => _categoryWire[category]!;

ListingCategory? categoryFromWire(String? value) {
  for (final entry in _categoryWire.entries) {
    if (entry.value == value) return entry.key;
  }
  return _legacyCategoryWire[value];
}

const _speciesWire = {
  ListingSpecies.allSpecies: 'all',
  ListingSpecies.dog: 'dog',
  ListingSpecies.cat: 'cat',
  ListingSpecies.smallMammal: 'small_mammal',
  ListingSpecies.bird: 'bird',
  ListingSpecies.reptileAmphibian: 'reptile_amphibian',
  ListingSpecies.fish: 'fish',
  ListingSpecies.other: 'other',
};

String speciesToWire(ListingSpecies species) => _speciesWire[species]!;

ListingSpecies? speciesFromWire(String? value) {
  for (final entry in _speciesWire.entries) {
    if (entry.value == value) return entry.key;
  }
  return null;
}
