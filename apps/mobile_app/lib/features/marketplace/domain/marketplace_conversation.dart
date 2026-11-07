/// Why a conversation does not accept messages. [closed] covers a closed ad, the
/// team's moderation and a block by the other person: the backend does not tell
/// them apart on purpose, so nobody learns they were blocked.
enum ConversationClosedReason { closed, blockedByMe }

/// A conversation as the backend shows it to one of its two participants. It
/// carries no account id of anyone: the role is all the app knows of the other.
class MarketplaceConversation {
  const MarketplaceConversation({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.isBuyer,
    required this.unreadCount,
    required this.canWrite,
    required this.closedReason,
    required this.lastMessageAt,
  });

  factory MarketplaceConversation.fromJson(Map<String, dynamic> json) {
    return MarketplaceConversation(
      id: json['id'] as String,
      listingId: json['listing_id'] as String?,
      listingTitle: json['listing_title'] as String? ?? '',
      isBuyer: json['role'] == 'buyer',
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      canWrite: json['can_write'] == true,
      closedReason: switch (json['closed_reason']) {
        'blocked_by_me' => ConversationClosedReason.blockedByMe,
        'closed' => ConversationClosedReason.closed,
        _ => null,
      },
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
    );
  }

  final String id;

  /// Null once the ad has been deleted; [listingTitle] stays.
  final String? listingId;
  final String listingTitle;
  final bool isBuyer;
  final int unreadCount;
  final bool canWrite;
  final ConversationClosedReason? closedReason;
  final DateTime lastMessageAt;
}

class MarketplaceMessage {
  const MarketplaceMessage({
    required this.id,
    required this.body,
    required this.mine,
    required this.createdAt,
  });

  factory MarketplaceMessage.fromJson(Map<String, dynamic> json) {
    return MarketplaceMessage(
      id: json['id'] as String,
      body: json['body'] as String? ?? '',
      mine: json['mine'] == true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String body;
  final bool mine;
  final DateTime createdAt;
}

class ConversationThread {
  const ConversationThread({required this.conversation, required this.messages});

  final MarketplaceConversation conversation;
  final List<MarketplaceMessage> messages;
}

class SentMarketplaceMessage {
  const SentMarketplaceMessage({required this.conversation, required this.message});

  final MarketplaceConversation conversation;
  final MarketplaceMessage message;
}
