import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/pet_news/data/pet_news_repository.dart';
import 'package:vet_app_mobile/features/pet_news/domain/pet_news_edition.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

/// K06 (collaudo giro 1): «Curiosità non disponibili» alla prima apertura della
/// Home. A server that has not read its feeds yet answers 200 with no headlines;
/// that answer must neither be shown as the section's result nor be kept for the
/// next 20 minutes.

class _Config extends AppRuntimeConfigLoader {
  const _Config();

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

const _empty = '{"categories":{},"available_categories":["Cane"],"stale":false}';
const _good =
    '{"categories":{"Cane":[{"title":"Prima","source":"Fonte","url":"https://example.com/n",'
    '"published_at":"2026-11-20T10:00:00+00:00"}]},"stale":false}';

BackendPetNewsRepository _repository(http.Client client) => BackendPetNewsRepository(
      client: client,
      configLoader: const _Config(),
      editionProvider: () => petNewsEditionFor('it', 'IT'),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BackendPetNewsRepository.resetCache();
  });

  test('an empty first answer is asked again and the news show up, with no error in between',
      () async {
    var requests = 0;
    final repository = _repository(MockClient((_) async {
      requests++;
      return http.Response(requests < 3 ? _empty : _good, 200);
    }));

    final items = await repository.fetchForSpecies('Cane');

    expect(items.single.title, 'Prima');
    expect(requests, 3);
  });

  test('a server that never has headlines: nothing to show, and nothing kept as an answer',
      () async {
    var requests = 0;
    final repository = _repository(MockClient((_) async {
      requests++;
      return http.Response(_empty, 200);
    }));

    expect(await repository.fetchForSpecies('Cane'), isEmpty);
    final afterFirst = requests;
    expect(afterFirst, greaterThan(1));

    // The empty answer was not stored as the 20-minute shared one: the next ask
    // (Riprova, or the next opening) goes to the server again.
    expect(await repository.fetchForSpecies('Cane'), isEmpty);
    expect(requests, greaterThan(afterFirst));
  });

  test('the first good answer after empty ones is kept for the next asks', () async {
    var requests = 0;
    final repository = _repository(MockClient((_) async {
      requests++;
      return http.Response(requests == 1 ? _empty : _good, 200);
    }));

    await repository.fetchForSpecies('Cane');
    final afterFirst = requests;
    final second = await repository.fetchForSpecies('Cane');

    expect(second.single.title, 'Prima');
    expect(requests, afterFirst, reason: 'served from the shared answer');
  });
}
