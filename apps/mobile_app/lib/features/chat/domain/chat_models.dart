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
  });

  final String id;
  final String title;
  final String subtitle;
  final String updatedAtLabel;
  final int unreadCount;
  final String activePetName;
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
}

class ChatConversationDetail {
  const ChatConversationDetail({
    required this.id,
    required this.title,
    required this.petName,
    required this.statusLabel,
    required this.messages,
    this.backendConversationId,
  });

  final String id;
  final String title;
  final String petName;
  final String statusLabel;
  final List<ChatMessage> messages;

  /// Id of the matching conversation on the real backend, once the first
  /// message of this (locally-created) thread has actually been sent there.
  /// Null means this thread has never talked to the backend yet.
  final String? backendConversationId;

  ChatConversationDetail copyWith({
    String? id,
    String? title,
    String? petName,
    String? statusLabel,
    List<ChatMessage>? messages,
    String? backendConversationId,
  }) {
    return ChatConversationDetail(
      id: id ?? this.id,
      title: title ?? this.title,
      petName: petName ?? this.petName,
      statusLabel: statusLabel ?? this.statusLabel,
      messages: messages ?? this.messages,
      backendConversationId: backendConversationId ?? this.backendConversationId,
    );
  }
}
