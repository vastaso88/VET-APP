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
import 'marketplace_conversation_page.dart';

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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(MarketplaceUnreadStore.pollInterval, (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final conversations = await _repository.listConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _failed = false;
      });
      MarketplaceUnreadStore.instance.count.value =
          conversations.fold(0, (total, item) => total + item.unreadCount);
    } on Exception {
      // A list already on screen stays there; only a first load shows the error.
      if (mounted) setState(() => _failed = _conversations == null);
    }
  }

  Future<void> _open(MarketplaceConversation conversation) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MarketplaceConversationPage(
          conversationId: conversation.id,
          listingTitle: conversation.listingTitle,
          repository: _repository,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(
          context.l10n.marketplaceMessagesTitle,
          style: AppTextStyles.title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final conversations = _conversations;
    if (conversations == null) {
      if (!_failed) return const Center(child: PetLoader());
      return _CenteredMessage(
        text: context.l10n.marketplaceMessagesLoadFailed,
        action: TextButton(
          onPressed: () {
            setState(() => _failed = false);
            unawaited(_load());
          },
          child: Text(context.l10n.commonRetry),
        ),
      );
    }
    if (conversations.isEmpty) {
      return _CenteredMessage(text: context.l10n.marketplaceMessagesEmpty);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
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
              label: Text('${conversation.unreadCount}'),
            )
          : null,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: AppTextStyles.body),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
