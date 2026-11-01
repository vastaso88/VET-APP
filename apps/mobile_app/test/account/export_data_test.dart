import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/account/data/account_export_remote_data_source.dart';
import 'package:vet_app_mobile/features/account/presentation/pages/export_data_page.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

import '../territory/territory_test_helpers.dart';

class _Config extends AppRuntimeConfigLoader {
  const _Config();

  @override
  AppRuntimeConfig load() => const AppRuntimeConfig(
        environment: AppEnvironment.development,
        appName: 'test',
        apiBaseUrl: 'https://api.test',
        supabaseUrl: '',
        supabaseAnonKey: '',
        logLevel: 'INFO',
        enableTelemetry: false,
      );
}

class _SlowSource implements AccountExportRemoteDataSource {
  _SlowSource(this._pending);

  final Future<Result<AccountExportFile>> _pending;
  int calls = 0;

  @override
  Future<Result<AccountExportFile>> fetch() {
    calls++;
    return _pending;
  }
}

class _FakeSource implements AccountExportRemoteDataSource {
  _FakeSource(this._result);

  final Result<AccountExportFile> _result;
  int calls = 0;

  @override
  Future<Result<AccountExportFile>> fetch() async {
    calls++;
    return _result;
  }
}

AccountExportFile _file() => AccountExportFile(
      fileName: 'quokka-dati-2026-10-28.json',
      bytes: Uint8List.fromList(utf8.encode('{"format_version":"1"}')),
    );

Future<void> _pump(
  WidgetTester tester, {
  required AccountExportRemoteDataSource source,
  AccountExportSaver? saver,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('it'),
      home: ExportDataPage(dataSource: source, saver: saver),
    ),
  );
}

void main() {
  setUp(() async => useLanguageVariant('it'));
  tearDown(resetTerritoryForTest);

  group('the page', () {
    testWidgets('explains what the file holds and offers the button', (tester) async {
      await _pump(tester, source: _FakeSource(Result.success(_file())));

      expect(find.byKey(const ValueKey('export-data-button')), findsOneWidget);
      expect(find.text('Scarica i miei dati'), findsWidgets);
      expect(find.textContaining('15 minuti'), findsOneWidget);
      expect(find.textContaining('dati sensibili'), findsOneWidget);
    });

    testWidgets('the file is saved with the system picker and a confirmation is shown',
        (tester) async {
      final source = _FakeSource(Result.success(_file()));
      AccountExportFile? saved;
      await _pump(tester, source: source, saver: (file, title) async {
        saved = file;
        return true;
      });

      await tester.tap(find.byKey(const ValueKey('export-data-button')));
      await tester.pumpAndSettle();

      expect(source.calls, 1);
      expect(saved?.fileName, 'quokka-dati-2026-10-28.json');
      expect(find.text('File salvato.'), findsOneWidget);
    });

    testWidgets('cancelling the picker shows no message', (tester) async {
      await _pump(tester, source: _FakeSource(Result.success(_file())), saver: (_, __) async => false);

      await tester.tap(find.byKey(const ValueKey('export-data-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('export-data-outcome')), findsNothing);
    });

    testWidgets('a 429 is explained and not retried', (tester) async {
      final source = _FakeSource(
        Result.failure(
          const AppNetworkError(code: accountExportRateLimitedCode, message: 'x'),
        ),
      );
      var saves = 0;
      await _pump(tester, source: source, saver: (_, __) async {
        saves++;
        return true;
      });

      await tester.tap(find.byKey(const ValueKey('export-data-button')));
      await tester.pumpAndSettle();

      expect(find.text('Hai già richiesto i dati da poco: riprova tra qualche minuto'), findsOneWidget);
      expect(source.calls, 1, reason: 'no automatic retry');
      expect(saves, 0);
      // The button is available again for a later, deliberate request.
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('export-data-button'))).onPressed,
          isNotNull);
    });

    testWidgets('any other failure shows a generic message', (tester) async {
      final source = _FakeSource(
        Result.failure(const AppNetworkError(code: 'account_export_http_500', message: 'x')),
      );
      await _pump(tester, source: source);

      await tester.tap(find.byKey(const ValueKey('export-data-button')));
      await tester.pumpAndSettle();

      expect(find.text('Non sono riuscito a preparare i dati. Riprova tra poco.'), findsOneWidget);
    });

    testWidgets('a failure to save the file is reported', (tester) async {
      await _pump(
        tester,
        source: _FakeSource(Result.success(_file())),
        saver: (_, __) async => throw Exception('disk full'),
      );

      await tester.tap(find.byKey(const ValueKey('export-data-button')));
      await tester.pumpAndSettle();

      expect(find.text('Non sono riuscito a salvare il file. Riprova.'), findsOneWidget);
    });

    testWidgets('while it works the button is disabled, so a second tap cannot ask again',
        (tester) async {
      final gate = Completer<Result<AccountExportFile>>();
      final source = _SlowSource(gate.future);
      await _pump(tester, source: source, saver: (_, __) async => true);

      await tester.tap(find.byKey(const ValueKey('export-data-button')));
      await tester.pump();

      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('export-data-button'))).onPressed,
          isNull);
      expect(find.text('Preparo i tuoi dati…'), findsOneWidget);

      gate.complete(Result.success(_file()));
      await tester.pumpAndSettle();
      expect(source.calls, 1);
      expect(find.text('File salvato.'), findsOneWidget);
    });

    testWidgets('German uses Sie', (tester) async {
      await useLanguageVariant('de');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: ExportDataPage(dataSource: _FakeSource(Result.success(_file()))),
        ),
      );

      expect(find.textContaining('Sie erhalten eine Datei'), findsOneWidget);
    });
  });

  group('the request', () {
    HttpAccountExportRemoteDataSource source(MockClient client, {String? token = 'jwt'}) =>
        HttpAccountExportRemoteDataSource(
          client: client,
          configLoader: const _Config(),
          tokenProvider: () => token,
          clock: () => DateTime(2026, 10, 28, 9, 30),
        );

    test('GET /account/export with the session token, file named by the day', () async {
      late http.Request seen;
      final result = await source(MockClient((request) async {
        seen = request;
        return http.Response('{"format_version":"1","data":{}}', 200,
            headers: {'content-type': 'application/json'});
      })).fetch();

      expect(seen.method, 'GET');
      expect(seen.url.toString(), 'https://api.test/account/export');
      expect(seen.headers['Authorization'], 'Bearer jwt');
      final file = result.fold<AccountExportFile?>(onSuccess: (v) => v, onFailure: (_) => null);
      expect(file?.fileName, 'quokka-dati-2026-10-28.json');
      expect(utf8.decode(file!.bytes), contains('"format_version":"1"'));
    });

    test('429 becomes the rate-limited error', () async {
      final result = await source(MockClient((_) async => http.Response(
            '{"detail":"Troppe richieste: riprova tra poco."}',
            429,
            headers: {'retry-after': '600'},
          ))).fetch();

      expect(result.fold<String>(onSuccess: (_) => '', onFailure: (e) => e.code),
          accountExportRateLimitedCode);
    });

    test('401, 500 and a network error are plain failures, never a file', () async {
      for (final status in [401, 500]) {
        final result = await source(MockClient((_) async => http.Response('{}', status))).fetch();
        expect(result.isFailure, isTrue, reason: '$status');
      }
      final offline = await source(MockClient((_) async => throw http.ClientException('offline'))).fetch();
      expect(offline.isFailure, isTrue);
    });
  });
}
