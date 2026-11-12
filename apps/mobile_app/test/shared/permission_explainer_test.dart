import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/features/location/data/device_location_service.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/permissions/permission_explainer.dart';

/// A phone's position service whose permission the test controls.
class _FakeGeolocator extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.denied;
  LocationPermission afterRequest = LocationPermission.whileInUse;
  int requests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    permission = afterRequest;
    return afterRequest;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async => Position(
        latitude: 45.0,
        longitude: 9.0,
        timestamp: DateTime(2026, 10, 28),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

Future<BuildContext> _pump(WidgetTester tester, {Locale locale = const Locale('it')}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        captured = context;
        return const Scaffold();
      }),
    ),
  );
  return captured;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the window before the system dialog', () {
    testWidgets('says why, what happens if refused, and offers "Non ora" / "Continua"',
        (tester) async {
      final context = await _pump(tester);
      final answer = explainPermission(context, PermissionPurpose.location);
      await tester.pumpAndSettle();

      expect(find.text('Usare la tua posizione?'), findsOneWidget);
      expect(find.textContaining('tracciare le passeggiate sulla mappa'), findsOneWidget);
      expect(find.textContaining('Se rifiuti'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Non ora'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Continua'), findsOneWidget);

      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();
      expect(await answer, isTrue);
    });

    testWidgets('"Non ora" answers false', (tester) async {
      final context = await _pump(tester);
      final answer = explainPermission(context, PermissionPurpose.microphone);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Non ora'));
      await tester.pumpAndSettle();

      expect(await answer, isFalse);
    });

    testWidgets('a picker flow (camera) is explained once, after "Continua"', (tester) async {
      final context = await _pump(tester);

      var answer = explainPermission(context, PermissionPurpose.camera, onlyFirstTime: true);
      await tester.pumpAndSettle();
      expect(find.text('Scattare una foto o un video'), findsOneWidget);
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();
      expect(await answer, isTrue);

      // The second time it goes straight on, with no window.
      answer = explainPermission(context, PermissionPurpose.camera, onlyFirstTime: true);
      await tester.pumpAndSettle();
      expect(find.text('Scattare una foto o un video'), findsNothing);
      expect(await answer, isTrue);

      // Another purpose still gets its own first time.
      answer = explainPermission(context, PermissionPurpose.gallery, onlyFirstTime: true);
      await tester.pumpAndSettle();
      expect(find.text('Scegliere foto e video'), findsOneWidget);
      await tester.tap(find.text('Non ora'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);

      // "Non ora" is not remembered: asked again next time.
      answer = explainPermission(context, PermissionPurpose.gallery, onlyFirstTime: true);
      await tester.pumpAndSettle();
      expect(find.text('Scegliere foto e video'), findsOneWidget);
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();
      expect(await answer, isTrue);
    });

    test('only the phone permissions have a system dialog afterwards', () {
      expect(PermissionPurpose.camera.hasSystemDialog, isFalse);
      expect(PermissionPurpose.gallery.hasSystemDialog, isFalse);
      for (final purpose in [
        PermissionPurpose.location,
        PermissionPurpose.notifications,
        PermissionPurpose.walkNotifications,
        PermissionPurpose.microphone,
      ]) {
        expect(purpose.hasSystemDialog, isTrue, reason: purpose.name);
      }
    });

    test('with no navigator to show it on, the flow just goes on', () async {
      expect(await explainPermissionGlobally(PermissionPurpose.location), isTrue);
    });
  });

  group('every purpose reads in all five languages', () {
    for (final locale in AppLocalizations.supportedLocales) {
      test('${locale.languageCode}: title, why and what-if-refused are filled in', () {
        final l10n = lookupAppLocalizations(locale);
        final italian = lookupAppLocalizations(const Locale('it'));
        for (final purpose in PermissionPurpose.values) {
          for (final text in [purpose.title(l10n), purpose.why(l10n), purpose.ifRefused(l10n)]) {
            expect(text.trim(), isNotEmpty, reason: '${purpose.name} ${locale.languageCode}');
          }
          if (locale.languageCode != 'it') {
            expect(purpose.why(l10n), isNot(purpose.why(italian)),
                reason: '${purpose.name} is still Italian in ${locale.languageCode}');
          }
        }
        expect(l10n.permNotNow, isNotEmpty);
        expect(l10n.permContinue, isNotEmpty);
      });
    }

    testWidgets('German with large text still fits (the window scrolls)', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(builder: (c) {
            context = c;
            return const Scaffold();
          }),
        ),
      );

      unawaited(explainPermission(context, PermissionPurpose.camera));
      await tester.pumpAndSettle();

      expect(find.text('Foto oder Video aufnehmen'), findsOneWidget);
      expect(find.text('Weiter'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the position request', () {
    late GeolocatorPlatform previous;
    late _FakeGeolocator phone;

    setUp(() {
      previous = GeolocatorPlatform.instance;
      phone = _FakeGeolocator();
      GeolocatorPlatform.instance = phone;
    });

    tearDown(() => GeolocatorPlatform.instance = previous);

    test('"Non ora" in the explanation: Android is never asked', () async {
      final sampler = GeolocatorLocationSampler(explainFirst: () async => false);

      final result = await sampler.requestCurrentPosition();

      expect(result.failure, LocationRequestFailure.permissionDenied);
      expect(phone.requests, 0);
    });

    test('"Continua": the system dialog follows and the position is read', () async {
      var explained = 0;
      final sampler = GeolocatorLocationSampler(explainFirst: () async {
        explained++;
        return true;
      });

      final result = await sampler.requestCurrentPosition();

      expect(explained, 1);
      expect(phone.requests, 1);
      expect(result.isSuccess, isTrue);
    });

    test('already allowed: no explanation at all', () async {
      phone.permission = LocationPermission.whileInUse;
      var explained = 0;
      final sampler = GeolocatorLocationSampler(explainFirst: () async {
        explained++;
        return true;
      });

      final result = await sampler.requestCurrentPosition();

      expect(explained, 0);
      expect(result.isSuccess, isTrue);
    });

    test('refused for good: no explanation, no request', () async {
      phone.permission = LocationPermission.deniedForever;
      var explained = 0;
      final sampler = GeolocatorLocationSampler(explainFirst: () async {
        explained++;
        return true;
      });

      final result = await sampler.requestCurrentPosition();

      expect(explained, 0);
      expect(phone.requests, 0);
      expect(result.failure, LocationRequestFailure.permissionDeniedForever);
    });
  });
}
