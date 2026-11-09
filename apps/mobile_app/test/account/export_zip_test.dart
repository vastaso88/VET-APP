import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/account/data/account_export_zip_builder.dart';
import 'package:vet_app_mobile/features/account/data/export_file_fetcher.dart';
import 'package:vet_app_mobile/features/account/data/export_workspace.dart';
import 'package:vet_app_mobile/features/account/data/export_workspace_io.dart';
import 'package:vet_app_mobile/features/account/domain/account_export_readme.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

ExportReadmeLabels _labels() => ExportReadmeLabels(
      htmlLang: 'it',
      title: 'I tuoi dati',
      intro: 'Intro',
      sensitive: 'Dati sensibili: conservali con cura',
      generatedOn: (date) => 'Creato il $date',
      sectionAccount: 'Account',
      sectionPets: 'Animali',
      petSheet: 'Scheda',
      clinicalRecord: 'Cartella clinica',
      conditions: 'Condizioni',
      weights: 'Pesate',
      reminders: 'Promemoria',
      walks: 'Passeggiate',
      media: 'Foto e video',
      chat: 'Chat',
      attachments: 'Allegati',
      marketplace: 'Mercatino',
      consents: 'Consensi',
      subscription: 'Abbonamento',
      location: 'Posizione',
      other: 'Altri dati',
      missing: 'File non scaricati',
      missingIntro: 'Non si sono scaricati.',
      empty: 'Nessun dato',
      roleUser: 'Tu',
      roleAssistant: 'Assistente',
      yes: 'Sì',
      no: 'No',
      routePoints: (count) => '$count punti',
      fields: const {'name': 'Nome', 'notes': 'Note', 'title': 'Titolo', 'started_at': 'Inizio'},
    );

String _date(DateTime date, {required bool withTime}) =>
    '${date.day}/${date.month}/${date.year}${withTime ? ' ${date.hour}:${date.minute.toString().padLeft(2, '0')}' : ''}';

/// An export that holds hostile text in every place a person can write.
Map<String, dynamic> _hostileExport() => {
      'format_version': '1',
      'generated_at': '2026-11-09T10:15:00+00:00',
      'account': {
        'id': 'u1',
        'email': '"><script>alert(1)</script>@example.com',
        'profile': {'display_name': '<img src=x onerror=alert(1)>', 'phone': '+39 000'},
      },
      'data': {
        'pet_profiles': [
          {
            'id': 'p1',
            'name': '<script>alert("pet")</script>',
            'species': "Cane'; DROP TABLE x;--",
            'notes': '<b onmouseover="steal()">note</b> & </td></tr><iframe src="https://evil.example"></iframe>',
          },
        ],
        'clinical_events': [
          {'id': 'e1', 'pet_id': 'p1', 'title': '<style>*{display:none}</style>Vaccino', 'created_at': '2026-03-02T09:30:00Z'},
        ],
        'pet_weight_measurements': [
          {'id': 'w1', 'pet_id': 'p1', 'measured_at': '2026-04-01', 'weight_kg': 12.5, 'note': 'javascript:alert(1)'},
        ],
        'dog_walks': [
          {'id': 'd1', 'pet_id': 'p1', 'started_at': '2026-05-01T07:00:00Z', 'route': [1, 2, 3], 'is_favorite': true},
        ],
        'pet_photos': [
          {'id': 'ph1', 'pet_id': 'p1', 'storage_path': 'u1/p1/cane.jpg'},
          {'id': 'ph2', 'pet_id': 'p1', 'storage_path': 'u1/p1/lost.jpg'},
        ],
        'conversations': [
          {
            'id': 'c1',
            'pet_id': 'p1',
            'title': '</h3><script>1</script>',
            'messages': [
              {'role': 'user', 'content': '<script>alert("msg")</script>', 'created_at': '2026-06-01T10:00:00Z'},
              {'role': 'assistant', 'content': 'Risposta <a href="javascript:evil()">link</a>'},
            ],
          },
        ],
        'chat_attachments': [
          {'id': 'a1', 'conversation_id': 'c1', 'storage_key': 'u1/c1/referto.pdf', 'original_filename': '<b>referto</b>.pdf', 'content_type': 'application/pdf'},
        ],
        'marketplace_listings': [
          {'id': 'm1', 'title': '"><script>x</script>', 'description': 'Cuccia', 'price_cents': 2500, 'photo_urls': ['https://cdn.example/x.jpg']},
        ],
        'account_consents': [
          {'owner_id': 'u1', 'consents': {'marketing': true, 'privacy_policy': {'granted': false}}},
        ],
        'subscriptions': [
          {'owner_id': 'u1', 'plan': 'plus', 'trial_ends_at': '2026-11-20T00:00:00Z'},
        ],
        'radar_place_ratings': [
          {'id': 'r1', 'place_id': '<img src=x>', 'stars': 5},
        ],
      },
      'files': [
        {'bucket': 'pet-photos', 'path': 'u1/p1/cane.jpg', 'kind': 'pet_media', 'url': 'https://files.test/cane.jpg', 'note': null},
        {'bucket': 'pet-photos', 'path': 'u1/p1/lost.jpg', 'kind': 'pet_media', 'url': 'https://files.test/lost.jpg', 'note': null},
        {'bucket': 'chat-attachments', 'path': 'u1/c1/referto.pdf', 'kind': 'chat_attachment', 'url': 'https://files.test/referto.pdf', 'note': null},
        {'bucket': 'pet-photos', 'path': 'u1/p1/senza-link.jpg', 'kind': 'pet_media', 'url': null, 'note': 'link not generated'},
      ],
    };

class _Fetcher implements ExportFileFetcher {
  _Fetcher({this.failing = const {}, this.onDownload});

  final Set<String> failing;
  final void Function(String url)? onDownload;
  final List<String> downloaded = [];

  @override
  Future<int?> sizeOf(String url) async => failing.contains(url) ? null : 1000;

  @override
  Future<Uint8List?> download(String url) async {
    downloaded.add(url);
    onDownload?.call(url);
    if (failing.contains(url)) return null;
    return Uint8List.fromList(utf8.encode('content of $url'));
  }
}

/// A workspace that records its end, to prove the cleanup.
class _SpyWorkspace extends MemoryExportWorkspace {
  bool disposed = false;

  @override
  Future<void> dispose() async {
    disposed = true;
    await super.dispose();
  }
}

AccountExportZipBuilder _builder(ExportFileFetcher fetcher, ExportWorkspace workspace) =>
    AccountExportZipBuilder(
      fetcher: fetcher,
      workspaceFactory: () async => workspace,
      labels: _labels(),
      formatDate: _date,
    );

Archive _open(Uint8List bytes) => ZipDecoder().decodeBytes(bytes);

String _text(ArchiveFile file) => utf8.decode(file.content as List<int>);

void main() {
  final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(_hostileExport())));

  group('the readable page escapes everything the owner (or anyone) wrote', () {
    late String html;
    setUp(() {
      html = renderExportReadme(
        export: _hostileExport(),
        labels: _labels(),
        fileLinks: const {'u1/p1/cane.jpg': 'foto/001-cane.jpg', 'u1/c1/referto.pdf': 'allegati/003-referto.pdf'},
        missingFiles: const [MissingExportFile(name: 'lost.jpg', reason: 'download')],
        formatDate: _date,
      );
    });

    test('no script, no event handler, no foreign element comes out of the data', () {
      expect(RegExp('<script', caseSensitive: false).hasMatch(html), isFalse);
      expect(html.contains('<iframe'), isFalse);
      expect(RegExp(r'<img[^>]*onerror', caseSensitive: false).hasMatch(html), isFalse);
      expect(RegExp(r'<[a-z][^>]*\son[a-z]+\s*=', caseSensitive: false).hasMatch(html), isFalse);
      expect(html.contains('<style>*{display:none}'), isFalse);
      expect(html.contains('<b onmouseover'), isFalse);
      // The hostile text is still there, as plain text.
      expect(html, contains('&lt;script&gt;alert(&quot;pet&quot;)&lt;&#47;script&gt;'));
      expect(html, contains('&lt;iframe'));
      expect(html, contains('DROP TABLE x;--'));
    });

    test('the only tags are the ones the page itself writes', () {
      final allowed = {
        'html', 'head', 'meta', 'title', 'style', 'body', 'h1', 'h2', 'h3', 'h4', 'p', 'strong', 'section', 'div',
        'dl', 'dt', 'dd', 'a', 'img', 'ul', 'li', 'pre', 'span', 'br',
      };
      final tags = RegExp(r'</?([a-zA-Z][a-zA-Z0-9]*)').allMatches(html).map((m) => m.group(1)!.toLowerCase());
      expect(tags.toSet().difference(allowed), isEmpty);
      // One <style> and one <title>, both ours.
      expect('<style>'.allMatches(html).length, 1);
    });

    test('nothing external: a policy that forbids scripts and remote resources, no absolute link', () {
      expect(html, contains('Content-Security-Policy'));
      expect(html, contains("default-src 'none'"));
      expect(RegExp(r'''(src|href)\s*=\s*["']?(https?:|//|javascript:|data:)''', caseSensitive: false).hasMatch(html),
          isFalse);
      // The public photo address of a listing is not turned into a link or an image.
      expect(html.contains('cdn.example'), isFalse);
    });

    test('files are called by relative paths, images shown, others linked', () {
      expect(html, contains('<img class="photo" src="foto/001-cane.jpg"'));
      expect(html, contains('<a href="allegati/003-referto.pdf">'));
      expect(html.contains('lost.jpg') && html.contains('File non scaricati'), isTrue);
    });

    test('dates are readable, booleans are words, routes are counted, prices are money', () {
      // Text goes through the full escape, slash included ("&#47;" shows as "/").
      expect(html, contains('2&#47;3&#47;2026 '));
      expect(html, contains('1&#47;4&#47;2026'));
      expect(html, contains('3 punti'));
      expect(html, contains('Sì'));
      expect(html, contains('25.00'));
      expect(html.contains('2026-03-02T09:30:00Z'), isFalse);
    });

    test('sections: account, pet record, chat with roles and attachment, consents, subscription', () {
      for (final text in ['Account', 'Animali', 'Cartella clinica', 'Pesate', 'Passeggiate', 'Foto e video',
        'Chat', 'Allegati', 'Mercatino', 'Consensi', 'Abbonamento', 'Altri dati', 'Tu', 'Assistente']) {
        expect(html, contains(text), reason: text);
      }
    });
  });

  group('the zip', () {
    test('holds dati.json untouched, leggimi.html and the files in foto/ and allegati/', () async {
      final fetcher = _Fetcher();
      final zip = await _builder(fetcher, MemoryExportWorkspace())
          .build(jsonBytes: jsonBytes, export: _hostileExport());

      final archive = _open(zip.bytes);
      final names = archive.files.map((f) => f.name).toList();
      expect(names, containsAll(['dati.json', 'leggimi.html', 'foto/001-cane.jpg', 'foto/002-lost.jpg', 'allegati/003-referto.pdf']));
      expect(names.where((n) => n.contains('..')), isEmpty);
      expect(archive.files.firstWhere((f) => f.name == 'dati.json').content, jsonBytes);
      expect(_text(archive.files.firstWhere((f) => f.name == 'foto/001-cane.jpg')), 'content of https://files.test/cane.jpg');
      final html = _text(archive.files.firstWhere((f) => f.name == 'leggimi.html'));
      expect(html, contains('foto/001-cane.jpg'));
      expect(html, contains('allegati/003-referto.pdf'));
      expect(zip.downloaded, 3);
      expect(zip.missing, hasLength(1), reason: 'only the one without a link');
    });

    test('a file that does not download does not stop the zip: it is listed in the page', () async {
      final fetcher = _Fetcher(failing: {'https://files.test/lost.jpg'});
      final zip = await _builder(fetcher, MemoryExportWorkspace())
          .build(jsonBytes: jsonBytes, export: _hostileExport());

      final archive = _open(zip.bytes);
      final names = archive.files.map((f) => f.name);
      expect(names, isNot(contains('foto/002-lost.jpg')));
      expect(names, containsAll(['dati.json', 'leggimi.html', 'foto/001-cane.jpg', 'allegati/003-referto.pdf']));
      final html = _text(archive.files.firstWhere((f) => f.name == 'leggimi.html'));
      expect(html, contains('File non scaricati'));
      expect(html, contains('lost.jpg'));
      expect(html, contains('senza-link.jpg'), reason: 'a file the server gave no link for is listed too');
      expect(zip.missing.map((m) => m.name), containsAll(['lost.jpg', 'senza-link.jpg']));
    });

    test('progress counts every file', () async {
      final seen = <String>[];
      await _builder(_Fetcher(), MemoryExportWorkspace()).build(
        jsonBytes: jsonBytes,
        export: _hostileExport(),
        onProgress: (done, total) => seen.add('$done/$total'),
      );
      expect(seen.first, '0/3');
      expect(seen.last, '3/3');
    });

    test('an export without files is just the two documents', () async {
      final zip = await _builder(_Fetcher(), MemoryExportWorkspace())
          .build(jsonBytes: Uint8List.fromList(utf8.encode('{}')), export: const {});
      expect(_open(zip.bytes).files.map((f) => f.name), ['dati.json', 'leggimi.html']);
    });
  });

  group('cleanup', () {
    test('cancelling removes the temporary files and throws', () async {
      final workspace = _SpyWorkspace();
      final token = ExportCancelToken();
      final fetcher = _Fetcher(onDownload: (_) => token.cancel());

      await expectLater(
        _builder(fetcher, workspace).build(jsonBytes: jsonBytes, export: _hostileExport(), cancel: token),
        throwsA(isA<ExportCancelled>()),
      );
      expect(workspace.disposed, isTrue);
      expect(workspace.isEmpty, isTrue);
    });

    test('an error removes them too', () async {
      final workspace = _SpyWorkspace();
      final fetcher = _Fetcher(onDownload: (_) => throw StateError('boom'));

      await expectLater(
        _builder(fetcher, workspace).build(jsonBytes: jsonBytes, export: _hostileExport()),
        throwsA(isA<StateError>()),
      );
      expect(workspace.disposed, isTrue);
    });

    test('success removes them', () async {
      final workspace = _SpyWorkspace();
      await _builder(_Fetcher(), workspace).build(jsonBytes: jsonBytes, export: _hostileExport());
      expect(workspace.disposed, isTrue);
    });

    test('on disk the temporary folder is gone after success, error and cancel', () async {
      final base = await Directory.systemTemp.createTemp('quokka-test-');
      addTearDown(() => base.delete(recursive: true));
      Future<DiskExportWorkspace> create() => DiskExportWorkspace.create(base);

      // success
      var workspace = await create();
      final root = workspace.root;
      await _builder(_Fetcher(), workspace).build(jsonBytes: jsonBytes, export: _hostileExport());
      expect(await root.exists(), isFalse);

      // cancelled in the middle of the downloads
      workspace = await create();
      final token = ExportCancelToken();
      await expectLater(
        _builder(_Fetcher(onDownload: (_) => token.cancel()), workspace)
            .build(jsonBytes: jsonBytes, export: _hostileExport(), cancel: token),
        throwsA(isA<ExportCancelled>()),
      );
      expect(await workspace.root.exists(), isFalse);

      // error
      workspace = await create();
      await expectLater(
        _builder(_Fetcher(onDownload: (_) => throw StateError('x')), workspace)
            .build(jsonBytes: jsonBytes, export: _hostileExport()),
        throwsA(isA<StateError>()),
      );
      expect(await workspace.root.exists(), isFalse);
      expect(base.listSync(), isEmpty, reason: 'nothing is left in the temporary folder');
    });

    test('the disk workspace refuses a path that climbs out of its folder', () async {
      final base = await Directory.systemTemp.createTemp('quokka-test-');
      addTearDown(() => base.delete(recursive: true));
      final workspace = await DiskExportWorkspace.create(base);
      for (final bad in ['../x', 'a/../../x', '/etc/x', 'a//b']) {
        await expectLater(workspace.write(bad, Uint8List(1)), throwsArgumentError, reason: bad);
      }
      await workspace.dispose();
    });
  });

  group('the plan, the names and the estimate', () {
    test('names are safe and numbered, folders by kind', () {
      final plan = planExport({
        'files': [
          {'path': 'u/../../etc/passwd', 'kind': 'pet_media', 'url': 'https://f.test/1'},
          {'path': 'u1/c1/Referto del gatto (1).pdf', 'kind': 'chat_attachment', 'url': 'https://f.test/2'},
          {'path': 'u1/avatar.jpg', 'kind': 'profile_photo', 'url': 'https://f.test/3'},
          {'path': '', 'kind': 'pet_media', 'url': 'https://f.test/4'},
        ],
      });
      expect(plan.files.map((f) => f.zipPath), [
        'foto/001-passwd',
        'allegati/002-Referto_del_gatto_1_.pdf',
        'foto/003-avatar.jpg',
        'foto/004-file',
      ]);
      expect(plan.files.every((f) => !f.zipPath.contains('..') && !f.zipPath.startsWith('/')), isTrue);
    });

    test('sanitizeExportFileName keeps short, plain names', () {
      expect(sanitizeExportFileName(r'a\b\c.png'), 'c.png');
      expect(sanitizeExportFileName('..hidden'), 'hidden');
      expect(sanitizeExportFileName('<script>.jpg'), 'script_.jpg');
      expect(sanitizeExportFileName('${'x' * 200}.jpeg').length, lessThanOrEqualTo(60));
      expect(sanitizeExportFileName('${'x' * 200}.jpeg').endsWith('.jpeg'), isTrue);
    });

    test('the estimate adds the sizes and counts the unknown ones', () async {
      final plan = planExport(_hostileExport());
      final estimate = await estimateExport(plan, _Fetcher(failing: {'https://files.test/lost.jpg'}));
      expect(estimate.fileCount, 3);
      expect(estimate.knownBytes, 2000);
      expect(estimate.unknownCount, 1);
    });
  });

  group('the downloads only follow https links to the app storage', () {
    HttpExportFileFetcher fetcher({String supabaseUrl = '', required List<Uri> seen}) => HttpExportFileFetcher(
          client: MockClient((request) async {
            seen.add(request.url);
            return http.Response('x', 200, headers: {'content-length': '1'});
          }),
          configLoader: _Config(supabaseUrl),
        );

    test('http, other hosts and garbage are refused without a request', () async {
      final seen = <Uri>[];
      final f = fetcher(supabaseUrl: 'https://project.supabase.co', seen: seen);

      expect(await f.download('http://project.supabase.co/a'), isNull);
      expect(await f.download('https://evil.example/a'), isNull);
      expect(await f.download('javascript:alert(1)'), isNull);
      expect(await f.download('/relative'), isNull);
      expect(await f.sizeOf('https://evil.example/a'), isNull);
      expect(seen, isEmpty);

      expect(await f.download('https://project.supabase.co/storage/v1/object/sign/x?token=t'), isNotNull);
      expect(seen, hasLength(1));
    });

    test('a failing request is a null, not an exception', () async {
      final f = HttpExportFileFetcher(
        client: MockClient((_) async => throw http.ClientException('offline')),
        configLoader: const _Config(''),
      );
      expect(await f.download('https://files.test/a'), isNull);
      expect(await f.sizeOf('https://files.test/a'), isNull);
    });
  });
}

class _Config extends AppRuntimeConfigLoader {
  const _Config(this._supabaseUrl);

  final String _supabaseUrl;

  @override
  AppRuntimeConfig load() => AppRuntimeConfig(
        environment: AppEnvironment.development,
        appName: 'test',
        apiBaseUrl: 'https://api.test',
        supabaseUrl: _supabaseUrl,
        supabaseAnonKey: '',
        logLevel: 'INFO',
        enableTelemetry: false,
      );
}
