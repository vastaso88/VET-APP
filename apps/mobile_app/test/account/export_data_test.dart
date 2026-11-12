import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/account/data/account_export_remote_data_source.dart';
import 'package:vet_app_mobile/features/account/data/export_file_fetcher.dart';
import 'package:vet_app_mobile/features/account/data/export_workspace.dart';
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

class _FakeFetcher implements ExportFileFetcher {
  _FakeFetcher({required this.size, this.failing = const {}, this.gate});

  final int size;
  final Set<String> failing;
  final Future<void>? gate;

  @override
  Future<int?> sizeOf(String url) async => size;

  @override
  Future<Uint8List?> download(String url) async {
    await gate;
    if (failing.contains(url)) return null;
    return Uint8List.fromList(utf8.encode('content of $url'));
  }
}

class _CountingWorkspace extends MemoryExportWorkspace {
  bool disposed = false;

  @override
  Future<void> dispose() async {
    disposed = true;
    await super.dispose();
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

/// First step: asks the server and waits for the "ready" choice.
Future<void> _fetch(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('export-data-button')));
  await tester.pumpAndSettle();
}

class _NoFilesFetcher implements ExportFileFetcher {
  @override
  Future<int?> sizeOf(String url) async => null;

  @override
  Future<Uint8List?> download(String url) async => null;
}

Future<void> _pump(
  WidgetTester tester, {
  required AccountExportRemoteDataSource source,
  AccountExportSaver? saver,
  ExportFileFetcher? fetcher,
  Future<ExportWorkspace> Function()? workspaceFactory,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('it'),
      home: ExportDataPage(
        dataSource: source,
        saver: saver,
        fetcher: fetcher ?? _NoFilesFetcher(),
        workspaceFactory: workspaceFactory ?? () async => MemoryExportWorkspace(),
        clock: () => DateTime(2026, 11, 9),
      ),
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

      await _fetch(tester);
      expect(find.byKey(const ValueKey('export-estimate')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('export-json-button')));
      await tester.pumpAndSettle();

      expect(source.calls, 1);
      expect(saved?.fileName, 'quokka-dati-2026-10-28.json');
      expect(find.text('File salvato.'), findsOneWidget);
    });

    testWidgets('cancelling the picker shows no message', (tester) async {
      await _pump(tester, source: _FakeSource(Result.success(_file())), saver: (_, __) async => false);

      await _fetch(tester);
      await tester.tap(find.byKey(const ValueKey('export-json-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('export-data-outcome')), findsNothing);
      // The owner can choose again without a new request to the server.
      expect(find.byKey(const ValueKey('export-json-button')), findsOneWidget);
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

      await _fetch(tester);
      await tester.tap(find.byKey(const ValueKey('export-json-button')));
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
      expect(find.byKey(const ValueKey('export-zip-button')), findsOneWidget);
    });

    group('the readable zip', () {
      final withFiles = AccountExportFile(
        fileName: 'quokka-dati-2026-11-09.json',
        bytes: Uint8List.fromList(utf8.encode(jsonEncode({
          'format_version': '1',
          'generated_at': '2026-11-09T10:00:00+00:00',
          'account': {'id': 'u1'},
          'data': {
            'pet_profiles': [
              {'id': 'p1', 'name': 'Luna'},
            ],
            'pet_photos': [
              {'id': 'f1', 'pet_id': 'p1', 'storage_path': 'u1/p1/a.jpg'},
            ],
          },
          'files': [
            {'path': 'u1/p1/a.jpg', 'kind': 'pet_media', 'url': 'https://files.test/a.jpg'},
            {'path': 'u1/p1/b.jpg', 'kind': 'pet_media', 'url': 'https://files.test/b.jpg'},
          ],
        }))),
      );

      testWidgets('shows how many files and how big before starting, then saves a .zip',
          (tester) async {
        final fetcher = _FakeFetcher(size: 1536 * 1024);
        AccountExportFile? saved;
        await _pump(
          tester,
          source: _FakeSource(Result.success(withFiles)),
          fetcher: fetcher,
          saver: (file, title) async {
            saved = file;
            return true;
          },
        );

        await _fetch(tester);
        expect(find.text('2 file da scaricare, circa 3 MB'), findsOneWidget);
        expect(find.textContaining('dati sensibili'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('export-zip-button')));
        await tester.pumpAndSettle();

        expect(saved?.fileName, 'quokka-dati-2026-11-09.zip');
        final names = ZipDecoder().decodeBytes(saved!.bytes).files.map((f) => f.name).toList();
        expect(names, containsAll(['dati.json', 'leggimi.html', 'foto/001-a.jpg', 'foto/002-b.jpg']));
        expect(find.text('File salvato.'), findsOneWidget);
      });

      testWidgets('a file that does not download still gives a zip and says so', (tester) async {
        AccountExportFile? saved;
        await _pump(
          tester,
          source: _FakeSource(Result.success(withFiles)),
          fetcher: _FakeFetcher(size: 10, failing: {'https://files.test/b.jpg'}),
          saver: (file, title) async {
            saved = file;
            return true;
          },
        );

        await _fetch(tester);
        await tester.tap(find.byKey(const ValueKey('export-zip-button')));
        await tester.pumpAndSettle();

        expect(saved, isNotNull);
        expect(find.textContaining('1 file non si è scaricato'), findsOneWidget);
        final html = utf8.decode(ZipDecoder()
            .decodeBytes(saved!.bytes)
            .files
            .firstWhere((f) => f.name == 'leggimi.html')
            .content as List<int>);
        expect(html, contains('b.jpg'));
      });

      testWidgets('cancelling during the download saves nothing and cleans up', (tester) async {
        final gate = Completer<void>();
        final workspace = _CountingWorkspace();
        var saves = 0;
        await _pump(
          tester,
          source: _FakeSource(Result.success(withFiles)),
          fetcher: _FakeFetcher(size: 10, gate: gate.future),
          workspaceFactory: () async => workspace,
          saver: (file, title) async {
            saves++;
            return true;
          },
        );

        await _fetch(tester);
        await tester.tap(find.byKey(const ValueKey('export-zip-button')));
        await tester.pump();
        expect(find.byKey(const ValueKey('export-progress')), findsOneWidget);
        expect(find.textContaining('0 di 2'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('export-cancel')));
        gate.complete();
        await tester.pumpAndSettle();

        expect(saves, 0);
        expect(workspace.disposed, isTrue);
        expect(find.text('Operazione annullata. Nessun file è stato salvato.'), findsOneWidget);
        // Back to the choice: no new request to the server is needed.
        expect(find.byKey(const ValueKey('export-zip-button')), findsOneWidget);
      });

      testWidgets('a huge export offers only the data', (tester) async {
        await _pump(
          tester,
          source: _FakeSource(Result.success(withFiles)),
          fetcher: _FakeFetcher(size: 300 * 1024 * 1024),
        );

        await _fetch(tester);

        expect(find.byKey(const ValueKey('export-too-big')), findsOneWidget);
        expect(
            tester.widget<FilledButton>(find.byKey(const ValueKey('export-zip-button'))).onPressed, isNull);
        expect(find.byKey(const ValueKey('export-json-button')), findsOneWidget);
      });

      for (final (variant, locale, one, many) in [
        ('en-GB', 'en', '1 file to download, about 2 KB', '2 files to download, about 4 KB'),
        ('es', 'es', '1 archivo por descargar, unos 2 KB', '2 archivos por descargar, unos 4 KB'),
        ('de', 'de', '1 Datei zum Herunterladen, etwa 2 KB', '2 Dateien zum Herunterladen, etwa 4 KB'),
        ('fr', 'fr', '1 fichier à télécharger, environ 2 KB', '2 fichiers à télécharger, environ 4 KB'),
      ]) {
        testWidgets('the file count has a singular and a plural ($locale)', (tester) async {
          await useLanguageVariant(variant);
          Future<void> pumpWith(int files) async {
            final export = AccountExportFile(
              fileName: 'x.json',
              bytes: Uint8List.fromList(utf8.encode(jsonEncode({
                'files': [
                  for (var i = 0; i < files; i++)
                    {'path': 'a/$i.jpg', 'kind': 'pet_media', 'url': 'https://files.test/$i'},
                ],
              }))),
            );
            await tester.pumpWidget(
              MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: Locale(locale),
                home: ExportDataPage(
                  key: ValueKey('page-$files'),
                  dataSource: _FakeSource(Result.success(export)),
                  fetcher: _FakeFetcher(size: 2048),
                  workspaceFactory: () async => MemoryExportWorkspace(),
                ),
              ),
            );
            await _fetch(tester);
          }

          await pumpWith(1);
          expect(find.text(one), findsOneWidget);
          await pumpWith(2);
          expect(find.text(many), findsOneWidget);
        });
      }

      testWidgets('two files that do not download use the plural', (tester) async {
        await _pump(
          tester,
          source: _FakeSource(Result.success(withFiles)),
          fetcher: _FakeFetcher(
            size: 10,
            failing: {'https://files.test/a.jpg', 'https://files.test/b.jpg'},
          ),
          saver: (file, title) async => true,
        );

        await _fetch(tester);
        await tester.tap(find.byKey(const ValueKey('export-zip-button')));
        await tester.pumpAndSettle();

        expect(find.textContaining('2 file non si sono scaricati'), findsOneWidget);
      });

      test('the missing-files message has a singular and a plural in every language', () {
        const expected = {
          'it': ('1 file non si è scaricato', '3 file non si sono scaricati'),
          'en': ('1 file could not be downloaded', '3 files could not be downloaded'),
          'es': ('1 archivo no se pudo descargar', '3 archivos no se pudieron descargar'),
          'de': ('1 Datei konnte nicht heruntergeladen werden', '3 Dateien konnten nicht heruntergeladen werden'),
          'fr': ("1 fichier n'a pas pu être téléchargé", "3 fichiers n'ont pas pu être téléchargés"),
        };
        expected.forEach((code, texts) {
          final l10n = lookupAppLocalizations(Locale(code));
          expect(l10n.accountExportZipDoneMissing(1), contains(texts.$1), reason: code);
          expect(l10n.accountExportZipDoneMissing(3), contains(texts.$2), reason: code);
          expect(l10n.accountExportZipDoneMissing(1), isNot(contains('{')), reason: code);
        });
      });

      testWidgets('with no files it says so and still offers both', (tester) async {
        await _pump(tester, source: _FakeSource(Result.success(_file())));

        await _fetch(tester);

        expect(find.text('Non ci sono foto né allegati: solo i dati.'), findsOneWidget);
      });
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
