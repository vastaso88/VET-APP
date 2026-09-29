import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/chat/data/chat_attachment_remote_data_source.dart';
import 'package:vet_app_mobile/features/chat/data/chat_demo_store.dart';
import 'package:vet_app_mobile/features/chat/data/chat_remote_data_source.dart';
import 'package:vet_app_mobile/features/chat/domain/chat_models.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

class _FakeConfigLoader extends AppRuntimeConfigLoader {
  const _FakeConfigLoader(this.apiBaseUrl);

  final String apiBaseUrl;

  @override
  AppRuntimeConfig load() => AppRuntimeConfig(
        environment: AppEnvironment.development,
        appName: 'test',
        apiBaseUrl: apiBaseUrl,
        supabaseUrl: '',
        supabaseAnonKey: '',
        logLevel: 'INFO',
        enableTelemetry: false,
      );
}

class _FakeRemote implements ChatRemoteDataSource {
  _FakeRemote({this.failing = false});

  bool failing;
  int conversationFetches = 0;

  @override
  Future<Result<List<RemoteConversation>>> fetchConversations() async {
    conversationFetches++;
    if (failing) {
      return Result.failure(const AppNetworkError(code: 'x', message: 'boom'));
    }
    return Result.success([
      RemoteConversation(
        id: 'c-old',
        petId: 'p1',
        title: 'Rex - vecchia',
        messages: [
          RemoteChatMessage(
            id: 'm1',
            role: 'user',
            content: 'Ciao',
            createdAt: DateTime.utc(2020, 1, 1),
          ),
        ],
      ),
      RemoteConversation(
        id: 'c-new',
        petId: 'p1',
        title: 'Rex - recente',
        messages: [
          RemoteChatMessage(
            id: 'm2',
            role: 'user',
            content: 'Mangia poco',
            createdAt: DateTime.utc(2021, 1, 1),
          ),
          RemoteChatMessage(
            id: 'm3',
            role: 'assistant',
            content: 'Da quando?',
            createdAt: DateTime.utc(2021, 1, 1, 0, 1),
          ),
        ],
      ),
      const RemoteConversation(id: 'c-orphan', petId: 'gone', title: 'x', messages: []),
    ]);
  }

  @override
  Future<Result<Map<String, String>>> fetchPetNamesById() async =>
      Result.success({'p1': 'Rex'});

  @override
  Future<Result<void>> deleteConversation(String conversationId) async =>
      Result.success<void>(null);

  @override
  Future<Result<String>> ensureDefaultPetId({
    required String fallbackName,
    required String fallbackSpecies,
  }) async =>
      Result.success('p1');

  @override
  Future<Result<ChatSendResult>> sendMessage({
    required String petId,
    String? conversationId,
    required String userMessage,
    String? attachmentId,
  }) async =>
      Result.failure(const AppNetworkError(code: 'x', message: 'unused'));
}

class _NoAttachments implements ChatAttachmentRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatDemoStore _store(_FakeRemote remote, {String apiBaseUrl = 'http://api', String? owner = 'u1'}) =>
    ChatDemoStore.forTesting(
      remoteDataSource: remote,
      attachmentRemoteDataSource: _NoAttachments(),
      configLoader: _FakeConfigLoader(apiBaseUrl),
      ownerIdProvider: () => owner,
    );

void main() {
  test('restores stored conversations with messages, newest first', () async {
    final remote = _FakeRemote();
    final store = _store(remote);
    expect(store.conversations, isEmpty);

    await store.ensureHydrated();

    final ids = store.conversations.map((c) => c.id).toList();
    expect(ids, ['c-new', 'c-old']);
    final detail = store.conversationById('c-new')!;
    expect(detail.petName, 'Rex');
    expect(detail.backendConversationId, 'c-new');
    expect(detail.messages.map((m) => m.text), ['Mangia poco', 'Da quando?']);
    expect(detail.messages.last.author, ChatMessageAuthor.assistant);
    expect(store.conversations.first.unreadCount, 0);
  });

  test('hydrates once per owner and retries after a failure', () async {
    final remote = _FakeRemote(failing: true);
    final store = _store(remote);

    await store.ensureHydrated();
    expect(store.conversations, isEmpty);

    remote.failing = false;
    await store.ensureHydrated();
    expect(store.conversations, hasLength(2));

    await store.ensureHydrated();
    expect(remote.conversationFetches, 2);
  });

  test('keeps the demo seed and skips the backend when no API is configured', () async {
    final remote = _FakeRemote();
    final store = _store(remote, apiBaseUrl: '');

    await store.ensureHydrated();

    expect(remote.conversationFetches, 0);
    expect(store.conversations, isNotEmpty);
  });

  test('does nothing while nobody is signed in', () async {
    final remote = _FakeRemote();
    final store = _store(remote, owner: null);

    await store.ensureHydrated();

    expect(remote.conversationFetches, 0);
    expect(store.conversations, isEmpty);
  });
}
