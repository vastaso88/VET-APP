import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/chat/data/chat_remote_data_source.dart';
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

const _speciesUnknown =
    '{"detail":"Specie non riconosciuta.","code":"species_unknown","field":"species"}';

void main() {
  test('a species the server does not know is tried once more as "Altro"', () async {
    final posted = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('{"pet_profiles":[]}', 200);
      final species = (jsonDecode(request.body) as Map<String, dynamic>)['species'] as String;
      posted.add(species);
      if (species == 'Drago') return http.Response(_speciesUnknown, 422);
      return http.Response('{"pet_profile":{"id":"p-new"}}', 200);
    });
    final source =
        HttpChatRemoteDataSource(client: client, configLoader: const _FakeConfigLoader());

    final result = await source.ensureDefaultPetId(fallbackName: 'Smaug', fallbackSpecies: 'Drago');

    expect(posted, ['Drago', 'Altro']);
    expect(result.isSuccess, isTrue);
  });

  test('an ordinary species is sent once, with no second try', () async {
    final posted = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('{"pet_profiles":[]}', 200);
      posted.add((jsonDecode(request.body) as Map<String, dynamic>)['species'] as String);
      return http.Response('{"pet_profile":{"id":"p-new"}}', 200);
    });
    final source =
        HttpChatRemoteDataSource(client: client, configLoader: const _FakeConfigLoader());

    await source.ensureDefaultPetId(fallbackName: 'Milo', fallbackSpecies: 'Cane');

    expect(posted, ['Cane']);
  });

  test('another 422 (or "Altro" itself refused) is not retried', () async {
    var posts = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('{"pet_profiles":[]}', 200);
      posts++;
      return http.Response('{"detail":"x","code":"name_required","field":"name"}', 422);
    });
    final source =
        HttpChatRemoteDataSource(client: client, configLoader: const _FakeConfigLoader());

    final result = await source.ensureDefaultPetId(fallbackName: ' ', fallbackSpecies: 'Cane');

    expect(posts, 1);
    expect(result.isSuccess, isFalse);
  });
}
