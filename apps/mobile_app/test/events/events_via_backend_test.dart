import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/events/data/events_repository.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

class _ConfigWithBackend extends AppRuntimeConfigLoader {
  const _ConfigWithBackend();

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

EventsRepository _repository(MockClient client, {String? token = 'jwt'}) => EventsRepository(
      httpClient: client,
      configLoader: const _ConfigWithBackend(),
      tokenProvider: () => token,
    );

Map<String, dynamic> _row(String id, {String country = 'IT'}) => {
      'id': id,
      'title': 'Giornata dell adozione',
      'event_type': 'adoption_day',
      'level': 'local',
      'country': country,
      'starts_on': '2026-11-20',
      'ends_on': '2026-11-20',
      'status': 'published',
    };

final _from = DateTime(2026, 11, 1);
final _to = DateTime(2026, 11, 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the events are asked of the backend with the country and the window', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response(
        jsonEncode({
          'events': [_row('ev-1')]
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final result = await _repository(client).loadEvents(from: _from, to: _to, country: 'IT');

    expect(seen.url.path, '/events');
    expect(seen.url.queryParameters, {'country': 'IT', 'from': '2026-11-01', 'to': '2026-11-30'});
    expect(seen.headers['Authorization'], 'Bearer jwt');
    expect(result.events.map((e) => e.id), ['ev-1']);
    expect(result.needsPlan, isFalse);
    expect(result.failed, isFalse);
  });

  test('an event of another country is never shown, even if the backend sent it', () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({
            'events': [_row('ev-it'), _row('ev-fr', country: 'FR')]
          }),
          200,
        ));

    final result = await _repository(client).loadEvents(from: _from, to: _to, country: 'IT');

    expect(result.events.map((e) => e.id), ['ev-it']);
  });

  test('a 402 means the owner needs a plan: not a failure, nothing to retry', () async {
    final client =
        MockClient((request) async => http.Response('{"code":"subscription_required"}', 402));

    final result = await _repository(client).loadEvents(from: _from, to: _to, country: 'IT');

    expect(result.needsPlan, isTrue);
    expect(result.failed, isFalse);
    expect(result.events, isEmpty);
  });

  test('a backend that does not answer usefully falls back to the direct read (none here)',
      () async {
    final client = MockClient((request) async => http.Response('boom', 500));

    final result = await _repository(client).loadEvents(from: _from, to: _to, country: 'IT');

    expect(result.needsPlan, isFalse);
    expect(result.events, isEmpty);
  });

  test('without a session the backend is not asked', () async {
    var asked = false;
    final client = MockClient((request) async {
      asked = true;
      return http.Response('{}', 200);
    });

    await _repository(client, token: null).loadEvents(from: _from, to: _to, country: 'IT');

    expect(asked, isFalse);
  });
}
