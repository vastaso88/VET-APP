import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/chat/data/chat_remote_data_source.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';
import 'package:vet_app_mobile/shared/date/utc_offset_header.dart';

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

void main() {
  group('the header', () {
    test('is the offset in whole minutes, with its sign', () {
      expect(utcOffsetHeader(const Duration(hours: 1)), {'X-UTC-Offset-Minutes': '60'});
      expect(utcOffsetHeader(const Duration(hours: 2)), {'X-UTC-Offset-Minutes': '120'});
      expect(utcOffsetHeader(Duration.zero), {'X-UTC-Offset-Minutes': '0'});
      expect(utcOffsetHeader(const Duration(hours: -5)), {'X-UTC-Offset-Minutes': '-300'});
      expect(utcOffsetHeader(const Duration(hours: 5, minutes: 30)), {'X-UTC-Offset-Minutes': '330'});
      expect(utcOffsetHeader(const Duration(hours: 5, minutes: 45)), {'X-UTC-Offset-Minutes': '345'});
      expect(utcOffsetHeader(const Duration(hours: 14)), {'X-UTC-Offset-Minutes': '840'});
      expect(utcOffsetHeader(const Duration(hours: -12)), {'X-UTC-Offset-Minutes': '-720'});
    });

    test('by default is the offset of this phone right now', () {
      final sent = int.parse(utcOffsetHeader()[utcOffsetHeaderName]!);

      expect(sent, DateTime.now().timeZoneOffset.inMinutes);
    });
  });

  test('POST /chat and the message edit tell the backend the phone offset', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        '{"reply":{"content":"ok"},"conversation":{"id":"c1","title":"t"}}',
        200,
      );
    });
    final source = HttpChatRemoteDataSource(client: client, configLoader: const _FakeConfigLoader());

    await source.sendMessage(petId: 'p1', userMessage: 'ciao');
    await source.editMessage(conversationId: 'c1', messageId: 'm1', userMessage: 'ciao ancora');

    final expected = DateTime.now().timeZoneOffset.inMinutes.toString();
    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request.headers[utcOffsetHeaderName], expected);
    }
  });
}
