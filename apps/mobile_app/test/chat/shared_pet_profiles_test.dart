import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/chat/data/chat_attachment_remote_data_source.dart';
import 'package:vet_app_mobile/features/chat/data/chat_demo_store.dart';
import 'package:vet_app_mobile/features/chat/data/chat_remote_data_source.dart';
import 'package:vet_app_mobile/features/chat/domain/chat_models.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

/// QK-02: Home and the chat read the pet profiles once. The pet store is the
/// real one (with its read replaced by a counter); the chat store is wired to
/// it exactly as in the app.

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

class _Remote implements ChatRemoteDataSource {
  int petNameReads = 0;
  int conversationReads = 0;
  List<RemoteConversation> conversations = const [];
  final sentToPets = <String>[];

  @override
  Future<Result<List<RemoteConversation>>> fetchConversations() async {
    conversationReads++;
    return Result.success(conversations);
  }

  @override
  Future<Result<RemoteConversationPage>> fetchConversationSummaries({
    int limit = 50,
    String? cursor,
  }) async =>
      Result.failure(
        const AppNetworkError(code: conversationSummariesUnsupportedCode, message: 'old'),
      );

  @override
  Future<Result<RemoteConversation>> fetchConversation(String conversationId) async =>
      Result.failure(const AppNetworkError(code: 'x', message: 'unused'));

  @override
  Future<Result<Map<String, String>>> fetchPetNamesById() async {
    petNameReads++;
    return Result.success(const {});
  }

  @override
  Future<Result<ChatSendResult>> sendMessage({
    required String petId,
    String? conversationId,
    required String userMessage,
    String? attachmentId,
    String? clientMessageId,
  }) async {
    sentToPets.add(petId);
    return Result.success(
      ChatSendResult(
        content: 'ok',
        aiGenerated: true,
        backendConversationId: conversationId ?? 'new',
      ),
    );
  }

  @override
  Future<Result<String>> ensureDefaultPetId({
    required String fallbackName,
    required String fallbackSpecies,
  }) async =>
      Result.failure(const AppNetworkError(code: 'unused', message: 'unused'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoAttachments implements ChatAttachmentRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _pet(String id, String name) => {
      'id': id,
      'name': name,
      'species': 'Cane',
      'owner_id': 'whoever',
    };

RemoteConversation _conversation(String id, String petId) =>
    RemoteConversation(id: id, petId: petId, title: 'Chat $id', messages: const []);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pets = PetDemoStore.instance;
  late _Remote remote;
  late ChatDemoStore chat;
  late String? owner;
  late int profileReads;
  late Future<List<dynamic>> Function(String ownerId) answer;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    pets.reset();
    owner = 'owner-a';
    profileReads = 0;
    answer = (_) async => [_pet('pet-1', 'Luna')];
    pets.debugOwnerId = () => owner;
    pets.debugFetchRows = (ownerId) {
      profileReads++;
      return answer(ownerId);
    };
    remote = _Remote();
    chat = ChatDemoStore.forTesting(
      remoteDataSource: remote,
      attachmentRemoteDataSource: _NoAttachments(),
      configLoader: const _Config(),
      ownerIdProvider: () => owner,
      petNamesProvider: pets.loadSyncedPetNames,
    );
  });

  tearDown(() {
    pets.debugOwnerId = null;
    pets.debugFetchRows = null;
    pets.reset();
  });

  Future<List<dynamic>> slow(List<dynamic> rows) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return rows;
  }

  group('one read of the profiles at start', () {
    test('preload order: pets, then chat, then Home', () async {
      answer = (_) => slow([_pet('pet-1', 'Luna')]);
      remote.conversations = [_conversation('c1', 'pet-1')];

      await Future.wait([pets.ensureHydrated(), chat.ensureHydrated()]);
      await pets.ensureHydrated(); // Home opening later

      expect(profileReads, 1);
      expect(remote.petNameReads, 0);
      expect(chat.conversations.map((c) => c.id), ['c1']);
      expect(chat.conversationById('c1')!.petName, 'Luna');
    });

    test('preload order: chat first, then pets, then the pet list page', () async {
      answer = (_) => slow([_pet('pet-1', 'Luna')]);
      remote.conversations = [_conversation('c1', 'pet-1')];

      await Future.wait([chat.ensureHydrated(), pets.ensureHydrated()]);
      await pets.ensureHydrated();
      await chat.ensureHydrated();

      expect(profileReads, 1);
      expect(remote.petNameReads, 0);
      expect(remote.conversationReads, 1);
    });
  });

  group('empty list versus failed read', () {
    test('a real empty list is an empty map, not "unknown"', () async {
      answer = (_) async => <dynamic>[];

      expect(pets.syncedPetNamesById(), isNull); // before any read
      await pets.ensureHydrated();

      expect(pets.syncedPetNamesById(), isEmpty);
      expect(pets.syncedPetNamesById(), isNotNull);
      expect(pets.lastHydrationFailed, isFalse);
    });

    test('offline: unknown, the chat waits and recovers on the next call', () async {
      answer = (_) async => throw TimeoutException('offline');
      remote.conversations = [_conversation('c1', 'pet-1')];

      await chat.ensureHydrated();
      expect(pets.syncedPetNamesById(), isNull);
      expect(pets.lastHydrationFailed, isTrue);
      expect(chat.conversations, isEmpty);

      answer = (_) async => [_pet('pet-1', 'Luna')];
      await chat.ensureHydrated();

      expect(pets.lastHydrationFailed, isFalse);
      expect(chat.conversations.map((c) => c.id), ['c1']);
    });

    test('pets saved on the phone are shown but are not "synced"', () async {
      SharedPreferences.setMockInitialValues({
        'vet_app.cache.pets.owner-a': '[{"id":"pet-9","name":"Moka","species":"Cane"}]',
      });
      answer = (_) async => throw TimeoutException('offline');

      await pets.restoreFromCache();
      await pets.ensureHydrated();

      expect(pets.list().map((p) => p.name), ['Moka']);
      expect(pets.syncedPetNamesById(), isNull);
    });
  });

  test('two pets with the same name each keep their own chats', () async {
    answer = (_) async => [_pet('pet-a', 'Luna'), _pet('pet-b', 'Luna')];
    remote.conversations = [_conversation('c-a', 'pet-a'), _conversation('c-b', 'pet-b')];
    await Future.wait([pets.ensureHydrated(), chat.ensureHydrated()]);

    await chat.sendMessage('c-a', 'ciao');
    await chat.sendMessage('c-b', 'ciao');
    await chat.sendMessage('c-a', 'ancora');

    expect(remote.sentToPets, ['pet-a', 'pet-b', 'pet-a']);
    expect(profileReads, 1);
  });

  group('sign-out and second account', () {
    test('a read that lands after sign-out brings nothing back', () async {
      final late = Completer<List<dynamic>>();
      answer = (_) => late.future;

      final loading = pets.ensureHydrated();
      pets.reset(); // sign-out while the read is in flight
      owner = null;
      late.complete([_pet('pet-1', 'Luna')]);
      await loading;

      expect(pets.list(), isEmpty);
      expect(pets.syncedPetNamesById(), isNull);
      expect(pets.lastHydrationFailed, isFalse);
    });

    test('the second account gets its own pets, once, whatever the old read does', () async {
      final firstRead = Completer<List<dynamic>>();
      answer = (ownerId) =>
          ownerId == 'owner-a' ? firstRead.future : slow([_pet('pet-b1', 'Rex')]);

      final firstLoading = pets.ensureHydrated(); // account A starts reading
      pets.reset();
      owner = 'owner-b'; // A signs out, B signs in
      final secondLoading = pets.ensureHydrated();

      firstRead.complete([_pet('pet-a1', 'Luna')]); // A's answer arrives late
      await Future.wait([firstLoading, secondLoading]);

      expect(pets.list().map((p) => p.name), ['Rex']);
      expect(pets.syncedPetNamesById(), {'pet-b1': 'Rex'});
      expect(profileReads, 2); // one per account
    });

    test('a signed-out chat read leaves the next account\'s chats empty', () async {
      final late = Completer<List<dynamic>>();
      answer = (_) => late.future;
      remote.conversations = [_conversation('c1', 'pet-1')];

      final loading = chat.ensureHydrated();
      chat.reset();
      owner = null;
      late.complete([_pet('pet-1', 'Luna')]);
      await loading;

      expect(chat.conversations, isEmpty);
    });

    test('the previous account\'s chats go as soon as another account asks, even offline', () async {
      remote.conversations = [_conversation('c1', 'pet-1')];
      await Future.wait([pets.ensureHydrated(), chat.ensureHydrated()]);
      expect(chat.conversations, hasLength(1));

      owner = 'owner-b'; // another account, no sign-out handler ran
      answer = (_) async => throw TimeoutException('offline');
      await chat.ensureHydrated();

      expect(chat.conversations, isEmpty);
    });
  });

  group('chats are tied to the pet by id, not by name (QK-02b)', () {
    ChatConversationDetail legacyChat(String petName) => ChatConversationDetail(
          id: 'old-$petName',
          title: 'Vecchia chat',
          petName: petName,
          statusLabel: 'Salvata',
          messages: const [],
        );

    test('two pets with the same name and no history: the first message goes to the one chosen',
        () async {
      answer = (_) async => [_pet('pet-a', 'Luna'), _pet('pet-b', 'Luna')];
      await Future.wait([pets.ensureHydrated(), chat.ensureHydrated()]);

      final forB = chat.startConversation(petId: 'pet-b', petName: 'Luna');
      await chat.sendMessage(forB.id, 'ciao');
      final forA = chat.startConversation(petId: 'pet-a', petName: 'Luna');
      await chat.sendMessage(forA.id, 'ciao');

      expect(remote.sentToPets, ['pet-b', 'pet-a']);
      expect(profileReads, 1);
    });

    test('the per-pet chat limit is counted apart for pets with the same name', () async {
      answer = (_) async => [_pet('pet-a', 'Luna'), _pet('pet-b', 'Luna')];
      await Future.wait([pets.ensureHydrated(), chat.ensureHydrated()]);

      for (var i = 0; i < ChatDemoStore.maxConversationsPerPet; i++) {
        chat.startConversation(petId: 'pet-b', petName: 'Luna');
      }

      expect(chat.countForPet('pet-b'), ChatDemoStore.maxConversationsPerPet);
      expect(chat.canStartConversation('pet-b'), isFalse);
      expect(chat.countForPet('pet-a'), 0);
      expect(chat.canStartConversation('pet-a'), isTrue);
      expect(
        chat.conversations.every((c) => c.petId == 'pet-b'),
        isTrue,
        reason: 'the list says which pet each chat is about',
      );
    });

    test('an old chat without a pet id is not guessed when the name is shared', () async {
      answer = (_) async => [_pet('pet-a', 'Luna'), _pet('pet-b', 'Luna')];
      await Future.wait([pets.ensureHydrated(), chat.ensureHydrated()]);
      final old = chat.openConversation('old-Luna', fallback: legacyChat('Luna'));

      final result = await chat.sendMessage(old.id, 'ciao');

      expect(result.isFailure, isTrue);
      expect(remote.sentToPets, isEmpty); // nothing went to either pet
      expect(chat.countForPet('pet-a'), 0);
      expect(chat.countForPet('pet-b'), 0);
    });

    test('an old chat without a pet id uses the name when it belongs to one pet only', () async {
      answer = (_) async => [_pet('pet-1', 'Rex'), _pet('pet-2', 'Luna')];
      await Future.wait([pets.ensureHydrated(), chat.ensureHydrated()]);
      final old = chat.openConversation('old-Rex', fallback: legacyChat('Rex'));
      expect(chat.countForPet('pet-1'), 1);

      await chat.sendMessage(old.id, 'ciao');

      expect(remote.sentToPets, ['pet-1']);
      expect(chat.conversationById(old.id)!.petId, 'pet-1'); // it has an id from now on
    });

    test('a second account never counts or sends with the pets of the first account', () async {
      answer = (_) async => [_pet('pet-a', 'Luna')];
      remote.conversations = [_conversation('c-a', 'pet-a')];
      await Future.wait([pets.ensureHydrated(), chat.ensureHydrated()]);
      expect(chat.countForPet('pet-a'), 1);

      owner = 'owner-b';
      pets.reset();
      answer = (_) async => [_pet('pet-z', 'Luna')];
      remote.conversations = const [];
      await Future.wait([pets.ensureHydrated(), chat.ensureHydrated()]);

      expect(chat.countForPet('pet-a'), 0);
      expect(chat.conversations, isEmpty);
      final fresh = chat.startConversation(petId: 'pet-z', petName: 'Luna');
      await chat.sendMessage(fresh.id, 'ciao');
      expect(remote.sentToPets, ['pet-z']);
      expect(chat.countForPet('pet-z'), 1);
    });
  });
}
