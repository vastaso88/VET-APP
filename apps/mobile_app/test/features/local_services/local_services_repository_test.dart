import 'package:flutter_test/flutter_test.dart';

import 'package:vet_app_mobile/features/local_services/data/local_services_repository.dart';
import 'package:vet_app_mobile/features/local_services/domain/local_service_models.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/network/api_client.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

void main() {
  test('loadSnapshot exposes API events, venues and live places', () async {
    final repository = LocalServicesRepository(
      apiClient: _StubApiClient({
        '/local-services/events': _eventsResponse(),
        '/local-services/venues?pet_friendly_only=true': _venuesResponse(),
        '/local-services/places?radius_km=10&limit=24': _placesResponse(),
      }),
    );

    final snapshot = await _unwrap(repository.loadSnapshot());

    expect(snapshot.eventCount, 1);
    expect(snapshot.structureCount, 1);
    expect(snapshot.petFriendlyEventCount, 1);
    expect(snapshot.events.single.title, 'Passeggiata urbana');
    expect(snapshot.structures.single.name, 'Clinica Vet Milano');
    expect(snapshot.radarFeedMode, RadarPlacesFeedMode.live);
    expect(snapshot.livePlaceCount, 1);
    expect(snapshot.liveRadarPlaceCount, 1);
    expect(snapshot.radarPlaces.single.dataOrigin, RadarPlaceDataOrigin.live);
    expect(snapshot.searchRadiusKm, 10);
    expect(snapshot.ingestionRadiusKm, 10);
  });

  test('loadEvents and loadStructures parse backend payloads', () async {
    final repository = LocalServicesRepository(
      apiClient: _StubApiClient({
        '/local-services/events': _eventsResponse(),
        '/local-services/venues?pet_friendly_only=true': _venuesResponse(),
      }),
    );

    final events = await _unwrap(repository.loadEvents());
    final structures = await _unwrap(repository.loadStructures());

    expect(events.single.kind, LocalEventKind.walk);
    expect(events.single.dateLabel, '20/04/2026');
    expect(structures.single.type, LocalStructureType.clinic);
    expect(structures.single.services, ['Triage', 'Sala separata']);
  });

  test('loadSnapshot returns an error when the live radar request fails',
      () async {
    final repository = LocalServicesRepository(
      apiClient: _StubApiClient({
        '/local-services/events': _eventsResponse(),
        '/local-services/venues?pet_friendly_only=true': _venuesResponse(),
        '/local-services/places?radius_km=10&limit=24': Result.failure(
          const AppNetworkError(
            code: 'api_http_error',
            message: 'temporary outage',
          ),
        ),
      }),
    );

    final result = await repository.loadSnapshot();

    expect(result.isFailure, isTrue);
  });
}

Future<T> _unwrap<T>(Future<Result<T>> future) async {
  final result = await future;
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw StateError(error.message),
  );
}

Result<Map<String, dynamic>> _eventsResponse() {
  return Result.success({
    'events': [
      {
        'id': 'event-walk-1',
        'title': 'Passeggiata urbana',
        'event_type': 'walk',
        'city': 'Milano',
        'venue_name': 'Parco Sempione',
        'location_label': 'Parco Sempione',
        'summary': 'Camminata guidata nel quartiere.',
        'event_date': '2026-04-20',
        'time_label': '18:30',
        'tags': ['Passeggiata', 'Outdoor'],
      },
    ],
  });
}

Result<Map<String, dynamic>> _venuesResponse() {
  return Result.success({
    'venues': [
      {
        'venue': {
          'id': 'venue-vet-1',
          'name': 'Clinica Vet Milano',
          'venue_type': 'clinic',
          'city': 'Milano',
          'address_label': 'Via Torino 10',
          'summary': 'Ambulatorio con accoglienza rapida.',
          'pet_friendly': true,
          'pet_friendly_features': ['Triage', 'Sala separata'],
          'contact_label': '08:00 - 19:00',
          'tags': ['Veterinario'],
        },
        'review_summary': {
          'review_count': 2,
          'average_rating': 4.8,
        },
      },
    ],
  });
}

Result<Map<String, dynamic>> _placesResponse() {
  return Result.success({
    'context': {
      'engine': 'places',
      'resolved_city': 'Milano',
      'address_label': 'Via Guglielmo Marconi, 3',
      'latitude': 45.4642,
      'longitude': 9.1899,
      'search_radius_km': 10,
      'ingestion_radius_km': 10,
      'coverage_key': 'test-user:45.46:9.19:r10',
      'coverage_status': 'fresh',
    },
    'coverage': {
      'coverage_key': 'test-user:45.46:9.19:r10',
      'status': 'fresh',
    },
    'places': [
      {
        'place': {
          'id': 'live-place-1',
          'name': 'OSM Vet Hub',
          'place_type': 'veterinary',
          'summary': 'Centro veterinario.',
          'address_label': 'Via Solferino 12',
          'city': 'Milano',
          'latitude': 45.4771,
          'longitude': 9.1879,
          'source_name': 'openstreetmap_overpass',
          'source_external_id': 'node/123',
          'source_url': 'https://www.openstreetmap.org/node/123',
          'tags': ['amenity:veterinary'],
        },
        'distance_km': 0.8,
      },
    ],
  });
}

class _StubApiClient extends ApiClient {
  _StubApiClient(this.responses);

  final Map<String, Result<Map<String, dynamic>>> responses;

  @override
  Future<Result<Map<String, dynamic>>> getJson(String path) async {
    return responses[path] ??
        Result.failure(
          const AppNetworkError(
            code: 'stub_response_missing',
            message: 'No stubbed response for request',
          ),
        );
  }
}