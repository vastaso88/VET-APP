import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vet_app_mobile/features/local_activities/data/local_activities_repository.dart';
import 'package:vet_app_mobile/features/local_activities/domain/local_activity.dart';
import 'package:vet_app_mobile/features/local_events/presentation/pages/local_events_page.dart';
import 'package:vet_app_mobile/features/location/data/device_location_service.dart';
import 'package:vet_app_mobile/features/location/data/location_preference_store.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/nearby_places/data/radar_places_repository.dart';
import 'package:vet_app_mobile/features/nearby_places/domain/radar_place.dart';
import 'package:vet_app_mobile/features/nearby_places/presentation/radar_category.dart';
import 'package:vet_app_mobile/features/nearby_places/presentation/widgets/radar_chip.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';
import 'package:vet_app_mobile/shared/widgets/pet_loader.dart';

const _milan = Coordinates(latitude: 45.4642, longitude: 9.1900);
const _turin = Coordinates(latitude: 45.0703, longitude: 7.6869);

class _FakeRadarPlacesRepository extends RadarPlacesRepository {
  _FakeRadarPlacesRepository(this._results);

  /// Answers in order; the last one repeats.
  final List<Result<RadarPlacesResult>> _results;
  final List<double> requestedRadii = [];
  final List<Coordinates> requestedCenters = [];

  @override
  Future<Result<RadarPlacesResult>> loadNearby({
    required Coordinates center,
    required double radiusKm,
  }) async {
    final index = requestedRadii.length.clamp(0, _results.length - 1);
    requestedRadii.add(radiusKm);
    requestedCenters.add(center);
    return _results[index];
  }
}

class _FakeLocationSampler implements LocationSampler {
  const _FakeLocationSampler(this._result);

  final DeviceLocationResult _result;

  @override
  Future<DeviceLocationResult> requestCurrentPosition() async => _result;
}

const _noGps = _FakeLocationSampler(
  DeviceLocationResult.failure(LocationRequestFailure.permissionDenied),
);

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

Result<RadarPlacesResult> _success(
  List<RadarPlace> places, {
  bool isStale = false,
  double searchRadiusKm = 50,
}) {
  return Result.success(
    RadarPlacesResult(places: places, searchRadiusKm: searchRadiusKm, isStale: isStale),
  );
}

_FakeRadarPlacesRepository _repositoryWith(List<RadarPlace> places, {bool isStale = false}) {
  return _FakeRadarPlacesRepository([_success(places, isStale: isStale)]);
}

Future<void> _useHome(Coordinates? home) {
  return LocationPreferenceStore.instance.update(
    UserLocationPreference(
      mode: home == null ? LocationMode.currentPosition : LocationMode.homeResidence,
      home: home,
    ),
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  RadarPlacesRepository repository, {
  LocationSampler locationSampler = _noGps,
}) async {
  // Tall surface so every section is built (ListView is lazy), same reason
  // as local_events_page_test.dart.
  await tester.binding.setSurfaceSize(const Size(420, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: LocalEventsPage(radarPlacesRepository: repository, locationSampler: locationSampler),
    ),
  );
  await _settle(tester);
}

/// Fixed pumps instead of pumpAndSettle: the page loader animates forever.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('it_IT');
  });

  // A saved home near the seeded demo activities stands in for the user's
  // Località; tests about missing or GPS positions override it.
  setUp(() => _useHome(_milan));

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

  test('with a backend the repository never falls back to demo activities', () async {
    // A configured client whose request fails (no network in tests): the
    // answer must be "nothing", not the preview seed.
    final repository = LocalActivitiesRepository(
      client: SupabaseClient('http://localhost:1', 'test-key'),
    );

    expect(await repository.loadActiveActivities(), isEmpty);
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

  testWidgets('scarce categories stay visible next to abundant ones', (tester) async {
    final parks = List.generate(
      30,
      (i) => RadarPlace(
        id: 'park-$i',
        type: RadarPlaceType.dogPark,
        name: 'Area cani $i',
        location: Coordinates(latitude: 45.465 + i * 0.0002, longitude: 9.19),
        distanceMeters: 100.0 + i,
      ),
    );
    const groomer = RadarPlace(
      id: 'groomer',
      type: RadarPlaceType.grooming,
      name: 'Toelettatura Lontana',
      location: Coordinates(latitude: 45.50, longitude: 9.25),
      distanceMeters: 7000,
    );

    await _pumpPage(tester, _repositoryWith([...parks, groomer]));

    // 30 dog parks are all closer, yet the one groomer has its own group.
    expect(find.text('Aree cani (30)'), findsOneWidget);
    expect(find.text('Toelettature (1)'), findsOneWidget);
    expect(find.text('Toelettatura Lontana'), findsOneWidget);
    expect(find.text('Area cani 5'), findsNothing);

    await tester.tap(find.text('Mostra tutti: aree cani (30)'));
    await _settle(tester);

    expect(find.text('Area cani 5'), findsOneWidget);
  });

  testWidgets('a quick category filter narrows lists without a new request', (tester) async {
    final repository = _repositoryWith([_clinic, _dogPark]);
    await _pumpPage(tester, repository);

    await tester.ensureVisible(find.widgetWithText(RadarChip, 'Veterinari'));
    await tester.tap(find.widgetWithText(RadarChip, 'Veterinari'));
    await tester.pumpAndSettle();

    expect(find.text('Clinica Veterinaria Duomo'), findsOneWidget);
    expect(find.text('Area cani'), findsNothing);
    // Events are a category too: hidden once another one is selected.
    expect(find.text('In programma'), findsNothing);
    expect(repository.requestedRadii, [10]);
  });

  testWidgets('selected chips use a light label on the dark background', (tester) async {
    await _pumpPage(tester, _repositoryWith([_clinic]));

    Color labelColor(String label) {
      final chip = tester.widget<ChoiceChip>(
        find.descendant(
          of: find.widgetWithText(RadarChip, label),
          matching: find.byType(ChoiceChip),
        ),
      );
      return chip.labelStyle!.color!;
    }

    // "10 km" and "Tutti" are the selected defaults.
    expect(labelColor('10 km').computeLuminance(), greaterThan(0.8));
    expect(labelColor('Tutti').computeLuminance(), greaterThan(0.8));
    expect(labelColor('25 km').computeLuminance(), lessThan(0.2));
  });

  testWidgets('changing the radius asks the backend for that radius', (tester) async {
    final repository = _repositoryWith([_clinic]);
    await _pumpPage(tester, repository);

    await tester.tap(find.widgetWithText(RadarChip, '50 km'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RadarChip, '5 km'));
    await tester.pumpAndSettle();

    expect(repository.requestedRadii, [10, 50, 5]);
  });

  testWidgets('the Filtri sheet applies a species filter', (tester) async {
    await _pumpPage(tester, _repositoryWith([_clinic, _dogPark]));

    await tester.tap(find.text('Filtri'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RadarChip, 'Gatto'));
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
      _FakeRadarPlacesRepository([
        Result.failure(const AppNetworkError(message: 'Non sono riuscito a caricare i servizi.')),
      ]),
    );

    expect(find.text('Non sono riuscito a caricare i servizi.'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
    // The events part of the page is unaffected by a radar failure.
    expect(find.text('Fiera cinofila regionale'), findsOneWidget);
  });

  testWidgets('without any position asks for a Località instead of showing a default city',
      (tester) async {
    await _useHome(null);
    final repository = _repositoryWith([_clinic]);

    await _pumpPage(tester, repository);

    // First visit with no position: explanation first, never a default city.
    expect(find.text('Usare la tua posizione?'), findsOneWidget);
    expect(find.textContaining('solo mentre usi l’app'), findsOneWidget);
    await tester.tap(find.text('Consenti'));
    await _settle(tester);

    // The (fake) system prompt was refused.
    expect(find.text('Imposta una località'), findsOneWidget);
    expect(find.text('Apri Impostazioni'), findsOneWidget);
    expect(find.text('Clinica Veterinaria Duomo'), findsNothing);
    expect(repository.requestedRadii, isEmpty);
  });

  testWidgets('"posizione attuale" centers the search on the GPS reading', (tester) async {
    await _useHome(null);
    final repository = _repositoryWith([_clinic]);

    await _pumpPage(
      tester,
      repository,
      locationSampler: const _FakeLocationSampler(DeviceLocationResult.success(_turin)),
    );
    await tester.tap(find.text('Consenti'));
    await _settle(tester);

    expect(repository.requestedCenters, [_turin]);
    expect(LocationPreferenceStore.instance.preference.mode, LocationMode.currentPosition);
    expect(LocationPreferenceStore.instance.preference.current, _turin);
    expect(find.text('Clinica Veterinaria Duomo'), findsOneWidget);
  });

  testWidgets('shows a full-page loader, then retries on its own while the area is prepared',
      (tester) async {
    final repository = _FakeRadarPlacesRepository([
      Result.failure(
        const AppNetworkError(code: RadarPlacesRepository.preparingErrorCode, message: 'attendi'),
      ),
      _success([_clinic]),
    ]);

    await _pumpPage(tester, repository);

    // First answer was "still preparing": no map, no lists, just the loader.
    expect(find.byType(PetLoader), findsOneWidget);
    expect(find.text('Servizi nella zona'), findsNothing);

    await tester.pump(const Duration(seconds: 9));
    await tester.pump(const Duration(milliseconds: 50));

    expect(repository.requestedRadii, [10, 10]);
    expect(find.text('Clinica Veterinaria Duomo'), findsOneWidget);
  });
}
