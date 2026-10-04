import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/account_consents/data/account_consents_remote_data_source.dart';
import 'package:vet_app_mobile/features/account_consents/domain/account_consent_models.dart';
import 'package:vet_app_mobile/features/local_events/presentation/pages/local_events_page.dart';
import 'package:vet_app_mobile/features/location/data/device_location_service.dart';
import 'package:vet_app_mobile/features/location/data/location_preference_store.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/nearby_places/data/radar_contributions_repository.dart';
import 'package:vet_app_mobile/features/nearby_places/data/radar_places_repository.dart';
import 'package:vet_app_mobile/features/nearby_places/data/reverse_geocoder.dart';
import 'package:vet_app_mobile/features/nearby_places/domain/radar_community.dart';
import 'package:vet_app_mobile/features/nearby_places/domain/radar_place.dart';
import 'package:vet_app_mobile/features/nearby_places/presentation/pages/report_missing_place_page.dart';
import 'package:vet_app_mobile/features/nearby_places/presentation/radar_contributions.dart';
import 'package:vet_app_mobile/features/nearby_places/presentation/widgets/radar_chip.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

const _milan = Coordinates(latitude: 45.4642, longitude: 9.1900);

class _FakePlaces extends RadarPlacesRepository {
  _FakePlaces(this.places);

  final List<RadarPlace> places;
  int requests = 0;

  @override
  Future<Result<RadarPlacesResult>> loadNearby({
    required Coordinates center,
    required double radiusKm,
  }) async {
    requests++;
    return Result.success(
      RadarPlacesResult(
        places: places,
        searchRadiusKm: 50,
        supportContactEmail: 'aiuto@esempio.example',
      ),
    );
  }
}

class _FakeContributions extends RadarContributionsRepository {
  /// When true, every write fails with "rules required" until
  /// [rulesAccepted] is set by the fake consents source.
  bool rulesAccepted = true;
  final List<String> calls = [];

  Result<T> _gate<T>(T value) => rulesAccepted
      ? Result.success(value)
      : Result.failure(
          const AppNetworkError(
            code: RadarContributionsRepository.rulesRequiredCode,
            message: 'Accetta le regole.',
          ),
        );

  /// Problems the backend accepts; the test changes it to play a switch.
  List<RadarProblem> problems = RadarProblem.values;

  @override
  Future<RadarReportOptions> loadOptions() async => RadarReportOptions(
        enabled: true,
        missingPlaceTypes: const [RadarPlaceType.veterinary, RadarPlaceType.grooming],
        problems: problems,
      );

  @override
  Future<Result<RadarReportReceipt>> reportMissing({
    required RadarPlaceType type,
    required String name,
    required Coordinates position,
    String? addressLabel,
  }) async {
    calls.add('missing:${type.name}:$name:$addressLabel');
    return _gate(const RadarReportReceipt(countedAsConfirmation: false));
  }

  @override
  Future<Result<RadarReportReceipt>> reportProblem(RadarPlace place, RadarProblem problem) async {
    calls.add('problem:${place.id}:${problem.apiValue}');
    return _gate(const RadarReportReceipt(countedAsConfirmation: false));
  }

  @override
  Future<Result<void>> vote(String reportId, {required bool confirm}) async {
    calls.add('vote:$reportId:$confirm');
    return _gate<void>(null);
  }

  @override
  Future<Result<void>> withdraw(String reportId) async {
    calls.add('withdraw:$reportId');
    return _gate<void>(null);
  }

  @override
  Future<Result<void>> rate(RadarPlace place, int stars) async {
    calls.add('rate:${place.id}:$stars');
    return _gate<void>(null);
  }
}

class _FakeConsents implements AccountConsentsRemoteDataSource {
  _FakeConsents(this._contributions);

  final _FakeContributions _contributions;

  AccountConsentsSnapshot get _snapshot => const AccountConsentsSnapshot(
        decisions: {},
        catalog: {
          'contribution_rules': ConsentCatalogEntry(version: 'v1', text: 'Regole di prova.'),
        },
      );

  @override
  Future<Result<AccountConsentsSnapshot>> fetch() async => Result.success(_snapshot);

  @override
  Future<Result<AccountConsentsSnapshot>> setConsent({
    required String consentKey,
    required bool granted,
  }) async {
    _contributions.rulesAccepted = granted;
    return Result.success(_snapshot);
  }
}

class _FakeReverseGeocoder extends ReverseGeocoder {
  @override
  Future<String?> addressOf(Coordinates position) async => 'Via Esempio 10, Milano';
}

const _noGps = _NoGps();

class _NoGps implements LocationSampler {
  const _NoGps();

  @override
  Future<DeviceLocationResult> requestCurrentPosition() async =>
      const DeviceLocationResult.failure(LocationRequestFailure.permissionDenied);
}

const _pendingGroomer = RadarPlace(
  id: 'vetapp_users|r1',
  type: RadarPlaceType.grooming,
  name: 'Toelettatura Nuova',
  location: Coordinates(latitude: 45.465, longitude: 9.19),
  distanceMeters: 300,
  sourceName: 'vetapp_users',
  sourceExternalId: 'r1',
  community: RadarReportInfo(reportId: 'r1', isPending: true, confirmations: 2, required: 5),
);

const _ownReport = RadarPlace(
  id: 'vetapp_users|r2',
  type: RadarPlaceType.shop,
  name: 'Negozio Mio',
  location: Coordinates(latitude: 45.466, longitude: 9.19),
  distanceMeters: 400,
  sourceName: 'vetapp_users',
  sourceExternalId: 'r2',
  community: RadarReportInfo(
    reportId: 'r2',
    isPending: true,
    confirmations: 0,
    required: 5,
    viewerIsReporter: true,
    expiresInDays: 5,
  ),
);

const _reportedDogPark = RadarPlace(
  id: 'vetapp_users|r3',
  type: RadarPlaceType.dogPark,
  name: 'Area cani',
  location: Coordinates(latitude: 45.468, longitude: 9.19),
  distanceMeters: 600,
  sourceName: 'vetapp_users',
  sourceExternalId: 'r3',
  community: RadarReportInfo(reportId: 'r3', isPending: true, confirmations: 1, required: 5),
);

const _dogPark = RadarPlace(
  id: 'park',
  type: RadarPlaceType.dogPark,
  name: 'Area cani Sempione',
  location: Coordinates(latitude: 45.47, longitude: 9.18),
  distanceMeters: 900,
  sourceExternalId: 'way/1',
  rating: RadarRating(count: 4, average: 4.25, viewerStars: 3),
);

const _unratedDogPark = RadarPlace(
  id: 'park-new',
  type: RadarPlaceType.dogPark,
  name: 'Area cani Nuova',
  location: Coordinates(latitude: 45.471, longitude: 9.181),
  distanceMeters: 950,
  sourceExternalId: 'way/2',
  rating: RadarRating(count: 0),
);

const _clinic = RadarPlace(
  id: 'clinic',
  type: RadarPlaceType.veterinary,
  name: 'Clinica Duomo',
  location: Coordinates(latitude: 45.465, longitude: 9.191),
  distanceMeters: 500,
  sourceName: 'overture',
  sourceExternalId: 'abc',
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<(_FakePlaces, _FakeContributions)> _pumpRadar(
  WidgetTester tester,
  List<RadarPlace> places, {
  bool rulesAccepted = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 2800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final placesRepository = _FakePlaces(places);
  final contributions = _FakeContributions()..rulesAccepted = rulesAccepted;
  await tester.pumpWidget(
    MaterialApp(
      home: LocalEventsPage(
        radarPlacesRepository: placesRepository,
        locationSampler: _noGps,
        contributions: RadarContributions(
          repository: contributions,
          consents: _FakeConsents(contributions),
          onChanged: () {},
        ),
      ),
    ),
  );
  await _settle(tester);
  return (placesRepository, contributions);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('it_IT');
    await LocationPreferenceStore.instance.update(
      const UserLocationPreference(mode: LocationMode.homeResidence, home: _milan),
    );
  });

  testWidgets('a pending user report is labelled and can be confirmed', (tester) async {
    final (places, contributions) = await _pumpRadar(tester, [_pendingGroomer]);

    expect(
      find.textContaining('Segnalato dagli utenti · in attesa di conferma (2/5)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Toelettatura Nuova'));
    await tester.pumpAndSettle();
    expect(find.text('Questo luogo esiste davvero qui?'), findsOneWidget);
    expect(find.text('Segnala un problema'), findsNothing);
    expect(find.textContaining('Fonte: Segnalato dagli utenti VetApp'), findsOneWidget);

    await tester.tap(find.text('Confermo'));
    await _settle(tester);

    expect(contributions.calls, ['vote:r1:true']);
    // The card closed and the radar reloaded to show the new count.
    expect(find.text('Confermo'), findsNothing);
    expect(places.requests, 2);
  });

  testWidgets('a reported dog park warns it may not be public and offers to write in',
      (tester) async {
    await _pumpRadar(tester, [_reportedDogPark]);

    expect(
      find.textContaining('Segnalata dagli utenti, verifica che sia un’area pubblica (1/5)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Area cani'));
    await tester.pumpAndSettle();

    expect(find.text('Non è un’area pubblica? Scrivici'), findsOneWidget);
    // Not confirmed yet: it can be confirmed or denied, but not rated.
    expect(find.text('Confermo'), findsOneWidget);
    expect(find.byTooltip('Dai 5 stelle'), findsNothing);
  });

  testWidgets('the reporter sees their own report without vote buttons', (tester) async {
    await _pumpRadar(tester, [_ownReport]);

    await tester.tap(find.text('Negozio Mio'));
    await tester.pumpAndSettle();

    expect(find.textContaining('L’hai segnalato tu'), findsOneWidget);
    expect(find.text('Confermo'), findsNothing);
    expect(find.text('Non è così'), findsNothing);
    expect(find.text('Scade tra 5 giorni se nessuno conferma.'), findsOneWidget);
  });

  testWidgets('the reporter can withdraw their report after confirming', (tester) async {
    final (places, contributions) = await _pumpRadar(tester, [_ownReport]);

    await tester.tap(find.text('Negozio Mio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ritira la mia segnalazione'));
    await tester.pumpAndSettle();
    expect(find.text('Ritirare la segnalazione?'), findsOneWidget);
    expect(contributions.calls, isEmpty);

    await tester.tap(find.text('Ritira'));
    await _settle(tester);

    expect(contributions.calls, ['withdraw:r2']);
    expect(find.text('Ritira la mia segnalazione'), findsNothing);
    expect(places.requests, 2);
  });

  testWidgets('someone else’s report cannot be withdrawn', (tester) async {
    await _pumpRadar(tester, [_pendingGroomer]);

    await tester.tap(find.text('Toelettatura Nuova'));
    await tester.pumpAndSettle();

    expect(find.text('Ritira la mia segnalazione'), findsNothing);
  });

  testWidgets('the rules are asked once, then the action goes through', (tester) async {
    final (_, contributions) = await _pumpRadar(tester, [_pendingGroomer], rulesAccepted: false);

    await tester.tap(find.text('Toelettatura Nuova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non è così'));
    await tester.pumpAndSettle();

    expect(find.text('Prima di segnalare o votare'), findsOneWidget);
    expect(find.text('Regole di prova.'), findsOneWidget);
    // "Accetto" stays disabled until the box is ticked.
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Accetto')).onPressed,
        isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Accetto'));
    await _settle(tester);

    expect(contributions.rulesAccepted, isTrue);
    expect(contributions.calls, ['vote:r1:false', 'vote:r1:false']);
  });

  testWidgets('declining the rules sends nothing more', (tester) async {
    final (_, contributions) = await _pumpRadar(tester, [_pendingGroomer], rulesAccepted: false);

    await tester.tap(find.text('Toelettatura Nuova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confermo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(contributions.calls, ['vote:r1:true']);
    expect(contributions.rulesAccepted, isFalse);
  });

  testWidgets('a public dog park shows its average and takes a star vote', (tester) async {
    final (_, contributions) = await _pumpRadar(tester, [_dogPark]);

    await tester.tap(find.text('Area cani Sempione'));
    await tester.pumpAndSettle();
    expect(find.text('Voto della community: 4,3 su 5 · 4 voti'), findsOneWidget);
    expect(find.textContaining('Il tuo voto: 3 su 5'), findsOneWidget);

    await tester.tap(find.byTooltip('Dai 5 stelle'));
    await _settle(tester);

    expect(contributions.calls, ['rate:park:5']);
    // The card stays open and shows the new vote straight away.
    expect(find.textContaining('Il tuo voto: 5 su 5'), findsOneWidget);
    expect(tester.widgetList<Icon>(find.byIcon(Icons.star_rounded)).length, 5);
  });

  testWidgets('a vote is still shown when the card reopens from data loaded before it',
      (tester) async {
    // The radar keeps answering with the park as it was before the vote.
    await _pumpRadar(tester, [_unratedDogPark]);

    await tester.tap(find.text('Area cani Nuova'));
    await tester.pumpAndSettle();
    expect(find.text('Voto della community: nessun voto ancora'), findsOneWidget);
    expect(find.textContaining('Tocca una stella per dare il tuo voto'), findsOneWidget);
    await tester.tap(find.byTooltip('Dai 4 stelle'));
    await _settle(tester);
    Navigator.of(tester.element(find.textContaining('Il tuo voto: 4 su 5'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Area cani Nuova'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Il tuo voto: 4 su 5'), findsOneWidget);
    expect(
      find.text('Voto della community: 1 voto · la media compare da 3 voti'),
      findsOneWidget,
    );
  });

  testWidgets('places that are not dog parks have no stars', (tester) async {
    await _pumpRadar(tester, [_clinic]);

    await tester.tap(find.text('Clinica Duomo'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Dai 5 stelle'), findsNothing);
  });

  testWidgets('an existing place can be reported as closed', (tester) async {
    final (_, contributions) = await _pumpRadar(tester, [_clinic]);

    await tester.tap(find.text('Clinica Duomo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Segnala un problema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ha chiuso o non esiste più'));
    await _settle(tester);

    expect(contributions.calls, ['problem:clinic:closed']);
  });

  testWidgets('a kind of report the backend switched off is not offered', (tester) async {
    final (_, contributions) = await _pumpRadar(tester, [_clinic]);
    contributions.problems = const [RadarProblem.duplicate, RadarProblem.wrongPosition];

    await tester.tap(find.text('Clinica Duomo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Segnala un problema'));
    await tester.pumpAndSettle();

    expect(find.text('Ha chiuso o non esiste più'), findsNothing);
    expect(find.text('È un doppione di un altro luogo'), findsOneWidget);
  });

  testWidgets('with reports switched off the card says so instead of asking', (tester) async {
    final (_, contributions) = await _pumpRadar(tester, [_clinic]);
    contributions.problems = const [];

    await tester.tap(find.text('Clinica Duomo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Segnala un problema'));
    await tester.pumpAndSettle();

    expect(find.text('Cosa non va in questo luogo?'), findsNothing);
    expect(find.text('Le segnalazioni non sono attive in questo momento.'), findsOneWidget);
    expect(contributions.calls, isEmpty);
  });

  testWidgets('reporting a missing place needs a category and a name', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeContributions();
    var reloaded = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReportMissingPlacePage(
          contributions: RadarContributions(
            repository: repository,
            consents: _FakeConsents(repository),
            onChanged: () => reloaded++,
          ),
          initialPosition: _milan,
          reverseGeocoder: _FakeReverseGeocoder(),
        ),
      ),
    );
    await _settle(tester);

    FilledButton sendButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Invia segnalazione'));

    // Only the categories the backend allows are offered.
    expect(find.widgetWithText(RadarChip, 'Veterinario'), findsOneWidget);
    expect(find.widgetWithText(RadarChip, 'Area cani'), findsNothing);
    expect(sendButton().onPressed, isNull);

    await tester.tap(find.widgetWithText(RadarChip, 'Toelettatura'));
    await tester.pump();
    expect(sendButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Toelettatura Bau');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Invia segnalazione'));
    await _settle(tester);

    expect(repository.calls, ['missing:grooming:Toelettatura Bau:Via Esempio 10, Milano']);
    expect(reloaded, 1);
  });
}
