import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/config/app_runtime_config_loader.dart';
import '../../location/domain/coordinates.dart';
import '../domain/marketplace_listing.dart';

/// Same shape as RemindersRepository: optional Supabase client, a
/// session-lifetime local list as demo/no-backend fallback, defensive row
/// parsing that skips anything malformed rather than crashing.
class MarketplaceRepository {
  MarketplaceRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static final List<MarketplaceListing> _localListings = List<MarketplaceListing>.of(_seedListings);

  Future<List<MarketplaceListing>> loadActiveListings() async {
    final remote = await _tryLoadRemoteListings();
    if (remote.isNotEmpty) {
      return remote;
    }
    return List<MarketplaceListing>.unmodifiable(
      _localListings.where((listing) => listing.status == ListingStatus.active),
    );
  }

  Future<void> saveListing(MarketplaceListing listing) async {
    final index = _localListings.indexWhere((item) => item.id == listing.id);
    if (index == -1) {
      _localListings.insert(0, listing);
    } else {
      _localListings[index] = listing;
    }

    final client = _resolveClient();
    if (client == null) {
      return;
    }

    try {
      await client.from('marketplace_listings').upsert(_toRow(listing));
    } catch (_) {
      // Best-effort: the local list above already applied for this session.
    }
  }

  Future<List<MarketplaceListing>> _tryLoadRemoteListings() async {
    final client = _resolveClient();
    if (client == null) {
      return const [];
    }

    try {
      final response =
          await client.from('marketplace_listings').select('*').eq('status', 'active');
      final rows = response as List<dynamic>;
      final listings = <MarketplaceListing>[];
      for (final row in rows) {
        final listing = _parseRow(row as Map<String, dynamic>);
        if (listing != null) {
          listings.add(listing);
        }
      }
      return listings;
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> _toRow(MarketplaceListing listing) {
    return {
      'id': listing.id,
      'owner_id': listing.ownerId,
      'title': listing.title,
      'description': listing.description,
      'category': _categoryToString(listing.category),
      'condition': _conditionToString(listing.condition),
      'price_cents': listing.priceCents,
      'photo_urls': listing.photoUrls,
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
    final category = _categoryFromString(row['category'] as String?);
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
      photoUrls: (row['photo_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      location: Coordinates(latitude: latitude, longitude: longitude),
      cityLabel: row['city_label'] as String?,
      status: status,
      reportCount: (row['report_count'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static ListingCategory? _categoryFromString(String? value) {
    for (final category in ListingCategory.values) {
      if (_categoryToString(category) == value) return category;
    }
    return null;
  }

  static String _categoryToString(ListingCategory category) {
    switch (category) {
      case ListingCategory.food:
        return 'food';
      case ListingCategory.accessories:
        return 'accessories';
      case ListingCategory.healthWellness:
        return 'health_wellness';
      case ListingCategory.transportCarriers:
        return 'transport_carriers';
      case ListingCategory.toys:
        return 'toys';
      case ListingCategory.grooming:
        return 'grooming';
      case ListingCategory.other:
        return 'other';
    }
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
    if (_client != null) {
      return _client;
    }

    final config = const AppRuntimeConfigLoader().load();
    if (!config.hasSupabaseCredentials) {
      return null;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // Demo-only seed for the maps demo route (app/preview/maps_demo_page.dart).
  // The coordinates below are already an example of a fuzzed position (see
  // packages/core/application/services/create_listing.py) - not the
  // seller's real address.
  static final List<MarketplaceListing> _seedListings = [
    MarketplaceListing(
      id: 'demo-listing-cuccia',
      ownerId: 'demo-user',
      title: 'Cuccia imbottita (demo)',
      description: 'Poco usata, taglia media.',
      category: ListingCategory.accessories,
      condition: ListingCondition.good,
      location: const Coordinates(latitude: 45.4610, longitude: 9.1940),
      cityLabel: 'Milano',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
}
