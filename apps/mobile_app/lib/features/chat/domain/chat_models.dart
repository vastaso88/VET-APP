import 'dart:typed_data';

enum ChatScreenState {
  loading,
  empty,
  error,
  success,
}

enum ChatMessageAuthor {
  user,
  assistant,
}

class ChatConversationSummary {
  const ChatConversationSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.updatedAtLabel,
    required this.unreadCount,
    required this.activePetName,
    required this.previewMessage,
    required this.lastSender,
    this.petId,
  });

  final String id;
  final String title;
  final String subtitle;
  final String updatedAtLabel;
  final int unreadCount;
  final String activePetName;

  /// The pet this chat belongs to (its profile id); null for a chat whose pet
  /// cannot be told apart by name. Use it, not [activePetName], to tell which
  /// pet a chat is about: two pets can share a name.
  final String? petId;
  final String previewMessage;
  final String lastSender;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.timeLabel,
    this.isRead = true,
    this.aiGenerated = false,
    this.attachmentImageBytes,
    this.serverId,
    this.healthAnswer = false,
    this.notHelpful = false,
  });

  final String id;
  final ChatMessageAuthor author;
  final String text;
  final String timeLabel;
  final bool isRead;

  /// Whether this message's content was produced by the AI assistant, as
  /// opposed to a rule-based/templated reply (e.g. safety triage). Drives
  /// the AI Act transparency disclosure badge in the message bubble.
  final bool aiGenerated;

  /// The photo the user attached to this message, kept client-side for
  /// display in the thread (the backend gets it via a separate upload, not
  /// re-sent here).
  final Uint8List? attachmentImageBytes;

  /// The message's id on the server (`reply.id` of `POST /chat`, or the stored
  /// id of a restored conversation); null for messages that never reached it.
  final String? serverId;

  /// The backend marked this answer as being about the animal's health
  /// (`health_answer`): only those get the "Non mi ha aiutato" button.
  final bool healthAnswer;

  /// The owner said this answer did not help (kept by the server too).
  final bool notHelpful;

  /// Whether the "Non mi ha aiutato" button is offered under this message.
  bool get canReportNotHelpful =>
      author == ChatMessageAuthor.assistant && healthAnswer && serverId != null && serverId!.isNotEmpty;

  ChatMessage copyWith({bool? notHelpful}) => ChatMessage(
        id: id,
        author: author,
        text: text,
        timeLabel: timeLabel,
        isRead: isRead,
        aiGenerated: aiGenerated,
        attachmentImageBytes: attachmentImageBytes,
        serverId: serverId,
        healthAnswer: healthAnswer,
        notHelpful: notHelpful ?? this.notHelpful,
      );
}

class ChatConversationDetail {
  const ChatConversationDetail({
    required this.id,
    required this.title,
    required this.petName,
    required this.statusLabel,
    required this.messages,
    this.backendConversationId,
    this.messagesLoaded = true,
    this.previewText = '',
    this.previewFromAssistant = true,
    this.lastActivityAt,
    this.petId,
  });

  final String id;
  final String title;

  /// The pet's name, for display only: it does not identify the pet (see [petId]).
  final String petName;

  /// The pet this chat is about (its profile id, the same as `pet_profiles.id` on
  /// the server). Set when the chat is started from a pet's page and when it is
  /// restored from the server; null only for the demo conversations and for chats
  /// created without a pet, which are matched by name when the name is unique.
  final String? petId;
  final String statusLabel;
  final List<ChatMessage> messages;

  /// Id of the matching conversation on the real backend, once the first
  /// message of this (locally-created) thread has actually been sent there.
  /// Null means this thread has never talked to the backend yet.
  final String? backendConversationId;

  /// False for a chat known only from the light list: [messages] is empty until the
  /// owner opens it (QK-12), and the list row shows [previewText] instead.
  final bool messagesLoaded;

  /// The start of the last message, for the list row while [messages] is not loaded.
  final String previewText;
  final bool previewFromAssistant;
  final DateTime? lastActivityAt;

  ChatConversationDetail copyWith({
    String? id,
    String? title,
    String? petName,
    String? statusLabel,
    List<ChatMessage>? messages,
    String? backendConversationId,
    bool? messagesLoaded,
    String? petId,
  }) {
    return ChatConversationDetail(
      id: id ?? this.id,
      title: title ?? this.title,
      petName: petName ?? this.petName,
      petId: petId ?? this.petId,
      statusLabel: statusLabel ?? this.statusLabel,
      messages: messages ?? this.messages,
      backendConversationId: backendConversationId ?? this.backendConversationId,
      messagesLoaded: messagesLoaded ?? this.messagesLoaded,
      previewText: previewText,
      previewFromAssistant: previewFromAssistant,
      lastActivityAt: lastActivityAt,
    );
  }
}
