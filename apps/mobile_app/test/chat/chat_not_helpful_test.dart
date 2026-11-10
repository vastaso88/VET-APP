import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/chat/data/chat_attachment_remote_data_source.dart';
import 'package:vet_app_mobile/features/chat/data/chat_demo_store.dart';
import 'package:vet_app_mobile/features/chat/data/chat_remote_data_source.dart';
import 'package:vet_app_mobile/features/chat/domain/chat_models.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

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

ChatMessage _answer({
  bool health = true,
  String? serverId = 'srv-1',
  bool notHelpful = false,
  ChatMessageAuthor author = ChatMessageAuthor.assistant,
}) =>
    ChatMessage(
      id: 'm1',
      author: author,
      text: 'Una risposta',
      timeLabel: '10:00',
      aiGenerated: true,
      serverId: serverId,
      healthAnswer: health,
      notHelpful: notHelpful,
    );

Future<void> _pump(
  WidgetTester tester,
  ChatMessage message, {
  Future<bool> Function()? onNotHelpful,
  Locale locale = const Locale('it'),
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChatMessageBubble(message: message, onNotHelpful: onNotHelpful),
        ),
      ),
    ),
  );
}

Finder get _button => find.byKey(const ValueKey('chat-not-helpful-m1'));
Finder get _note => find.byKey(const ValueKey('chat-not-helpful-note-m1'));

class _RecordingRemote implements ChatRemoteDataSource {
  _RecordingRemote({this.failing = false});

  bool failing;
  final List<(String, String)> reports = [];

  @override
  Future<Result<void>> markNotHelpful({
    required String conversationId,
    required String messageId,
  }) async {
    reports.add((conversationId, messageId));
    return failing
        ? Result.failure(const AppNetworkError(code: 'chat_not_helpful_http_500', message: 'x'))
        : Result.success(null);
  }

  @override
  Future<Result<List<RemoteConversation>>> fetchConversations() async => Result.success([
        RemoteConversation(
          id: 'c1',
          petId: 'p1',
          title: 'Rex - zoppia',
          messages: [
            RemoteChatMessage(id: 'srv-u', role: 'user', content: 'Zoppica', createdAt: DateTime.utc(2026, 11, 10)),
            RemoteChatMessage(
              id: 'srv-1',
              role: 'assistant',
              content: 'Può essere una distorsione',
              createdAt: DateTime.utc(2026, 11, 10, 0, 1),
              healthAnswer: true,
            ),
            RemoteChatMessage(
              id: 'srv-2',
              role: 'assistant',
              content: 'Già segnalata',
              createdAt: DateTime.utc(2026, 11, 10, 0, 2),
              healthAnswer: true,
              notHelpful: true,
            ),
            RemoteChatMessage(
              id: 'srv-3',
              role: 'assistant',
              content: 'Gestione',
              createdAt: DateTime.utc(2026, 11, 10, 0, 3),
            ),
          ],
        ),
      ]);

  @override
  Future<Result<Map<String, String>>> fetchPetNamesById() async => Result.success({'p1': 'Rex'});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoAttachments implements ChatAttachmentRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatDemoStore _store(_RecordingRemote remote) => ChatDemoStore.forTesting(
      remoteDataSource: remote,
      attachmentRemoteDataSource: _NoAttachments(),
      configLoader: const _Config(),
      ownerIdProvider: () => 'u1',
    );

void main() {
  group('the button under a health answer', () {
    testWidgets('appears only under an assistant answer the backend marked as health',
        (tester) async {
      await _pump(tester, _answer(), onNotHelpful: () async => true);
      expect(_button, findsOneWidget);
      expect(find.text('Non mi ha aiutato'), findsOneWidget);

      await _pump(tester, _answer(health: false), onNotHelpful: () async => true);
      expect(_button, findsNothing);

      await _pump(tester, _answer(serverId: null), onNotHelpful: () async => true);
      expect(_button, findsNothing);

      await _pump(tester, _answer(author: ChatMessageAuthor.user), onNotHelpful: () async => true);
      expect(_button, findsNothing);

      await _pump(tester, _answer());
      expect(_button, findsNothing, reason: 'no handler, no button');
    });

    testWidgets('a tap sends the signal once and gives way to the note', (tester) async {
      var calls = 0;
      await _pump(tester, _answer(), onNotHelpful: () async {
        calls++;
        return true;
      });

      await tester.tap(_button);
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(_button, findsNothing);
      expect(find.text('Ci riprovo con più attenzione: dimmi cosa non ti è stato utile.'), findsOneWidget);
    });

    testWidgets('while the signal travels the button is disabled: no double tap', (tester) async {
      final gate = Completer<bool>();
      var calls = 0;
      await _pump(tester, _answer(), onNotHelpful: () {
        calls++;
        return gate.future;
      });

      await tester.tap(_button);
      await tester.pump();
      expect(tester.widget<TextButton>(_button).onPressed, isNull);
      await tester.tap(_button, warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);

      gate.complete(true);
      await tester.pumpAndSettle();
      expect(_note, findsOneWidget);
    });

    testWidgets('if it cannot be sent the button stays, with a short error, and can be tried again',
        (tester) async {
      var ok = false;
      var calls = 0;
      await _pump(tester, _answer(), onNotHelpful: () async {
        calls++;
        return ok;
      });

      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(find.text('Non sono riuscito a inviare la segnalazione. Riprova.'), findsOneWidget);
      expect(_button, findsOneWidget);
      expect(_note, findsNothing);

      ok = true;
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(_note, findsOneWidget);
      expect(find.text('Non sono riuscito a inviare la segnalazione. Riprova.'), findsNothing);
    });

    testWidgets('an answer already reported shows the note after a restart, no button', (tester) async {
      await _pump(tester, _answer(notHelpful: true), onNotHelpful: () async => true);

      expect(_note, findsOneWidget);
      expect(_button, findsNothing);
    });

    testWidgets('it is accessible: a labelled button with a 48 px target, a spoken note', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _answer(), onNotHelpful: () async => true);

      expect(tester.getSize(_button).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(_button).width, greaterThanOrEqualTo(48));
      final data = tester.getSemantics(_button);
      expect(data.label, 'Non mi ha aiutato');
      expect(data.hint, 'Segnala che questa risposta non ti è stata utile');
      expect(data.flagsCollection.isButton, isTrue);

      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(_note).flagsCollection.isLiveRegion, isTrue);
      semantics.dispose();
    });

    testWidgets('it reads in the five languages', (tester) async {
      const labels = {
        'en': "That didn't help",
        'es': 'No me ha ayudado',
        'de': 'Das hat mir nicht geholfen',
        'fr': "Cela ne m'a pas aidé",
      };
      for (final entry in labels.entries) {
        await _pump(tester, _answer(), onNotHelpful: () async => true, locale: Locale(entry.key));
        expect(find.text(entry.value), findsOneWidget, reason: entry.key);
      }
    });
  });

  group('the signal to the backend', () {
    HttpChatRemoteDataSource source(MockClient client) =>
        HttpChatRemoteDataSource(client: client, configLoader: const _Config());

    test('POST /conversations/{id}/messages/{id}/not-helpful, no body', () async {
      late http.Request seen;
      final result = await source(MockClient((request) async {
        seen = request;
        return http.Response('{"recorded":true}', 200);
      })).markNotHelpful(conversationId: 'c 1', messageId: 'srv/1');

      expect(result.isSuccess, isTrue);
      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'https://api.test/conversations/c%201/messages/srv%2F1/not-helpful');
      expect(seen.body, isEmpty);
    });

    test('404, 429, 500, a timeout and a network error are failures', () async {
      for (final status in [404, 429, 500]) {
        final result = await source(MockClient((_) async => http.Response('{}', status)))
            .markNotHelpful(conversationId: 'c', messageId: 'm');
        expect(result.isFailure, isTrue, reason: '$status');
      }
      final offline = await source(MockClient((_) async => throw http.ClientException('offline')))
          .markNotHelpful(conversationId: 'c', messageId: 'm');
      expect(offline.isFailure, isTrue);
    });

    test('POST /chat and the edit read health_answer and the reply id', () async {
      final answer = '{"reply":{"id":"srv-9","content":"ok"},"conversation":{"id":"c1","title":"t"},'
          '"ai_generated":true,"health_answer":true}';
      final result = await source(MockClient((_) async => http.Response(answer, 200)))
          .sendMessage(petId: 'p1', userMessage: 'ciao');

      final reply = result.fold<ChatSendResult?>(onSuccess: (v) => v, onFailure: (_) => null)!;
      expect(reply.messageId, 'srv-9');
      expect(reply.healthAnswer, isTrue);

      final plain = await source(MockClient((_) async => http.Response(
              '{"reply":{"content":"ok"},"conversation":{"id":"c1"}}', 200)))
          .sendMessage(petId: 'p1', userMessage: 'ciao');
      final plainReply = plain.fold<ChatSendResult?>(onSuccess: (v) => v, onFailure: (_) => null)!;
      expect(plainReply.healthAnswer, isFalse, reason: 'a backend without the field: no button');
      expect(plainReply.messageId, isNull);
    });

    test('stored conversations carry health_answer and not_helpful per message', () async {
      final body = jsonEncode({
        'conversations': [
          {
            'id': 'c1',
            'pet_id': 'p1',
            'title': 't',
            'messages': [
              {'id': 'a', 'role': 'assistant', 'content': 'x', 'health_answer': true},
              {'id': 'b', 'role': 'assistant', 'content': 'y', 'health_answer': true, 'not_helpful': true},
              {'id': 'c', 'role': 'assistant', 'content': 'z'},
            ],
          },
        ],
      });
      final result = await source(MockClient((_) async => http.Response(body, 200))).fetchConversations();

      final messages = result.fold<List<RemoteConversation>>(onSuccess: (v) => v, onFailure: (_) => [])
          .single
          .messages;
      expect(messages.map((m) => (m.healthAnswer, m.notHelpful)), [(true, false), (true, true), (false, false)]);
    });
  });

  group('the store', () {
    test('restored conversations keep the server id, the health flag and the reported state', () async {
      final store = _store(_RecordingRemote());
      await store.ensureHydrated();

      final messages = store.conversationById('c1')!.messages;
      expect(messages[1].canReportNotHelpful, isTrue);
      expect(messages[1].serverId, 'srv-1');
      expect(messages[2].notHelpful, isTrue);
      expect(messages[3].canReportNotHelpful, isFalse, reason: 'not a health answer');
      expect(messages[0].canReportNotHelpful, isFalse, reason: 'the owner\'s own message');
    });

    test('reporting sends the server ids, marks the message and adds nothing to the thread', () async {
      final remote = _RecordingRemote();
      final store = _store(remote);
      await store.ensureHydrated();
      final before = store.conversationById('c1')!.messages;

      final ok = await store.reportNotHelpful('c1', before[1]);

      expect(ok, isTrue);
      expect(remote.reports, [('c1', 'srv-1')]);
      final after = store.conversationById('c1')!.messages;
      expect(after.length, before.length, reason: 'it is not a question');
      expect(after[1].notHelpful, isTrue);
      expect(after[1].text, before[1].text);
      expect(after[3].notHelpful, isFalse);
    });

    test('a failure leaves the message as it was', () async {
      final remote = _RecordingRemote(failing: true);
      final store = _store(remote);
      await store.ensureHydrated();

      final ok = await store.reportNotHelpful('c1', store.conversationById('c1')!.messages[1]);

      expect(ok, isFalse);
      expect(store.conversationById('c1')!.messages[1].notHelpful, isFalse);
    });

    test('a message the server does not know is never reported', () async {
      final remote = _RecordingRemote();
      final store = _store(remote);
      await store.ensureHydrated();

      final ok = await store.reportNotHelpful('c1', _answer(serverId: null));

      expect(ok, isFalse);
      expect(remote.reports, isEmpty);
    });
  });
}
