import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/chat/data/chat_remote_data_source.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
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

const _replyBody =
    '{"reply":{"content":"ok"},"conversation":{"id":"c1","title":"t"}}';

void main() {
  tearDown(() => AppLocaleHolder.current = const Locale('it'));

  test('POST /chat and the message edit carry the app language', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(_replyBody, 200);
    });
    final source = HttpChatRemoteDataSource(
        client: client, configLoader: const _FakeConfigLoader());

    await source.sendMessage(petId: 'p1', userMessage: 'ciao');
    AppLocaleHolder.current = const Locale('en');
    await source.editMessage(
        conversationId: 'c1', messageId: 'm1', userMessage: 'hello');

    expect(jsonDecode(requests[0].body), {
      'pet_id': 'p1',
      'user_message': 'ciao',
      'language': 'it',
      'response_locale': 'it',
    });
    expect(requests[0].headers['Accept-Language'], 'it');
    expect(jsonDecode(requests[1].body),
        {'user_message': 'hello', 'language': 'en'});
    expect(requests[1].headers['Accept-Language'], 'en');
  });

  test(
      'known backend messages are mapped, unknown ones are returned as they are',
      () {
    expect(
      localizedBackendMessage('x',
          detail: 'conversation_limit_reached: ... conversazioni (4) ...'),
      appL10n.chatErrorConversationLimit('4'),
    );
    expect(localizedBackendMessage('Conversation Not Found'),
        appL10n.chatErrorConversationNotFound);
    expect(localizedBackendMessage('something unexpected'),
        'something unexpected');
  });
}
