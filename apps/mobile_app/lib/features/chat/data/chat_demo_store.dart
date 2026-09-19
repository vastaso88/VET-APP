import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/types/result.dart';
import '../domain/chat_models.dart';
import 'chat_remote_data_source.dart';
import 'chat_seed_data.dart';

class ChatDemoStore extends ChangeNotifier {
  ChatDemoStore._({
    ChatRemoteDataSource? remoteDataSource,
    AppRuntimeConfigLoader? configLoader,
  })  : _remote = remoteDataSource ?? HttpChatRemoteDataSource(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader() {
    reset();
  }

  static final ChatDemoStore instance = ChatDemoStore._();

  /// Max concurrent chat threads per pet. Keeps the per-pet chat list short
  /// and scannable on a phone screen instead of growing without bound.
  static const maxConversationsPerPet = 4;

  final ChatRemoteDataSource _remote;
  final AppRuntimeConfigLoader _configLoader;
  String? _defaultPetId;

  final List<ChatConversationDetail> _threads = <ChatConversationDetail>[];
  final Set<String> _openedConversationIds = <String>{};

  UnmodifiableListView<ChatConversationSummary> get conversations {
    final summaries = _threads.map(_summaryFor).toList(growable: false);
    return UnmodifiableListView<ChatConversationSummary>(summaries);
  }

  int countForPet(String petName) =>
      _threads.where((thread) => thread.petName == petName).length;

  bool canStartConversation(String petName) =>
      countForPet(petName) < maxConversationsPerPet;

  /// Removes the conversation locally right away — required by
  /// [Dismissible], which expects the backing list to shrink synchronously
  /// once `onDismissed` fires — then, if it was ever actually sent to the
  /// backend, deletes it there too so the backend's own max-conversations
  /// count (packages/core/application/services/send_chat_message.py) stays
  /// in sync and a freed slot is really free. A backend failure here can't
  /// undo the now-animated-away local removal, so it's surfaced to the
  /// caller only as an informational Result, not by restoring the item.
  Future<Result<void>> deleteConversation(String id) async {
    final thread = conversationById(id);
    _threads.removeWhere((thread) => thread.id == id);
    _openedConversationIds.remove(id);
    notifyListeners();

    final backendConversationId = thread?.backendConversationId;
    if (backendConversationId == null) {
      return Result.success<void>(null);
    }
    return _remote.deleteConversation(backendConversationId);
  }

  ChatConversationDetail? conversationById(String id) {
    for (final thread in _threads) {
      if (thread.id == id) {
        return thread;
      }
    }
    return null;
  }

  ChatConversationDetail openConversation(String id) {
    _openedConversationIds.add(id);
    final conversation = conversationById(id);
    if (conversation != null) {
      notifyListeners();
      return conversation;
    }

    final created = _createConversation(
      petName: 'Moka',
      title: 'Moka - nuova conversazione',
      seedPrompt: 'Ciao, ho una domanda su Moka.',
    );
    _threads.insert(0, created);
    _openedConversationIds.add(created.id);
    notifyListeners();
    return created;
  }

  ChatConversationDetail startConversation({
    String petName = 'Moka',
    String seedPrompt = 'Ciao, ho una domanda su Moka.',
  }) {
    final conversation = _createConversation(
      petName: petName,
      title: '$petName - nuova conversazione',
      seedPrompt: seedPrompt,
    );
    _threads.insert(0, conversation);
    _openedConversationIds.add(conversation.id);
    notifyListeners();
    return conversation;
  }

  Future<Result<ChatConversationDetail>> sendMessage(
    String conversationId,
    String message,
  ) async {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      return Result.success(conversationById(conversationId) ?? _threads.first);
    }

    final thread = conversationById(conversationId) ?? _threads.first;
    final userMessage = ChatMessage(
      id: _messageId('user'),
      author: ChatMessageAuthor.user,
      text: cleanMessage,
      timeLabel: _clockLabel(),
      isRead: true,
    );

    _replaceThread(
      conversationId,
      thread.copyWith(
        title: _maybeRetitle(thread.title, cleanMessage),
        statusLabel: 'Messaggio inviato',
        messages: [...thread.messages, userMessage],
      ),
    );
    _openedConversationIds.add(conversationId);
    notifyListeners();

    if (!_configLoader.load().hasApiBaseUrl) {
      return Result.success(await _sendDemoReply(conversationId, cleanMessage));
    }
    return _sendRealMessage(conversationId, cleanMessage);
  }

  Future<ChatConversationDetail> _sendDemoReply(
    String conversationId,
    String cleanMessage,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));

    final updatedThread = conversationById(conversationId) ?? _threads.first;
    final assistantMessage = ChatMessage(
      id: _messageId('assistant'),
      author: ChatMessageAuthor.assistant,
      text: _generateReply(cleanMessage, updatedThread.petName),
      timeLabel: _clockLabel(),
    );

    _replaceThread(
      conversationId,
      updatedThread.copyWith(
        statusLabel: 'Risposta pronta',
        messages: [...updatedThread.messages, assistantMessage],
      ),
    );
    _openedConversationIds.add(conversationId);
    notifyListeners();

    return conversationById(conversationId) ?? updatedThread;
  }

  Future<Result<ChatConversationDetail>> _sendRealMessage(
    String conversationId,
    String cleanMessage,
  ) async {
    final thread = conversationById(conversationId) ?? _threads.first;

    final petIdResult = await _resolveDefaultPetId(thread.petName);
    return petIdResult.fold(
      onFailure: (error) async => Result.failure(error),
      onSuccess: (petId) async {
        final sendResult = await _remote.sendMessage(
          petId: petId,
          conversationId: thread.backendConversationId,
          userMessage: cleanMessage,
        );
        return sendResult.fold(
          onFailure: (error) => Result.failure(error),
          onSuccess: (reply) {
            final updatedThread = conversationById(conversationId) ?? thread;
            final assistantMessage = ChatMessage(
              id: _messageId('assistant'),
              author: ChatMessageAuthor.assistant,
              text: reply.content,
              timeLabel: _clockLabel(),
              aiGenerated: reply.aiGenerated,
            );

            final resultThread = updatedThread.copyWith(
              statusLabel: 'Risposta pronta',
              messages: [...updatedThread.messages, assistantMessage],
              backendConversationId: reply.backendConversationId,
            );
            _replaceThread(conversationId, resultThread);
            _openedConversationIds.add(conversationId);
            notifyListeners();

            return Result.success(resultThread);
          },
        );
      },
    );
  }

  Future<Result<String>> _resolveDefaultPetId(String petName) async {
    final cachedPetId = _defaultPetId;
    if (cachedPetId != null) {
      return Result.success(cachedPetId);
    }

    final result = await _remote.ensureDefaultPetId(
      fallbackName: petName,
      fallbackSpecies: 'dog',
    );
    return result.fold(
      onFailure: (error) => Result.failure<String>(error),
      onSuccess: (petId) {
        _defaultPetId = petId;
        return Result.success(petId);
      },
    );
  }

  void reset() {
    _threads
      ..clear()
      ..addAll(
        ChatSeedData.conversations.map(ChatSeedData.detailForSummary),
      );
    _openedConversationIds.clear();
    notifyListeners();
  }

  ChatConversationSummary _summaryFor(ChatConversationDetail conversation) {
    final lastMessage = conversation.messages.isNotEmpty
        ? conversation.messages.last
        : ChatMessage(
            id: _messageId('summary'),
            author: ChatMessageAuthor.assistant,
            text: 'Nuovo thread pronto per essere usato.',
            timeLabel: 'adesso',
          );

    final unreadCount = _openedConversationIds.contains(conversation.id)
        ? 0
        : (lastMessage.author == ChatMessageAuthor.assistant ? 1 : 0);

    return ChatConversationSummary(
      id: conversation.id,
      title: conversation.title,
      subtitle: conversation.statusLabel,
      updatedAtLabel: lastMessage.timeLabel,
      unreadCount: unreadCount,
      activePetName: conversation.petName,
      previewMessage: lastMessage.text,
      lastSender: lastMessage.author == ChatMessageAuthor.assistant
          ? 'Assistente'
          : 'Tu',
    );
  }

  ChatConversationDetail _createConversation({
    required String petName,
    required String title,
    required String seedPrompt,
  }) {
    final createdAt = _clockLabel();
    return ChatConversationDetail(
      id: _conversationId(petName),
      title: title,
      petName: petName,
      statusLabel: 'Contesto attivo del pet',
      messages: [
        ChatMessage(
          id: _messageId('assistant'),
          author: ChatMessageAuthor.assistant,
          text:
              'Ti seguo su $petName. Dimmi pure cosa stai osservando e ti preparo una risposta concreta.',
          timeLabel: createdAt,
        ),
        ChatMessage(
          id: _messageId('user'),
          author: ChatMessageAuthor.user,
          text: seedPrompt,
          timeLabel: createdAt,
        ),
        ChatMessage(
          id: _messageId('assistant'),
          author: ChatMessageAuthor.assistant,
          text: _generateReply(seedPrompt, petName),
          timeLabel: createdAt,
        ),
      ],
    );
  }

  void _replaceThread(String id, ChatConversationDetail value) {
    final index = _threads.indexWhere((thread) => thread.id == id);
    if (index == -1) {
      _threads.insert(0, value);
      return;
    }

    _threads[index] = value;
  }

  String _conversationId(String petName) {
    final seed = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final normalizedPet = petName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return 'conv-$normalizedPet-$seed';
  }

  String _messageId(String prefix) {
    final seed = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return '$prefix-$seed';
  }

  String _clockLabel() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _maybeRetitle(String title, String message) {
    if (title.toLowerCase().contains('nuova conversazione')) {
      final subject = message.length > 34 ? '${message.substring(0, 34).trim()}...' : message;
      return 'Chat - $subject';
    }
    return title;
  }

  String _generateReply(String message, String petName) {
    final normalized = message.toLowerCase();

    if (normalized.contains('appetito') || normalized.contains('mang') || normalized.contains('cibo')) {
      return 'Per $petName terrei sotto osservazione appetito, acqua e livello di energia per le prossime 24 ore. Se peggiora, meglio sentire il veterinario.';
    }

    if (normalized.contains('vomit') || normalized.contains('diarrea')) {
      return 'Se ci sono vomito o diarrea, conviene monitorare idratazione e contattare il veterinario se i sintomi si ripetono o diventano intensi.';
    }

    if (normalized.contains('vaccin') || normalized.contains('richiamo')) {
      return 'Posso aiutarti a mettere il richiamo di $petName in agenda e aggiungere un reminder chiaro nella home.';
    }

    if (normalized.contains('peso') || normalized.contains('dimagr')) {
      return 'Sul peso di $petName possiamo fissare un controllo periodico e confrontarlo con l ultima visita per capire se il trend cambia davvero.';
    }

    return 'Ho preso nota: per $petName ti preparo un riepilogo breve, cosi hai subito un piano pratico e leggibile.';
  }
}
