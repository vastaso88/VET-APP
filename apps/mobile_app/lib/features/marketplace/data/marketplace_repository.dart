import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/config/app_runtime_config_loader.dart';
import '../../location/domain/coordinates.dart';
import '../domain/marketplace_listing.dart';
import 'listing_photo_store.dart';

/// Thrown when someone other than the author tries to change or delete a
/// listing, or the database refused the change for that reason.
class ListingPermissionException implements Exception {
  const ListingPermissionException();

  @override
  String toString() => 'Solo chi ha pubblicato l\'annuncio può modificarlo o eliminarlo.';
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
  MarketplaceRepository({SupabaseClient? client, ListingPhotoStore? photoStore})
      : _client = client,
        _localOnly = false,
        _local = _sharedLocal,
        _photoStore = photoStore ?? ListingPhotoStore(client: client);

  /// Isolated local store (tests, previews): never talks to Supabase.
  MarketplaceRepository.inMemory(List<MarketplaceListing> listings)
      : _client = null,
        _localOnly = true,
        _local = List<MarketplaceListing>.of(listings),
        _photoStore = ListingPhotoStore(localOnly: true);

  static const _table = 'marketplace_listings';
  static final List<MarketplaceListing> _sharedLocal = List<MarketplaceListing>.of(_seedListings);

  final SupabaseClient? _client;
  final bool _localOnly;
  final List<MarketplaceListing> _local;
  final ListingPhotoStore _photoStore;

  ListingPhotoStore get photoStore => _photoStore;

  Future<List<MarketplaceListing>> loadActiveListings() async {
    final client = _resolveClient();
    if (client == null) {
      return List<MarketplaceListing>.unmodifiable(
        _local.where((listing) => listing.status == ListingStatus.active),
      );
    }

    final response = await client.from(_table).select('*').eq('status', 'active');
    final listings = <MarketplaceListing>[];
    for (final row in response as List<dynamic>) {
      final listing = _parseRow(row as Map<String, dynamic>);
      if (listing != null) listings.add(listing);
    }
    return listings;
  }

  Future<void> createListing(MarketplaceListing listing) async {
    final client = _resolveClient();
    if (client == null) {
      _local.insert(0, listing);
      return;
    }
    await client.from(_table).insert(_toRow(listing));
  }

  /// Author only. The `owner_id` filter plus `.select()` turn an RLS
  /// refusal (which Postgres reports as "0 rows" rather than an error) into
  /// a visible [ListingPermissionException].
  Future<void> updateListing(MarketplaceListing listing, {required String requesterId}) async {
    final client = _resolveClient();
    if (client == null) {
      final index = _local.indexWhere((item) => item.id == listing.id);
      // The stored copy decides ownership, not the one the caller hands in.
      if (index == -1 || !canManageListing(_local[index], requesterId)) {
        throw const ListingPermissionException();
      }
      _local[index] = listing;
      return;
    }

    if (!canManageListing(listing, requesterId)) throw const ListingPermissionException();
    final row = _toRow(listing)
      ..remove('id')
      ..remove('owner_id')
      ..remove('created_at')
      ..remove('status')
      ..remove('report_count');
    final updated = await client
        .from(_table)
        .update(row)
        .eq('id', listing.id)
        .eq('owner_id', requesterId)
        .select('id');
    if ((updated as List<dynamic>).isEmpty) throw const ListingPermissionException();
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

  Map<String, dynamic> _toRow(MarketplaceListing listing) {
    return {
      'id': listing.id,
      'owner_id': listing.ownerId,
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
      'status': _statusToString(listing.status),
      'report_count': listing.reportCount,
      'created_at': listing.createdAt.toIso8601String(),
      'updated_at': listing.updatedAt.toIso8601String(),
    };
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

  static String _statusToString(ListingStatus status) {
    switch (status) {
      case ListingStatus.active:
        return 'active';
      case ListingStatus.reserved:
        return 'reserved';
      case ListingStatus.sold:
        return 'sold';
      case ListingStatus.removed:
        return 'removed';
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
      title: 'Cuccia imbottita (demo)',
      description: 'Poco usata, taglia media.',
      category: ListingCategory.kennelsCarriers,
      condition: ListingCondition.good,
      priceCents: 1500,
      species: const [ListingSpecies.dog],
      location: const Coordinates(latitude: 45.46, longitude: 9.19),
      cityLabel: 'Centro, Milano',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    MarketplaceListing(
      id: 'demo-listing-tiragraffi',
      ownerId: 'demo-seller',
      title: 'Tiragraffi a due piani (demo)',
      category: ListingCategory.toys,
      condition: ListingCondition.likeNew,
      species: const [ListingSpecies.cat],
      location: const Coordinates(latitude: 45.48, longitude: 9.21),
      cityLabel: 'Città Studi, Milano',
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
