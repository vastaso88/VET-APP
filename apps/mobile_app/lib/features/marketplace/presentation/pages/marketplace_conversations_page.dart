import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../data/marketplace_messages_repository.dart';
import '../../data/marketplace_unread_store.dart';
import '../../domain/marketplace_conversation.dart';
import '../widgets/visibility_poller.dart';
import 'marketplace_conversation_page.dart';
import '../../../../shared/widgets/page_header.dart';
import '../../../../shared/widgets/empty_state.dart';

/// The owner's conversations on the Mercatino, as buyer and as seller.
class MarketplaceConversationsPage extends StatefulWidget {
  const MarketplaceConversationsPage({super.key, this.repository});

  final MarketplaceMessagesRepository? repository;

  @override
  State<MarketplaceConversationsPage> createState() => _MarketplaceConversationsPageState();
}

class _MarketplaceConversationsPageState extends State<MarketplaceConversationsPage> {
  late final MarketplaceMessagesRepository _repository =
      widget.repository ?? MarketplaceMessagesRepository();
  List<MarketplaceConversation>? _conversations;
  bool _failed = false;

  /// Reads the list at opening and every minute, only while this page is the one
  /// on screen and the app is in the foreground; and again at once when the
  /// conversation page above it is closed or the app comes back.
  late final VisibilityPoller _poller = VisibilityPoller(
    interval: MarketplaceUnreadStore.pollInterval,
    onPoll: () => unawaited(_load()),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _poller.attach(ModalRoute.of(context));
  }

  @override
  void dispose() {
    _poller.dispose();
    super.dispose();
  }

  /// The read in progress, if any: a tick, a pull-to-refresh or a retry that
  /// arrives meanwhile shares it instead of starting another.
  Future<void>? _loading;

  Future<void> _load() => _loading ??= _read().whenComplete(() => _loading = null);

  Future<void> _read() async {
    final session = MarketplaceUnreadStore.instance.session;
    try {
      final conversations = await _repository.listConversations();
      // Signed out while the answer was on its way: nothing of it is the next
      // owner's to see, on the page or on the envelope.
      if (!mounted || session != MarketplaceUnreadStore.instance.session) return;
      setState(() {
        _conversations = conversations;
        _failed = false;
      });
      MarketplaceUnreadStore.instance.applyTotal(
        conversations.fold(0, (total, item) => total + item.unreadCount),
        session: session,
      );
    } on Exception {
      // A list already on screen stays there; only a first load shows the error.
      if (mounted && session == MarketplaceUnreadStore.instance.session) {
        setState(() => _failed = _conversations == null);
      }
    }
  }

  /// The conversation page covers this one; when it is closed the poller reads
  /// the list again at once, so the unread numbers match what was just read.
  Future<void> _open(MarketplaceConversation conversation) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MarketplaceConversationPage(
            conversationId: conversation.id,
            listingTitle: conversation.listingTitle,
            repository: _repository,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PageHeader(title: context.l10n.marketplaceMessagesTitle),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final conversations = _conversations;
    if (conversations == null) {
      if (!_failed) return const Center(child: PetLoader());
      return CenteredPageState(
        child: EmptyState.icon(
          icon: Icons.cloud_off_outlined,
          text: context.l10n.marketplaceMessagesLoadFailed,
          action: OutlinedButton(
            onPressed: () {
              setState(() => _failed = false);
              unawaited(_load());
            },
            child: Text(context.l10n.commonRetry),
          ),
        ),
      );
    }
    if (conversations.isEmpty) {
      return CenteredPageState(
        child: EmptyState(text: context.l10n.marketplaceMessagesEmpty),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: conversations.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          return _ConversationRow(
            conversation: conversation,
            onTap: () => _open(conversation),
          );
        },
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.onTap});

  final MarketplaceConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final when = formatAppDate(conversation.lastMessageAt.toLocal(), 'd MMM');
    final parts = [
      conversation.isBuyer ? l10n.marketplaceMessagesRoleBuyer : l10n.marketplaceMessagesRoleSeller,
      when,
      if (conversation.closedReason != null) l10n.marketplaceMessagesClosedTag,
    ];
    final hasUnread = conversation.unreadCount > 0;
    return ListTile(
      key: ValueKey('marketplace-conversation-${conversation.id}'),
      onTap: onTap,
      title: Text(
        conversation.listingTitle,
        style: hasUnread
            ? AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)
            : AppTextStyles.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(parts.join(' · '), style: AppTextStyles.bodySmall),
      trailing: hasUnread
          ? Badge(
              key: ValueKey('marketplace-conversation-unread-${conversation.id}'),
              backgroundColor: AppColors.primary,
              textColor: AppColors.onPrimary,
              label: Text(
                '${conversation.unreadCount}',
                textScaler: TextScaler.noScaling,
              ),
            )
          : null,
    );
  }
}
