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
}

class ChatConversationDetail {
  const ChatConversationDetail({
    required this.id,
    required this.title,
    required this.petName,
    required this.statusLabel,
    required this.messages,
  });

  final String id;
  final String title;
  final String petName;
  final String statusLabel;
  final List<ChatMessage> messages;

  ChatConversationDetail copyWith({
    String? id,
    String? title,
    String? petName,
    String? statusLabel,
    List<ChatMessage>? messages,
  }) {
    return ChatConversationDetail(
      id: id ?? this.id,
      title: title ?? this.title,
      petName: petName ?? this.petName,
      statusLabel: statusLabel ?? this.statusLabel,
      messages: messages ?? this.messages,
    );
  }
}
