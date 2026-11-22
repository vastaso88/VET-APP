// QK-12 at the HTTP level: the requests the app makes for the light chat list and for one
// chat, how it reads the answers, and what it does with an older server.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/chat/data/chat_remote_data_source.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

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

HttpChatRemoteDataSource _source(MockClient client) =>
    HttpChatRemoteDataSource(client: client, configLoader: const _Config());

void main() {
  test('the list asks for a page and reads the light rows and the cursor',
      () async {
    final requests = <http.Request>[];
    final source = _source(MockClient((request) async {
      requests.add(request);
      return http.Response(
        '{"conversations":[{"id":"c1","pet_id":"p1","title":"Zampa",'
        '"last_activity_at":"2026-11-01T09:30:00Z","last_message_role":"assistant",'
        '"last_message_preview":"Da quando?","message_count":4}],"next_cursor":"abc"}',
        200,
      );
    }));

    final result =
        await source.fetchConversationSummaries(limit: 20, cursor: 'xyz');

    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/conversations/summaries');
    expect(
        requests.single.url.queryParameters, {'limit': '20', 'cursor': 'xyz'});
    final page = (result as Success<RemoteConversationPage>).value;
    expect(page.nextCursor, 'abc');
    final row = page.items.single;
    expect(row.id, 'c1');
    expect(row.petId, 'p1');
    expect(row.lastMessagePreview, 'Da quando?');
    expect(row.lastMessageRole, 'assistant');
    expect(row.messageCount, 4);
    expect(row.lastActivityAt, DateTime.utc(2026, 11, 1, 9, 30));
    expect(row.messages, isNull); // no message body came
  });

  test('the first request has no cursor', () async {
    late http.Request seen;
    final source = _source(MockClient((request) async {
      seen = request;
      return http.Response('{"conversations":[],"next_cursor":null}', 200);
    }));

    final result = await source.fetchConversationSummaries();

    expect(seen.url.queryParameters, {'limit': '50'});
    expect(
        (result as Success<RemoteConversationPage>).value.nextCursor, isNull);
  });

  test(
      'an older server (404 or 405) is reported as "unsupported", other errors are not',
      () async {
    for (final status in [404, 405]) {
      final result =
          await _source(MockClient((_) async => http.Response('', status)))
              .fetchConversationSummaries();
      expect((result as Failure<RemoteConversationPage>).error.code,
          conversationSummariesUnsupportedCode);
    }

    final failed =
        await _source(MockClient((_) async => http.Response('', 500)))
            .fetchConversationSummaries();
    expect((failed as Failure<RemoteConversationPage>).error.code,
        'conversation_list_http_500');
  });

  test('one chat is read from GET /conversations/{id} with its messages',
      () async {
    late http.Request seen;
    final source = _source(MockClient((request) async {
      seen = request;
      return http.Response(
        '{"conversation":{"id":"c1","pet_id":"p1","title":"Zampa","messages":['
        '{"id":"m1","role":"user","content":"Ciao","client_message_id":"user-abc",'
        '"created_at":"2026-11-01T09:00:00Z"},'
        '{"id":"m2","role":"assistant","content":"Da quando?","health_answer":true,'
        '"created_at":"2026-11-01T09:01:00Z"}]}}',
        200,
      );
    }));

    final result = await source.fetchConversation('c1');

    expect(seen.url.path, '/conversations/c1');
    final conversation = (result as Success<RemoteConversation>).value;
    expect(conversation.messages.map((m) => m.content), ['Ciao', 'Da quando?']);
    expect(conversation.messages.last.healthAnswer, isTrue);
    // The app's own id of the owner's message comes back, to recognise it after a send.
    expect(conversation.messages.first.clientMessageId, 'user-abc');
    expect(conversation.messages.last.clientMessageId, isNull);
  });

  test("someone else's or a missing chat is a failure, not an empty chat",
      () async {
    final result = await _source(MockClient(
      (_) async => http.Response('{"detail":"conversation not found"}', 400),
    )).fetchConversation('c-other');

    expect((result as Failure<RemoteConversation>).error.code,
        'conversation_get_http_400');
  });

  test('the old full history is still read from GET /conversations', () async {
    late http.Request seen;
    final source = _source(MockClient((request) async {
      seen = request;
      return http.Response(
        '{"conversations":[{"id":"c1","pet_id":"p1","title":"Zampa","messages":['
        '{"id":"m1","role":"user","content":"Ciao","created_at":"2026-11-01T09:00:00Z"}]}]}',
        200,
      );
    }));

    final result = await source.fetchConversations();

    expect(seen.url.path, '/conversations');
    final all = (result as Success<List<RemoteConversation>>).value;
    expect(all.single.messages.single.content, 'Ciao');
  });
}
