import 'package:flutter/material.dart';

import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_error.dart';
import '../../../shared/network/api_client.dart';
import '../../../shared/types/result.dart';
import '../domain/local_service_models.dart';

class LocalServicesRepository {
  LocalServicesRepository({
    ApiClient? apiClient,
    AppRuntimeConfigLoader? runtimeConfigLoader,
  })  : _apiClient = apiClient ?? ApiClient(),
        _runtimeConfigLoader =
            runtimeConfigLoader ?? const AppRuntimeConfigLoader();

  final ApiClient _apiClient;
  final AppRuntimeConfigLoader _runtimeConfigLoader;

  Future<Result<List<LocalEventCardModel>>> loadEvents() async {
    final response = await _apiClient.getJson('/local-services/events');
    return response.map(
      (payload) => (_readList(payload, 'events') ?? const <Object?>[])
          .map(_parseEvent)
          .whereType<LocalEventCardModel>()
          .toList(growable: false),
    );
  }

  Future<Result<List<PetFriendlyStructureCardModel>>> loadStructures() async {
    final response = await _apiClient.getJson(
      '/local-services/venues?pet_friendly_only=true',
    );
    return response.map(
      (payload) => (_readList(payload, 'venues') ?? const <Object?>[])
          .map(_parseStructure)
          .whereType<PetFriendlyStructureCardModel>()
          .toList(growable: false),
    );
  }

  Future<Result<LocalServicesSnapshot>> loadSnapshot() async {
    final eventsResult = await loadEvents();
    if (eventsResult
        case Failure<List<LocalEventCardModel>>(error: final error)) {
      return Result.failure(error);
    }

    final structuresResult = await loadStructures();
    if (structuresResult
        case Failure<List<PetFriendlyStructureCardModel>>(error: final error)) {
      return Result.failure(error);
    }

    final placesResult = await loadRadarPlaces();
    if (placesResult case Failure<RadarPlacesFeedResult>(error: final error)) {
      return Result.failure(error);
    }

    final events = (eventsResult as Success<List<LocalEventCardModel>>).value;
    final structures =
        (structuresResult as Success<List<PetFriendlyStructureCardModel>>)
            .value;
    final places = (placesResult as Success<RadarPlacesFeedResult>).value;

    return Result.success(
      LocalServicesSnapshot(
        cityLabel: places.cityLabel,
        addressLabel: places.addressLabel,
        centerLatitude: places.latitude,
        centerLongitude: places.longitude,
        searchRadiusKm: places.searchRadiusKm,
        ingestionRadiusKm: places.ingestionRadiusKm,
        radarFeedMode: places.feedMode,
        radarCoverageKey: places.coverageKey,
        radarCoverageStatus: places.coverageStatus,
        events: events,
        structures: structures,
        radarPlaces: places.places,
        diagnostics: _buildDiagnostics(placesResult: placesResult),
      ),
    );
  }

  Future<Result<RadarPlacesFeedResult>> loadRadarPlaces({
    double radiusKm = 10,
    int limit = 24,
  }) async {
    final effectiveRadiusKm = _effectiveRadiusKm(radiusKm);
    final response = await _apiClient.getJson(
      '/local-services/places?radius_km=${_formatRadiusKm(effectiveRadiusKm)}&limit=$limit',
    );
    return response.fold(
      onSuccess: (payload) {
        final coverage = _readMap(payload, 'coverage');
        final context = _readMap(payload, 'context');
        final rawPlaces = _readList(payload, 'places');
        if (rawPlaces == null) {
          return Result.failure(
            const AppUnexpectedError(
              code: 'radar_places_payload_invalid',
              message: 'Radar places response does not contain a places list',
            ),
          );
        }

        final coverageStatus = _readString(coverage, 'status') ??
            _readString(context, 'coverage_status');
        final coverageKey = _readString(coverage, 'coverage_key') ??
            _readString(context, 'coverage_key');
        final items = rawPlaces
            .map(
              (item) => _parseRadarPlace(
                item,
                coverageKey: coverageKey,
              ),
            )
            .whereType<RadarPlaceCardModel>()
            .toList(growable: false);

        return Result.success(
          RadarPlacesFeedResult(
            places: items,
            feedMode: items.isEmpty
                ? RadarPlacesFeedMode.empty
                : RadarPlacesFeedMode.live,
            coverageKey: coverageKey,
            coverageStatus: coverageStatus,
            cityLabel: _readString(context, 'resolved_city'),
            addressLabel: _readString(context, 'address_label'),
            latitude: _asDouble(context?['latitude']),
            longitude: _asDouble(context?['longitude']),
            searchRadiusKm: _asDouble(context?['search_radius_km']) ?? 10,
            ingestionRadiusKm: _asDouble(context?['ingestion_radius_km']) ?? 10,
            source: _readString(context, 'engine') ?? 'api',
          ),
        );
      },
      onFailure: (error) => Result.failure(error),
    );
  }

  LocalEventCardModel? _parseEvent(Object? item) {
    if (item is! Map) {
      return null;
    }
    final raw = Map<String, dynamic>.from(item);
    final kind = _mapEventKind(raw['event_type']?.toString());
    final palette = _paletteForEvent(kind);
    final location = _firstText([
      raw['venue_name'],
      raw['location_label'],
      raw['city'],
    ]);

    return LocalEventCardModel(
      id: _readString(raw, 'id') ?? _stableId('event', raw['title']),
      title: _readString(raw, 'title') ?? '',
      location: location,
      neighborhood: _readString(raw, 'city') ?? '',
      dateLabel: _formatDateLabel(raw['event_date']),
      timeLabel: _readString(raw, 'time_label') ?? '',
      summary: _readString(raw, 'summary') ?? '',
      kind: kind,
      petFriendly: true,
      tags: _asStringList(raw['tags']),
      accentColor: palette,
    );
  }

  PetFriendlyStructureCardModel? _parseStructure(Object? item) {
    if (item is! Map) {
      return null;
    }
    final rawItem = Map<String, dynamic>.from(item);
    final raw = _readMap(rawItem, 'venue') ?? rawItem;
    final type = _mapStructureType(raw['venue_type']?.toString());
    final palette = _paletteForStructure(type);
    final petFriendly = raw['pet_friendly'] != false;

    return PetFriendlyStructureCardModel(
      id: _readString(raw, 'id') ?? _stableId('venue', raw['name']),
      name: _readString(raw, 'name') ?? '',
      location: _readString(raw, 'address_label') ?? '',
      neighborhood: _readString(raw, 'city') ?? '',
      type: type,
      openingLabel: _readString(raw, 'contact_label') ?? '',
      summary: _readString(raw, 'summary') ?? '',
      services: _asStringList(raw['pet_friendly_features']),
      petPolicyLabel: petFriendly ? 'Pet friendly' : 'Accesso da verificare',
      tags: _asStringList(raw['tags']),
      accentColor: palette,
    );
  }

  RadarPlaceCardModel? _parseRadarPlace(
    Object? item, {
    String? coverageKey,
  }) {
    if (item is! Map) {
      return null;
    }

    final rawItem = Map<String, dynamic>.from(item);
    final place = _readMap(rawItem, 'place') ?? rawItem;
    final latitude = _asDouble(place['latitude']);
    final longitude = _asDouble(place['longitude']);
    if (latitude == null || longitude == null) {
      return null;
    }

    final type = _mapPlaceType(place['place_type']?.toString());
    final palette = _paletteForType(type);
    final sourceName = place['source_name']?.toString().trim() ?? '';
    final sourceExternalId = place['source_external_id']?.toString().trim();

    return RadarPlaceCardModel(
      id: _readString(place, 'id') ??
          _stableId(
              sourceName.isEmpty ? 'radar' : sourceName, sourceExternalId),
      name: _readString(place, 'name') ?? '',
      type: type,
      typeLabel: type.label,
      summary: _readString(place, 'summary') ?? '',
      addressLabel: _readString(place, 'address_label') ?? '',
      city: _readString(place, 'city') ?? '',
      latitude: latitude,
      longitude: longitude,
      distanceKm: _asDouble(rawItem['distance_km']) ??
          _asDouble(rawItem['distanceKm']) ??
          0,
      sourceName: sourceName,
      dataOrigin: _classifyPlaceOrigin(
        sourceName: sourceName,
        coverageKey: coverageKey,
      ),
      accentColor: palette.color,
      icon: palette.icon,
      tags: _asStringList(place['tags']),
      rating: _asDouble(place['rating']),
      websiteUrl:
          _readString(place, 'website_url') ?? _readString(place, 'source_url'),
      phone: _readString(place, 'phone'),
      isFeatured: place['is_featured'] == true,
      isPetFriendly: place['is_pet_friendly'] != false,
    );
  }

  LocalEventKind _mapEventKind(String? rawType) {
    switch ((rawType ?? '').trim().toLowerCase()) {
      case 'walk':
      case 'walking':
      case 'passeggiata':
        return LocalEventKind.walk;
      case 'market':
      case 'mercato':
        return LocalEventKind.market;
      case 'workshop':
      case 'training':
        return LocalEventKind.workshop;
      case 'meetup':
      case 'community':
        return LocalEventKind.meetup;
      case 'festival':
      case 'fair':
        return LocalEventKind.festival;
      default:
        return LocalEventKind.meetup;
    }
  }

  LocalStructureType _mapStructureType(String? rawType) {
    switch ((rawType ?? '').trim().toLowerCase()) {
      case 'park':
      case 'dog_park':
        return LocalStructureType.park;
      case 'cafe':
      case 'bar':
        return LocalStructureType.cafe;
      case 'restaurant':
        return LocalStructureType.restaurant;
      case 'hotel':
      case 'pet_boarding_service':
        return LocalStructureType.hotel;
      case 'beach':
        return LocalStructureType.beach;
      case 'clinic':
      case 'veterinary':
      case 'veterinary_care':
        return LocalStructureType.clinic;
      default:
        return LocalStructureType.all;
    }
  }

  RadarPlaceType _mapPlaceType(String? rawType) {
    switch ((rawType ?? '').trim().toLowerCase()) {
      case 'veterinary':
      case 'vet':
      case 'veterinary_care':
        return RadarPlaceType.veterinary;
      case 'grooming':
        return RadarPlaceType.grooming;
      case 'shop':
      case 'pet_store':
        return RadarPlaceType.shop;
      case 'school':
        return RadarPlaceType.school;
      case 'pet_sitting':
      case 'pet_care':
        return RadarPlaceType.petSitting;
      case 'breeder':
        return RadarPlaceType.breeder;
      case 'hotel':
      case 'pet_boarding_service':
        return RadarPlaceType.hotel;
      default:
        return RadarPlaceType.other;
    }
  }

  Color _paletteForEvent(LocalEventKind kind) {
    return switch (kind) {
      LocalEventKind.walk => const Color(0xFF2E686A),
      LocalEventKind.market => const Color(0xFFE0A35B),
      LocalEventKind.workshop => const Color(0xFF6F91A3),
      LocalEventKind.meetup => const Color(0xFF9A73B8),
      LocalEventKind.festival => const Color(0xFF4A8AA0),
      LocalEventKind.all => const Color(0xFF5E706E),
    };
  }

  Color _paletteForStructure(LocalStructureType type) {
    return switch (type) {
      LocalStructureType.park => const Color(0xFF2E686A),
      LocalStructureType.cafe => const Color(0xFFE0A35B),
      LocalStructureType.restaurant => const Color(0xFF4A8AA0),
      LocalStructureType.hotel => const Color(0xFF6F91A3),
      LocalStructureType.beach => const Color(0xFF9A73B8),
      LocalStructureType.clinic => const Color(0xFFB45F59),
      LocalStructureType.all => const Color(0xFF5E706E),
    };
  }

  ({Color color, IconData icon}) _paletteForType(RadarPlaceType type) {
    return switch (type) {
      RadarPlaceType.veterinary => (
          color: const Color(0xFFB45F59),
          icon: Icons.local_hospital_rounded,
        ),
      RadarPlaceType.grooming => (
          color: const Color(0xFF2E686A),
          icon: Icons.content_cut_rounded,
        ),
      RadarPlaceType.shop => (
          color: const Color(0xFFE0A35B),
          icon: Icons.shopping_bag_rounded,
        ),
      RadarPlaceType.school => (
          color: const Color(0xFF6F91A3),
          icon: Icons.school_rounded,
        ),
      RadarPlaceType.petSitting => (
          color: const Color(0xFF9A73B8),
          icon: Icons.home_work_rounded,
        ),
      RadarPlaceType.breeder => (
          color: const Color(0xFF8A6B4F),
          icon: Icons.workspace_premium_rounded,
        ),
      RadarPlaceType.hotel => (
          color: const Color(0xFF4A8AA0),
          icon: Icons.hotel_rounded,
        ),
      RadarPlaceType.all || RadarPlaceType.other => (
          color: const Color(0xFF5E706E),
          icon: Icons.place_rounded,
        ),
    };
  }

  RadarPlaceDataOrigin _classifyPlaceOrigin({
    required String sourceName,
    String? coverageKey,
  }) {
    final normalized = sourceName.trim();
    if (normalized.isEmpty &&
        (coverageKey == null || coverageKey.trim().isEmpty)) {
      return RadarPlaceDataOrigin.unknown;
    }
    return RadarPlaceDataOrigin.live;
  }

  RadarRuntimeDiagnostics _buildDiagnostics({
    required Result<RadarPlacesFeedResult> placesResult,
  }) {
    final runtimeConfig = _runtimeConfigLoader.load();
    final placesSource = placesResult.fold(
      onSuccess: (value) => value.source,
      onFailure: (_) => null,
    );
    final radarErrorCode = placesResult.fold(
      onSuccess: (_) => null,
      onFailure: (error) => error.code,
    );

    return RadarRuntimeDiagnostics(
      apiBaseUrl: runtimeConfig.apiBaseUrl,
      supabaseConfigured: runtimeConfig.hasSupabaseCredentials,
      contextSource: placesSource,
      placesSource: placesSource,
      errorCode: radarErrorCode,
    );
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  double _effectiveRadiusKm(double radiusKm) {
    if (radiusKm <= 0) {
      return 10;
    }
    return radiusKm > 10 ? 10 : radiusKm;
  }

  String _formatRadiusKm(double radiusKm) {
    return radiusKm % 1 == 0
        ? radiusKm.toStringAsFixed(0)
        : radiusKm.toString();
  }

  String _formatDateLabel(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  Map<String, dynamic>? _readMap(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  List<Object?>? _readList(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is List) {
      return value.cast<Object?>();
    }
    return null;
  }

  String? _readString(Map<String, dynamic>? payload, String key) {
    if (payload == null) {
      return null;
    }
    final value = payload[key];
    final cleaned = value?.toString().trim();
    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }
    return cleaned;
  }

  String _firstText(List<Object?> values) {
    for (final value in values) {
      final cleaned = value?.toString().trim();
      if (cleaned != null && cleaned.isNotEmpty) {
        return cleaned;
      }
    }
    return '';
  }

  String _stableId(String prefix, Object? value) {
    final suffix = value?.toString().trim();
    if (suffix == null || suffix.isEmpty) {
      return '$prefix-item';
    }
    return '$prefix-${suffix.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
  }

  List<String> _asStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class LocalServicesSnapshot {
  const LocalServicesSnapshot({
    this.cityLabel,
    this.addressLabel,
    this.centerLatitude,
    this.centerLongitude,
    this.searchRadiusKm,
    this.ingestionRadiusKm,
    this.radarFeedMode = RadarPlacesFeedMode.empty,
    this.radarCoverageKey,
    this.radarCoverageStatus,
    required this.events,
    required this.structures,
    this.radarPlaces = const <RadarPlaceCardModel>[],
    this.diagnostics = const RadarRuntimeDiagnostics(),
  });

  final String? cityLabel;
  final String? addressLabel;
  final double? centerLatitude;
  final double? centerLongitude;
  final double? searchRadiusKm;
  final double? ingestionRadiusKm;
  final RadarPlacesFeedMode radarFeedMode;
  final String? radarCoverageKey;
  final String? radarCoverageStatus;
  final List<LocalEventCardModel> events;
  final List<PetFriendlyStructureCardModel> structures;
  final List<RadarPlaceCardModel> radarPlaces;
  final RadarRuntimeDiagnostics diagnostics;

  int get eventCount => events.length;
  int get structureCount => structures.length;
  int get petFriendlyEventCount =>
      events.where((event) => event.petFriendly).length;
  int get livePlaceCount => radarPlaces.length;
  int get liveRadarPlaceCount =>
      radarPlaces.where((place) => place.isLive).length;

  String get locationSummary {
    final city = cityLabel?.trim();
    final address = addressLabel?.trim();

    if (city != null &&
        city.isNotEmpty &&
        address != null &&
        address.isNotEmpty) {
      return '$city - $address';
    }
    if (city != null && city.isNotEmpty) {
      return city;
    }
    if (address != null && address.isNotEmpty) {
      return address;
    }
    return 'posizione profilo non disponibile';
  }
}

class RadarPlacesFeedResult {
  const RadarPlacesFeedResult({
    required this.places,
    required this.feedMode,
    this.coverageKey,
    this.coverageStatus,
    this.cityLabel,
    this.addressLabel,
    this.latitude,
    this.longitude,
    this.searchRadiusKm,
    this.ingestionRadiusKm,
    this.source,
  });

  final List<RadarPlaceCardModel> places;
  final RadarPlacesFeedMode feedMode;
  final String? coverageKey;
  final String? coverageStatus;
  final String? cityLabel;
  final String? addressLabel;
  final double? latitude;
  final double? longitude;
  final double? searchRadiusKm;
  final double? ingestionRadiusKm;
  final String? source;
}