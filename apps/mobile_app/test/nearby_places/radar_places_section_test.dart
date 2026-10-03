import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/local_events/presentation/pages/local_events_page.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/nearby_places/data/radar_places_repository.dart';
import 'package:vet_app_mobile/features/nearby_places/domain/radar_place.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

class _FakeRadarPlacesRepository extends RadarPlacesRepository {
  _FakeRadarPlacesRepository(this._result);

  final Result<RadarPlacesResult> _result;

  @override
  Future<Result<RadarPlacesResult>> loadNearby({
    required Coordinates center,
    required double radiusKm,
    int limit = 60,
  }) async =>
      _result;
}

Future<void> _pumpPage(WidgetTester tester, RadarPlacesRepository repository) async {
  // Same tall surface as local_events_page_test.dart, plus room for the
  // extra "Servizi per animali" section below the two existing lists.
  await tester.binding.setSurfaceSize(const Size(400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: LocalEventsPage(radarPlacesRepository: repository)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('it_IT');
  });

  test('RadarPlace.tryFromJson maps the API row and skips unusable ones', () {
    final place = RadarPlace.tryFromJson({
      'id': 'cell:45.45:9.20:r15|openstreetmap_overpass|node/1',
      'place_type': 'pet_sitting',
      'name': ' Dog Sitter Navigli ',
      'latitude': 45.45,
      'longitude': 9.18,
      'distance_km': 1.25,
      'website_url': 'https://www.openstreetmap.org/node/1',
      'source_url': 'https://www.openstreetmap.org/node/1',
    })!;

    expect(place.name, 'Dog Sitter Navigli');
    expect(place.type, RadarPlaceType.petSitting);
    expect(place.distanceMeters, 1250);
    expect(place.websiteUrl, isNull);
    expect(RadarPlace.tryFromJson({'name': 'Senza coordinate'}), isNull);
    expect(radarPlaceTypeFromApi('something_new'), RadarPlaceType.other);
  });

  testWidgets('lists places inside the selected radius and opens the detail sheet',
      (tester) async {
    const near = RadarPlace(
      id: 'near',
      type: RadarPlaceType.veterinary,
      name: 'Clinica Veterinaria Duomo',
      location: Coordinates(latitude: 45.465, longitude: 9.19),
      distanceMeters: 800,
      addressLabel: 'Via Torino 10, Milano',
      phone: '+39 02 1234567',
    );
    await _pumpPage(
      tester,
      _FakeRadarPlacesRepository(
        Result.success(const RadarPlacesResult(places: [near], searchRadiusKm: 10)),
      ),
    );

    expect(find.text('Servizi per animali'), findsOneWidget);
    expect(find.text('Clinica Veterinaria Duomo'), findsOneWidget);
    // Default radius chip is 25 km, wider than what the backend serves.
    expect(find.textContaining('disponibili entro 10 km'), findsOneWidget);

    await tester.tap(find.text('Clinica Veterinaria Duomo'));
    await tester.pumpAndSettle();

    expect(find.text('Chiama'), findsOneWidget);
    expect(find.text('Apri in mappa'), findsOneWidget);
  });

  testWidgets('shows the error with a retry action when the radar fails', (tester) async {
    await _pumpPage(
      tester,
      _FakeRadarPlacesRepository(
        Result.failure(const AppNetworkError(message: 'Non sono riuscito a caricare i servizi.')),
      ),
    );

    expect(find.text('Non sono riuscito a caricare i servizi.'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
    // The events part of the page is unaffected by a radar failure.
    expect(find.text('Fiera cinofila regionale'), findsOneWidget);
  });
}
