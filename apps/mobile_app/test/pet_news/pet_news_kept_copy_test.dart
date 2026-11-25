import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/pet_news/data/pet_news_disk_cache.dart';
import 'package:vet_app_mobile/features/pet_news/data/pet_news_repository.dart';
import 'package:vet_app_mobile/features/pet_news/domain/pet_news_edition.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

class _FakeConfigLoader extends AppRuntimeConfigLoader {
  const _FakeConfigLoader();

  @override
  AppRuntimeConfig load() => const AppRuntimeConfig(
        environment: AppEnvironment.development,
        appName: 'test',
        apiBaseUrl: 'http://api.test',
        supabaseUrl: '',
        supabaseAnonKey: '',
        logLevel: 'INFO',
        enableTelemetry: false,
      );
}

String _body(String title) =>
    '{"categories":{"Cane":[{"title":"$title","source":"Fonte","url":"https://example.com/n",'
    '"published_at":"2026-11-20T10:00:00+00:00"}],"Generale":[]},"stale":false}';

BackendPetNewsRepository _repository(http.Client client) => BackendPetNewsRepository(
      client: client,
      configLoader: const _FakeConfigLoader(),
      editionProvider: () => petNewsEditionFor('it', 'IT'),
    );

Future<void> _keepCopy(String title) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString('vet_app.pet_news.last_body', _body(title));
  await preferences.setInt('vet_app.pet_news.last_at', DateTime.now().millisecondsSinceEpoch);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BackendPetNewsRepository.resetCache();
  });

  test('a good answer is kept on the phone', () async {
    final repository = _repository(MockClient((_) async => http.Response(_body('Prima'), 200)));

    final items = await repository.fetchForSpecies('Cane');
    await pumpEventQueue();

    expect(items.single.title, 'Prima');
    final kept = await const PetNewsDiskCache().load();
    expect(kept, isNotNull);
    expect(kept!.body, contains('Prima'));
  });

  test('a failed request shows the kept copy, and the next ask goes to the server again', () async {
    await _keepCopy('Copia salvata');
    var requests = 0;
    final repository = _repository(MockClient((_) async {
      requests++;
      return http.Response('boom', 500);
    }));

    final first = await repository.fetchForSpecies('Cane');
    final afterFirst = requests;
    final second = await repository.fetchForSpecies('Cane');

    expect(first.single.title, 'Copia salvata');
    expect(second.single.title, 'Copia salvata');
    expect(requests, greaterThan(afterFirst), reason: 'the stale copy is not taken for fresh');
  });

  test('no kept copy and no answer: nothing to show, as before', () async {
    final repository = _repository(MockClient((_) async => http.Response('boom', 500)));

    expect(await repository.fetchForSpecies('Cane'), isEmpty);
  });

  test('a copy older than two weeks is not shown', () async {
    await _keepCopy('Vecchia');
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      'vet_app.pet_news.last_at',
      DateTime.now().subtract(const Duration(days: 15)).millisecondsSinceEpoch,
    );
    final repository = _repository(MockClient((_) async => http.Response('boom', 500)));

    expect(await repository.fetchForSpecies('Cane'), isEmpty);
  });

  test('a copy of another country is not shown', () async {
    SharedPreferences.setMockInitialValues({
      'vet_app.pet_news.last_body': _body('Le chien').replaceFirst('{', '{"country":"FR",'),
      'vet_app.pet_news.last_at': DateTime.now().millisecondsSinceEpoch,
    });
    final repository = _repository(MockClient((_) async => http.Response('boom', 500)));

    expect(await repository.fetchForSpecies('Cane'), isEmpty);
  });

  test('signing out forgets the kept copy', () async {
    await _keepCopy('Da dimenticare');

    await const PetNewsDiskCache().clear();

    expect(await const PetNewsDiskCache().load(), isNull);
  });

  testWidgets('a slow server: the kept copy shows after a few seconds, the late answer refreshes',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'vet_app.pet_news.last_body': _body('Copia salvata'),
      'vet_app.pet_news.last_at': DateTime.now().millisecondsSinceEpoch,
    });
    final late = Completer<http.Response>();
    final repository = _repository(MockClient((_) => late.future));

    List<String>? shown;
    unawaited(repository
        .fetchForSpecies('Cane')
        .then((items) => shown = [for (final item in items) item.title]));

    await tester.pump(const Duration(seconds: 3));
    expect(shown, isNull, reason: 'it waits a little for the network first');
    await tester.pump(const Duration(seconds: 4));
    expect(shown, ['Copia salvata']);

    late.complete(http.Response(_body('Fresca'), 200));
    await tester.pump();
    List<String>? next;
    unawaited(repository
        .fetchForSpecies('Cane')
        .then((items) => next = [for (final item in items) item.title]));
    await tester.pump();
    expect(next, ['Fresca'], reason: 'the late answer fills the shared answer');
    await tester.pump(const Duration(seconds: 60));
  });
}
