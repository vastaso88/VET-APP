import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/local_activities/data/local_activities_repository.dart';
import 'package:vet_app_mobile/features/local_activities/domain/local_activity.dart';
import 'package:vet_app_mobile/features/local_events/presentation/pages/local_events_page.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/nearby_places/data/radar_places_repository.dart';
import 'package:vet_app_mobile/features/nearby_places/domain/radar_place.dart';
import 'package:vet_app_mobile/features/nearby_places/presentation/radar_category.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

class _FakeRadarPlacesRepository extends RadarPlacesRepository {
  _FakeRadarPlacesRepository(this._result);

  final Result<RadarPlacesResult> _result;
  final List<double> requestedRadii = [];

  @override
  Future<Result<RadarPlacesResult>> loadNearby({
    required Coordinates center,
    required double radiusKm,
  }) async {
    requestedRadii.add(radiusKm);
    return _result;
  }
}

const _clinic = RadarPlace(
  id: 'clinic',
  type: RadarPlaceType.veterinary,
  name: 'Clinica Veterinaria Duomo',
  location: Coordinates(latitude: 45.465, longitude: 9.19),
  distanceMeters: 800,
  addressLabel: 'Via Torino 10, Milano',
  phone: '+39 02 1234567',
  openingHours: 'Mo-Fr 09:00-19:00; Sa off',
);

const _dogPark = RadarPlace(
  id: 'park',
  type: RadarPlaceType.dogPark,
  name: 'Area cani',
  location: Coordinates(latitude: 45.47, longitude: 9.2),
  distanceMeters: 1500,
  species: ['dog'],
);

_FakeRadarPlacesRepository _repositoryWith(List<RadarPlace> places, {bool isStale = false}) {
  return _FakeRadarPlacesRepository(
    Result.success(RadarPlacesResult(places: places, searchRadiusKm: 50, isStale: isStale)),
  );
}

Future<void> _pumpPage(WidgetTester tester, RadarPlacesRepository repository) async {
  // Tall surface so every section is built (ListView is lazy), same reason
  // as local_events_page_test.dart.
  await tester.binding.setSurfaceSize(const Size(420, 2600));
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
      'id': 'radar:v2:0.05:45.45:9.20:r14|openstreetmap_overpass|node/1',
      'place_type': 'dog_park',
      'name': ' Area cani ',
      'latitude': 45.45,
      'longitude': 9.18,
      'distance_km': 1.25,
      'opening_hours': '24/7',
      'species': ['dog'],
      'website_url': 'https://www.openstreetmap.org/node/1',
      'source_url': 'https://www.openstreetmap.org/node/1',
    })!;

    expect(place.name, 'Area cani');
    expect(place.type, RadarPlaceType.dogPark);
    expect(place.distanceMeters, 1250);
    expect(place.websiteUrl, isNull);
    expect(place.openingHours, '24/7');
    expect(RadarPlace.tryFromJson({'name': 'Senza coordinate'}), isNull);
    expect(radarPlaceTypeFromApi('something_new'), RadarPlaceType.other);
  });

  test('species filter keeps places that do not state a species', () {
    expect(_dogPark.matchesSpecies({'cat'}), isFalse);
    expect(_dogPark.matchesSpecies({'cat', 'dog'}), isTrue);
    expect(_clinic.matchesSpecies({'cat'}), isTrue);
    expect(_dogPark.matchesSpecies(const {}), isTrue);
  });

  test('opening hours are translated, not interpreted', () {
    expect(formatOpeningHours('Mo-Fr 09:00-19:00; Sa off'), 'Lun-Ven 09:00-19:00; Sab chiuso');
    expect(formatOpeningHours('24/7'), 'Indicato come aperto 24 ore su 24');
  });

  test('every category has its own icon and color', () {
    expect(RadarCategory.values.map((c) => c.color).toSet().length, RadarCategory.values.length);
    expect(RadarCategory.values.map((c) => c.icon).toSet().length, RadarCategory.values.length);
  });

  testWidgets('splits places into services and clinics, with urgency actions on clinics',
      (tester) async {
    await _pumpPage(tester, _repositoryWith([_clinic, _dogPark]));

    expect(find.text('Cliniche e ambulatori'), findsOneWidget);
    expect(find.text('Clinica Veterinaria Duomo'), findsOneWidget);
    expect(find.textContaining('Lun-Ven 09:00-19:00'), findsOneWidget);
    expect(find.byTooltip('Chiama Clinica Veterinaria Duomo'), findsOneWidget);
    expect(find.byTooltip('Indicazioni per Clinica Veterinaria Duomo'), findsOneWidget);
    expect(find.textContaining('telefona prima di partire'), findsOneWidget);
    expect(find.text('Area cani'), findsOneWidget);

    await tester.tap(find.text('Clinica Veterinaria Duomo'));
    await tester.pumpAndSettle();

    expect(find.text('Chiama'), findsOneWidget);
    expect(find.text('Indicazioni'), findsOneWidget);
  });

  testWidgets('a quick category filter narrows lists without a new request', (tester) async {
    final repository = _repositoryWith([_clinic, _dogPark]);
    await _pumpPage(tester, repository);

    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Veterinari'));
    await tester.tap(find.widgetWithText(FilterChip, 'Veterinari'));
    await tester.pumpAndSettle();

    expect(find.text('Clinica Veterinaria Duomo'), findsOneWidget);
    expect(find.text('Area cani'), findsNothing);
    // Events are a category too: hidden once another one is selected.
    expect(find.text('In programma'), findsNothing);
    expect(repository.requestedRadii, [10]);
  });

  testWidgets('changing the radius asks the backend for that radius', (tester) async {
    final repository = _repositoryWith([_clinic]);
    await _pumpPage(tester, repository);

    await tester.tap(find.widgetWithText(ChoiceChip, '50 km'));
    await tester.pumpAndSettle();

    expect(repository.requestedRadii, [10, 50]);
  });

  testWidgets('the Filtri sheet applies a species filter', (tester) async {
    await _pumpPage(tester, _repositoryWith([_clinic, _dogPark]));

    await tester.tap(find.text('Filtri'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Gatto'));
    await tester.tap(find.text('Applica'));
    await tester.pumpAndSettle();

    expect(find.text('Filtri (1)'), findsOneWidget);
    expect(find.text('Area cani'), findsNothing);
    expect(find.text('Clinica Veterinaria Duomo'), findsOneWidget);
  });

  testWidgets('national events are listed whatever the radius', (tester) async {
    await LocalActivitiesRepository().saveActivity(
      LocalActivity(
        id: 'test-national-fair',
        kind: LocalActivityKind.event,
        title: 'Grande fiera a Roma',
        category: 'fiera nazionale',
        location: const Coordinates(latitude: 41.9028, longitude: 12.4964),
        startsAt: DateTime.now().add(const Duration(days: 30)),
      ),
    );
    await _pumpPage(tester, _repositoryWith(const []));

    expect(find.text('Grande fiera a Roma'), findsOneWidget);
    expect(find.textContaining('Evento nazionale'), findsOneWidget);
  });

  testWidgets('tells the user when the area is served from an old import', (tester) async {
    await _pumpPage(tester, _repositoryWith([_clinic], isStale: true));

    expect(find.textContaining('potrebbero non essere recenti'), findsOneWidget);
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
