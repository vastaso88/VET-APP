// QK-12: the Home reads the chat list without message bodies; the messages of a chat are
// fetched once, when the owner opens it. An older server (no light list) still works.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/chat/data/chat_attachment_remote_data_source.dart';
import 'package:vet_app_mobile/features/chat/data/chat_demo_store.dart';
import 'package:vet_app_mobile/features/chat/data/chat_remote_data_source.dart';
import 'package:vet_app_mobile/features/chat/domain/chat_models.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

class _Config extends AppRuntimeConfigLoader {
  const _Config();

  @override
  AppRuntimeConfig load() => AppRuntimeConfig(
        environment: AppEnvironment.development,
        appName: 'test',
        apiBaseUrl: 'http://api',
        supabaseUrl: '',
        supabaseAnonKey: '',
        logLevel: 'INFO',
        enableTelemetry: false,
      );
}

RemoteChatMessage _message(String id, String role, String text, int minute) =>
    RemoteChatMessage(
      id: id,
      role: role,
      content: text,
      createdAt: DateTime.utc(2026, 11, 1, 9, minute),
    );

class _Remote implements ChatRemoteDataSource {
  _Remote({this.supportsLightList = true, this.pageSize = 50});

  final bool supportsLightList;
  final int pageSize;
  int summaryRequests = 0;
  int fullHistoryRequests = 0;
  int detailRequests = 0;
  int bytesOfMessageBodiesRead = 0;
  bool failDetail = false;
  Completer<void>? holdDetail;
  final deleted = <String>[];

  final histories = <String, List<RemoteChatMessage>>{
    'c3': [
      _message('m5', 'user', 'Starnutisce', 30),
      _message('m6', 'assistant', 'Da quando?', 31)
    ],
    'c2': [
      _message('m3', 'user', 'Mangia poco', 20),
      _message('m4', 'user', 'Ieri sera', 21)
    ],
    'c1': [_message('m1', 'user', 'Ciao', 10)],
  };

  List<RemoteConversationSummary> get _rows => [
        for (final entry in histories.entries)
          RemoteConversationSummary(
            id: entry.key,
            petId: 'p1',
            title: 'Chat ${entry.key}',
            lastActivityAt: entry.value.last.createdAt,
            lastMessageRole: entry.value.last.role,
            lastMessagePreview: entry.value.last.content,
            messageCount: entry.value.length,
          ),
      ];

  @override
  Future<Result<RemoteConversationPage>> fetchConversationSummaries({
    int limit = 50,
    String? cursor,
  }) async {
    summaryRequests++;
    if (!supportsLightList) {
      return Result.failure(
        const AppNetworkError(
            code: conversationSummariesUnsupportedCode, message: 'old'),
      );
    }
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, _rows.length);
    return Result.success(
      RemoteConversationPage(
        items: _rows.sublist(start, end),
        nextCursor: end < _rows.length ? '$end' : null,
      ),
    );
  }

  @override
  Future<Result<List<RemoteConversation>>> fetchConversations() async {
    fullHistoryRequests++;
    for (final messages in histories.values) {
      bytesOfMessageBodiesRead +=
          messages.fold(0, (sum, m) => sum + m.content.length);
    }
    return Result.success([
      for (final entry in histories.entries)
        RemoteConversation(
          id: entry.key,
          petId: 'p1',
          title: 'Chat ${entry.key}',
          messages: entry.value,
        ),
    ]);
  }

  @override
  Future<Result<RemoteConversation>> fetchConversation(
      String conversationId) async {
    detailRequests++;
    await holdDetail?.future;
    if (failDetail) {
      return Result.failure(
          const AppNetworkError(code: 'boom', message: 'boom'));
    }
    final messages = histories[conversationId]!;
    bytesOfMessageBodiesRead +=
        messages.fold(0, (sum, m) => sum + m.content.length);
    return Result.success(
      RemoteConversation(
        id: conversationId,
        petId: 'p1',
        title: 'Chat $conversationId',
        messages: messages,
      ),
    );
  }

  @override
  Future<Result<void>> deleteConversation(String conversationId) async {
    deleted.add(conversationId);
    return Result.success<void>(null);
  }

  @override
  Future<Result<String>> renameConversation(
          String conversationId, String title) async =>
      Result.success(title);

  // QK-12b: a send that the server stores when it is released (holdSend) and answers when
  // holdReply is released: the order in which the history fetch and the send land is
  // then up to the test.
  Completer<void>? holdSend;
  Completer<void>? holdReply;
  int editCalls = 0;

  @override
  Future<Result<ChatSendResult>> sendMessage({
    required String petId,
    String? conversationId,
    required String userMessage,
    String? attachmentId,
    String? clientMessageId,
  }) async {
    await holdSend?.future;
    final history = histories[conversationId]!;
    history.add(
      RemoteChatMessage(
        id: 'srv-u${history.length}',
        role: 'user',
        content: userMessage,
        createdAt: DateTime.utc(2026, 11, 1, 10),
        clientMessageId: clientMessageId,
      ),
    );
    history
        .add(_message('srv-a${history.length}', 'assistant', 'Risposta', 41));
    final answerId = history.last.id;
    await holdReply?.future;
    return Result.success(
      ChatSendResult(
        content: 'Risposta',
        aiGenerated: true,
        backendConversationId: conversationId!,
        messageId: answerId,
      ),
    );
  }

  @override
  Future<Result<ChatSendResult>> editMessage({
    required String conversationId,
    required String messageId,
    required String userMessage,
    String? clientMessageId,
  }) async {
    editCalls++;
    return Result.failure(
        const AppNetworkError(code: 'edit_called', message: 'edit'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoAttachments implements ChatAttachmentRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatDemoStore _store(_Remote remote, {String? Function()? owner}) =>
    ChatDemoStore.forTesting(
      remoteDataSource: remote,
      attachmentRemoteDataSource: _NoAttachments(),
      configLoader: const _Config(),
      ownerIdProvider: owner ?? () => 'u1',
      petNamesProvider: () async => {'p1': 'Rex'},
    );

void main() {
  test('the Home reads rows and previews and downloads no message bodies',
      () async {
    final remote = _Remote();
    final store = _store(remote);

    await store.ensureHydrated();

    expect(remote.summaryRequests, 1);
    expect(remote.fullHistoryRequests, 0);
    expect(remote.detailRequests, 0);
    expect(remote.bytesOfMessageBodiesRead, 0);
    expect(store.conversations.map((c) => c.id), ['c3', 'c2', 'c1']);
    final first = store.conversations.first;
    expect(first.previewMessage, 'Da quando?');
    expect(first.activePetName, 'Rex');
    final thread = store.conversationById('c3')!;
    expect(thread.messages, isEmpty);
    expect(thread.messagesLoaded, isFalse);
    // The per-pet limit still counts every chat, loaded or not.
    expect(store.countForPet('Rex'), 3);
  });

  test('every page of the list is followed, one request each', () async {
    final remote = _Remote(pageSize: 2);
    final store = _store(remote);

    await store.ensureHydrated();

    expect(remote.summaryRequests, 2);
    expect(store.conversations.map((c) => c.id), ['c3', 'c2', 'c1']);
  });

  test('opening a chat fetches its messages once, however often it is asked',
      () async {
    final remote = _Remote();
    final store = _store(remote);
    await store.ensureHydrated();

    store.openConversation('c2');
    store.openConversation('c2');
    await store.ensureMessagesLoaded('c2');
    await store.ensureMessagesLoaded('c2');

    expect(remote.detailRequests, 1);
    final thread = store.conversationById('c2')!;
    expect(thread.messagesLoaded, isTrue);
    expect(thread.messages.map((m) => m.text), ['Mangia poco', 'Ieri sera']);
    expect(store.isLoadingMessages('c2'), isFalse);
    // The other chats were never fetched.
    expect(store.conversationById('c3')!.messagesLoaded, isFalse);
  });

  test('a failed fetch is flagged and a retry loads the chat', () async {
    final remote = _Remote()..failDetail = true;
    final store = _store(remote);
    await store.ensureHydrated();

    await store.ensureMessagesLoaded('c1');
    expect(store.messagesLoadFailed('c1'), isTrue);
    expect(store.conversationById('c1')!.messagesLoaded, isFalse);

    remote.failDetail = false;
    await store.ensureMessagesLoaded('c1');
    expect(store.messagesLoadFailed('c1'), isFalse);
    expect(store.conversationById('c1')!.messages.map((m) => m.text), ['Ciao']);
  });

  test(
      'an older server without the light list still gets the whole history, loaded',
      () async {
    final remote = _Remote(supportsLightList: false);
    final store = _store(remote);

    await store.ensureHydrated();

    expect(remote.summaryRequests, 1);
    expect(remote.fullHistoryRequests, 1);
    expect(store.conversationById('c3')!.messagesLoaded, isTrue);
    expect(store.conversationById('c3')!.messages, hasLength(2));
    store.openConversation('c3');
    await store.ensureMessagesLoaded('c3');
    expect(remote.detailRequests, 0); // nothing more to fetch
  });

  test('a sign-out while a chat is loading drops the late answer', () async {
    final remote = _Remote()..holdDetail = Completer<void>();
    var owner = 'u1';
    final store = _store(remote, owner: () => owner);
    await store.ensureHydrated();

    final loading = store.ensureMessagesLoaded('c2');
    expect(store.isLoadingMessages('c2'), isTrue);
    store.reset(); // sign-out
    owner = 'u2';
    remote.holdDetail!.complete();
    await loading;

    expect(store.conversationById('c2'), isNull);
    expect(store.conversations, isEmpty);
    expect(store.isLoadingMessages('c2'), isFalse);
  });

  test(
      'deleting a chat that was never opened works and a later fetch is dropped',
      () async {
    final remote = _Remote()..holdDetail = Completer<void>();
    final store = _store(remote);
    await store.ensureHydrated();

    final loading = store.ensureMessagesLoaded('c1');
    final result = await store.deleteConversation('c1');
    remote.holdDetail!.complete();
    await loading;

    expect(result.isSuccess, isTrue);
    expect(remote.deleted, ['c1']);
    expect(store.conversationById('c1'), isNull);
  });

  test('a rename keeps the preview and the position of an unopened chat',
      () async {
    final remote = _Remote();
    final store = _store(remote);
    await store.ensureHydrated();

    final renamed = await store.renameConversation('c2', 'Esami di settembre');

    expect(renamed.isSuccess, isTrue);
    expect(store.conversationById('c2')!.title, 'Esami di settembre');
    expect(store.conversations.map((c) => c.id), ['c3', 'c2', 'c1']);
    expect(store.conversations[1].previewMessage, 'Ieri sera');
  });

  group('QK-12b: a message sent while the history is loading', () {
    List<String> texts(ChatDemoStore store) =>
        store.conversationById('c2')!.messages.map((m) => m.text).toList();

    const full = ['Mangia poco', 'Ieri sera', 'Nuova', 'Risposta'];

    test('the history lands first, the server had not stored the message yet',
        () async {
      final remote = _Remote()
        ..holdDetail = Completer<void>()
        ..holdSend = Completer<void>();
      final store = _store(remote);
      await store.ensureHydrated();
      final loading = store.ensureMessagesLoaded('c2');
      final sending = store.sendMessage('c2', 'Nuova');
      await pumpEventQueue();

      remote.holdDetail!.complete();
      await loading;
      expect(texts(store), ['Mangia poco', 'Ieri sera', 'Nuova']); // kept, once
      remote.holdSend!.complete();
      await sending;

      expect(texts(store), full);
      expect(store.conversationById('c2')!.messagesLoaded, isTrue);
    });

    test('the answer lands first, then a history that already holds both',
        () async {
      final remote = _Remote()..holdDetail = Completer<void>();
      final store = _store(remote);
      await store.ensureHydrated();
      final loading = store.ensureMessagesLoaded('c2');

      await store.sendMessage(
          'c2', 'Nuova'); // stored by the server and answered
      expect(texts(store), ['Nuova', 'Risposta']);
      remote.holdDetail!.complete();
      await loading;

      expect(texts(store),
          full); // neither duplicated nor lost, the server's order
    });

    test('the history, already holding both, lands before the answer arrives',
        () async {
      final remote = _Remote()
        ..holdDetail = Completer<void>()
        ..holdReply = Completer<void>();
      final store = _store(remote);
      await store.ensureHydrated();
      final loading = store.ensureMessagesLoaded('c2');
      final sending = store.sendMessage('c2', 'Nuova');
      await pumpEventQueue(); // the server stored the message, the reply is held

      remote.holdDetail!.complete();
      await loading;
      expect(texts(store), full);
      remote.holdReply!.complete();
      await sending;

      expect(texts(store), full); // the late answer is not added a second time
    });

    test('the same words sent twice are two messages, not one', () async {
      final remote = _Remote();
      remote.histories['c2']!.add(_message('m9', 'user', 'Nuova', 25));
      final store = _store(remote);
      await store.ensureHydrated();

      await store.sendMessage('c2', 'Nuova');
      await store.ensureMessagesLoaded('c2');

      expect(texts(store),
          ['Mangia poco', 'Ieri sera', 'Nuova', 'Nuova', 'Risposta']);
    });
  });

  group('QK-12b: whoever needs the whole history gets it or an error', () {
    test('the export fetches the messages first and then has all of them',
        () async {
      final remote = _Remote();
      final store = _store(remote);
      await store.ensureHydrated();
      expect(store.conversationById('c2')!.messages, isEmpty);

      final ready = await store.ensureMessagesAvailable('c2');

      expect(ready, isTrue);
      expect(store.conversationById('c2')!.messages.map((m) => m.text),
          ['Mangia poco', 'Ieri sera']);
      expect(await store.ensureMessagesAvailable('c2'), isTrue);
      expect(remote.detailRequests, 1); // the second call had nothing to fetch
    });

    test('when the fetch fails nothing is exported: the answer is "not ready"',
        () async {
      final remote = _Remote()..failDetail = true;
      final store = _store(remote);
      await store.ensureHydrated();

      final ready = await store.ensureMessagesAvailable('c2');

      expect(ready, isFalse);
      expect(store.conversationById('c2')!.messages, isEmpty);
      expect(store.messagesLoadFailed('c2'), isTrue);
      expect(await store.ensureMessagesAvailable('nobody'), isFalse);
    });

    test(
        'an edit waits for the history; without it the edit is refused, not cut wrongly',
        () async {
      final remote = _Remote()..failDetail = true;
      final store = _store(remote);
      await store.ensureHydrated();

      final refused = await store.editMessage('c2', 'm4', 'Ieri notte');

      expect((refused as Failure<ChatConversationDetail>).error.code,
          'chat_messages_not_loaded');
      expect(remote.editCalls, 0);

      remote.failDetail = false;
      final reached = await store.editMessage('c2', 'm4', 'Ieri notte');

      expect((reached as Failure<ChatConversationDetail>).error.code,
          'edit_called');
      expect(remote.editCalls, 1);
      expect(store.conversationById('c2')!.messages.map((m) => m.text),
          ['Mangia poco', 'Ieri notte']); // cut at the right message
    });
  });
}
