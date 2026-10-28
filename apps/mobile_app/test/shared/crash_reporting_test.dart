import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/shared/crash/crash_reporting.dart';

class _FakeTransport implements CrashTransport {
  int starts = 0;
  int stops = 0;
  Object? startError;
  String? dsn;
  String? environment;
  String? release;

  @override
  Future<void> start({
    required String dsn,
    required String environment,
    required String release,
  }) async {
    if (startError != null) throw startError!;
    starts++;
    this.dsn = dsn;
    this.environment = environment;
    this.release = release;
  }

  @override
  Future<void> stop() async => stops++;
}

CrashReporting _reporting(
  _FakeTransport transport, {
  bool enabled = true,
  String dsn = 'https://example.invalid/1',
  bool isWeb = false,
}) {
  return CrashReporting(
    transport: transport,
    enabled: enabled,
    dsn: dsn,
    isWeb: isWeb,
    describeApp: () async => (environment: 'com.example.app', release: '1.2.3+4'),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tests are built without the flag and without an address: nothing can be sent', () {
    expect(kCrashReportingFlag, isFalse);
    expect(kSentryDsn, isEmpty);
    expect(CrashReporting.instance.isAvailable, isFalse);
    expect(CrashReporting.instance.isActive, isFalse);
  });

  group('a build that cannot send reports', () {
    for (final (name, make) in <(String, CrashReporting Function(_FakeTransport))>[
      ('without the flag', (t) => _reporting(t, enabled: false)),
      ('without the Sentry address', (t) => _reporting(t, dsn: '')),
      ('on web', (t) => _reporting(t, isWeb: true)),
    ]) {
      test('$name: consent or not, nothing starts and nothing is stored', () async {
        final transport = _FakeTransport();
        final reporting = make(transport);
        await const CrashConsentStore().write(true);

        await reporting.initialize();
        await reporting.applyConsent(true);

        expect(reporting.isAvailable, isFalse);
        expect(reporting.isActive, isFalse);
        expect(transport.starts, 0);
      });
    }
  });

  group('a build that can send reports, but the owner has not agreed', () {
    test('nothing starts at boot', () async {
      final transport = _FakeTransport();
      final reporting = _reporting(transport);

      await reporting.initialize();

      expect(reporting.isAvailable, isTrue);
      expect(reporting.isActive, isFalse);
      expect(transport.starts, 0);
    });

    test('a declined consent stays off', () async {
      final transport = _FakeTransport();
      final reporting = _reporting(transport);

      await reporting.applyConsent(false);

      expect(reporting.isActive, isFalse);
      expect(transport.starts, 0);
      expect(await const CrashConsentStore().read(), isFalse);
    });
  });

  group("with the owner's consent", () {
    test('agreeing starts the service with the app and its build named', () async {
      final transport = _FakeTransport();
      final reporting = _reporting(transport);

      await reporting.applyConsent(true);

      expect(reporting.isActive, isTrue);
      expect(transport.starts, 1);
      expect(transport.dsn, 'https://example.invalid/1');
      expect(transport.environment, 'com.example.app');
      expect(transport.release, '1.2.3+4');
      expect(await const CrashConsentStore().read(), isTrue);
    });

    test('the next launch starts it again at boot, without asking the network', () async {
      await const CrashConsentStore().write(true);
      final transport = _FakeTransport();
      final reporting = _reporting(transport);

      await reporting.initialize();

      expect(reporting.isActive, isTrue);
      expect(transport.starts, 1);
    });

    test('agreeing twice starts it once', () async {
      final transport = _FakeTransport();
      final reporting = _reporting(transport);

      await reporting.applyConsent(true);
      await reporting.applyConsent(true);

      expect(transport.starts, 1);
    });

    test('withdrawing consent stops it at once and the phone forgets the decision', () async {
      final transport = _FakeTransport();
      final reporting = _reporting(transport);
      await reporting.applyConsent(true);

      await reporting.applyConsent(false);

      expect(reporting.isActive, isFalse);
      expect(transport.stops, 1);
      expect(await const CrashConsentStore().read(), isFalse);

      // And the next launch does not start it.
      final next = _FakeTransport();
      await _reporting(next).initialize();
      expect(next.starts, 0);
    });

    test('signing out stops it and clears the local decision (the next account decides)',
        () async {
      final transport = _FakeTransport();
      final reporting = _reporting(transport);
      await reporting.applyConsent(true);

      await reporting.onSignedOut();

      expect(reporting.isActive, isFalse);
      expect(transport.stops, 1);
      expect(await const CrashConsentStore().read(), isFalse);
    });

    test('a service that fails to start leaves reporting off and never breaks the app',
        () async {
      final transport = _FakeTransport()..startError = StateError('bad address');
      final reporting = _reporting(transport);

      await reporting.applyConsent(true);

      expect(reporting.isActive, isFalse);
    });
  });

  group('scrubStackPath', () {
    test('cuts a file path to the package part, keeps package: and dart: paths', () {
      expect(scrubStackPath(r'C:\Users\mario\VetApp\apps\mobile_app\lib\a\b.dart'), 'lib/a/b.dart');
      expect(scrubStackPath('/home/mario/work/app/lib/x.dart'), 'lib/x.dart');
      expect(scrubStackPath('file:///C:/Users/mario/x/test/y_test.dart'), 'y_test.dart');
      expect(scrubStackPath('package:flutter/src/widgets/framework.dart'),
          'package:flutter/src/widgets/framework.dart');
      expect(scrubStackPath('dart:async'), 'dart:async');
      expect(scrubStackPath('libapp.so'), 'libapp.so');
      expect(scrubStackPath(null), isNull);
      expect(scrubStackPath(''), '');
    });
  });

  group('what leaves the phone (scrubCrashEvent)', () {
    SentryEvent dirtyEvent() {
      final event = SentryEvent(
        message: SentryMessage('Il mio cane Thor ha vomitato'),
        user: SentryUser(email: 'mario@example.com', id: 'user-1', ipAddress: '203.0.113.7'),
        request: SentryRequest(url: 'https://api.example.com/pets/abc?lat=45.1&lon=9.2'),
        breadcrumbs: [Breadcrumb(message: 'tapped "Invia" with text ciao')],
        exceptions: [
          SentryException(
            type: 'FormatException',
            value: 'Unexpected character in "Thor ha 3 anni, via Roma 1"',
            stackTrace: SentryStackTrace(frames: [
              SentryStackFrame(
                function: 'parsePet',
                absPath: r'C:\Users\mario.rossi\Documents\VetApp\apps\mobile_app\lib\pets\pet.dart',
                fileName: 'file:///C:/Users/mario.rossi/Documents/VetApp/apps/mobile_app/lib/pets/pet.dart',
              ),
              SentryStackFrame(
                function: 'build',
                absPath: 'package:vet_app_mobile/pets/pet_page.dart',
                fileName: 'package:vet_app_mobile/pets/pet_page.dart',
              ),
            ]),
          ),
        ],
        tags: {'owner': 'mario'},
        serverName: 'laptop-di-mario',
        contexts: Contexts(
          device: SentryDevice.fromJson({
            'model': 'Pixel 8',
            'name': 'Telefono di Mario Rossi',
            'id': 'a1b2c3d4-installation-id',
            'device_unique_identifier': 'imei-123456789',
          }),
          operatingSystem: SentryOperatingSystem(name: 'Android', version: '15'),
          app: SentryApp(
            version: '1.2.3',
            build: '4',
            deviceAppHash: 'hash-per-device',
            viewNames: ['/pets/thor', '/chat'],
          ),
        )..['flutter_error_details'] = {
            'context': 'building the pet name "Thor"',
            'information': 'phone 3331234567',
          },
      );
      // ignore: deprecated_member_use
      event.extra = {'draft': 'testo del messaggio'};
      return event;
    }

    test('keeps the exception type, the stack trace and the phone/app description', () {
      final scrubbed = scrubCrashEvent(dirtyEvent(), Hint())!;

      final exception = scrubbed.exceptions!.single;
      expect(exception.type, 'FormatException');
      expect(exception.stackTrace!.frames.map((frame) => frame.function), ['parsePet', 'build']);
      expect(scrubbed.contexts.device!.model, 'Pixel 8');
      expect(scrubbed.contexts.operatingSystem!.name, 'Android');
      expect(scrubbed.contexts.app!.version, '1.2.3');
    });

    test('removes what identifies the phone: its name, its installation id, the app hash', () {
      final scrubbed = scrubCrashEvent(dirtyEvent(), Hint())!;

      final device = scrubbed.contexts.device!;
      expect(device.model, 'Pixel 8', reason: 'the model is what the report is for');
      expect(device.name, isNull);
      expect(device.deviceUniqueIdentifier, isNull);
      final app = scrubbed.contexts.app!;
      expect(app.deviceAppHash, isNull);
      expect(app.viewNames, isNull);
      expect(app.version, '1.2.3');
      final json = scrubbed.toJson().toString();
      for (final secret in ['Mario', 'a1b2c3d4', 'imei-', 'hash-per-device', '/pets/thor']) {
        expect(json, isNot(contains(secret)), reason: secret);
      }
    });

    test('stack frames carry no folder of the build machine, package paths are kept', () {
      final scrubbed = scrubCrashEvent(dirtyEvent(), Hint())!;
      final frames = scrubbed.exceptions!.single.stackTrace!.frames;

      expect(frames[0].absPath, 'lib/pets/pet.dart');
      expect(frames[0].fileName, 'lib/pets/pet.dart');
      expect(frames[1].absPath, 'package:vet_app_mobile/pets/pet_page.dart');
      expect(scrubbed.toJson().toString(), isNot(contains('mario.rossi')));
    });

    test(
        'removes the exception text, any message, the user, the request, breadcrumbs, '
        'extra data, tags and the other contexts', () {
      final scrubbed = scrubCrashEvent(dirtyEvent(), Hint())!;

      expect(scrubbed.exceptions!.single.value, isNull);
      expect(scrubbed.message, isNull);
      expect(scrubbed.user, isNull);
      expect(scrubbed.request, isNull);
      expect(scrubbed.breadcrumbs, isNull);
      // ignore: deprecated_member_use
      expect(scrubbed.extra, isNull);
      expect(scrubbed.tags, isNull);
      expect(scrubbed.serverName, isNull);
      expect(scrubbed.contexts.containsKey('flutter_error_details'), isFalse);
    });

    test('nothing of what the owner wrote survives anywhere in the event', () {
      final json = scrubCrashEvent(dirtyEvent(), Hint())!.toJson().toString();

      for (final secret in [
        'Thor',
        'mario',
        'example.com',
        'Roma',
        '3331234567',
        'ciao',
        '203.0.113',
      ]) {
        expect(json, isNot(contains(secret)), reason: secret);
      }
    });
  });
}
