import '../../../l10n/l10n.dart';
import '../domain/chat_models.dart';

/// Demo conversations shown only when no backend is configured. The texts
/// follow the app language (they are read through [appL10n] on every call).
class ChatSeedData {
  static List<ChatConversationSummary> get conversations {
    final l10n = appL10n;
    return [
      ChatConversationSummary(
        id: 'conv-1',
        title: l10n.chatSeedConv1Title,
        subtitle: l10n.chatSeedConv1Subtitle,
        updatedAtLabel: l10n.chatSeedAgo2Min,
        unreadCount: 2,
        activePetName: 'Moka',
        previewMessage: l10n.chatSeedConv1Preview,
        lastSender: l10n.chatSenderAssistant,
      ),
      ChatConversationSummary(
        id: 'conv-2',
        title: l10n.chatSeedConv2Title,
        subtitle: l10n.chatSeedConv2Subtitle,
        updatedAtLabel: l10n.chatTimeYesterday,
        unreadCount: 0,
        activePetName: 'Moka',
        previewMessage: l10n.chatSeedConv2Preview,
        lastSender: l10n.chatSenderYou,
      ),
      ChatConversationSummary(
        id: 'conv-3',
        title: l10n.chatSeedConv3Title,
        subtitle: l10n.chatSeedConv3Subtitle,
        updatedAtLabel: l10n.chatSeedAgo3Days,
        unreadCount: 1,
        activePetName: 'Moka',
        previewMessage: l10n.chatSeedConv3Preview,
        lastSender: l10n.chatSenderAssistant,
      ),
    ];
  }

  static const emptyConversations = <ChatConversationSummary>[];

  static ChatConversationDetail get detail {
    final l10n = appL10n;
    return ChatConversationDetail(
      id: 'conv-1',
      title: l10n.chatSeedConv1Title,
      petName: 'Moka',
      statusLabel: l10n.chatSeedConv1Status,
      messages: [
        ChatMessage(
          id: 'msg-1',
          author: ChatMessageAuthor.assistant,
          text: l10n.chatSeedConv1Msg1,
          timeLabel: '09:12',
        ),
        ChatMessage(
          id: 'msg-2',
          author: ChatMessageAuthor.user,
          text: l10n.chatSeedConv1Msg2,
          timeLabel: '09:13',
        ),
        ChatMessage(
          id: 'msg-3',
          author: ChatMessageAuthor.assistant,
          text: l10n.chatSeedConv1Msg3,
          timeLabel: '09:14',
        ),
        ChatMessage(
          id: 'msg-4',
          author: ChatMessageAuthor.assistant,
          text: l10n.chatSeedConv1Msg4,
          timeLabel: '09:15',
        ),
      ],
    );
  }

  static ChatConversationDetail detailForSummary(
    ChatConversationSummary conversation,
  ) {
    final l10n = appL10n;
    return switch (conversation.id) {
      'conv-2' => ChatConversationDetail(
          id: 'conv-2',
          title: l10n.chatSeedConv2Title,
          petName: 'Moka',
          statusLabel: l10n.chatSeedConv2Status,
          messages: [
            ChatMessage(
              id: 'msg-1',
              author: ChatMessageAuthor.assistant,
              text: l10n.chatSeedConv2Msg1,
              timeLabel: '08:41',
            ),
            ChatMessage(
              id: 'msg-2',
              author: ChatMessageAuthor.user,
              text: l10n.chatSeedConv2Msg2,
              timeLabel: '08:43',
            ),
            ChatMessage(
              id: 'msg-3',
              author: ChatMessageAuthor.assistant,
              text: l10n.chatSeedConv2Msg3,
              timeLabel: '08:44',
            ),
          ],
        ),
      'conv-3' => ChatConversationDetail(
          id: 'conv-3',
          title: l10n.chatSeedConv3Title,
          petName: 'Moka',
          statusLabel: l10n.chatSeedConv3Status,
          messages: [
            ChatMessage(
              id: 'msg-1',
              author: ChatMessageAuthor.assistant,
              text: l10n.chatSeedConv3Msg1,
              timeLabel: '17:05',
            ),
            ChatMessage(
              id: 'msg-2',
              author: ChatMessageAuthor.user,
              text: l10n.chatSeedConv3Msg2,
              timeLabel: '17:06',
            ),
            ChatMessage(
              id: 'msg-3',
              author: ChatMessageAuthor.assistant,
              text: l10n.chatSeedConv3Msg3,
              timeLabel: '17:07',
            ),
          ],
        ),
      _ => detail,
    };
  }
}
