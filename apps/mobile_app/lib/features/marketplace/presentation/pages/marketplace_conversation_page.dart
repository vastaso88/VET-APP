import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../billing/data/billing_demo_store.dart';
import '../../data/marketplace_messages_repository.dart';
import '../../data/marketplace_unread_store.dart';
import '../../domain/marketplace_conversation.dart';
import '../widgets/messages_safety_notice.dart';

/// Same limit as the backend (`MESSAGE_MAX_LENGTH`), which is what decides.
const _maxMessageLength = 1000;
const _pollInterval = Duration(seconds: 20);

/// One conversation. Opened on an existing one ([conversationId]) or from an ad
/// ([listingId]): then it looks for the buyer's conversation about that ad and,
/// if there is none, starts empty. Nothing exists on the server until the first
/// message is sent.
class MarketplaceConversationPage extends StatefulWidget {
  const MarketplaceConversationPage({
    super.key,
    this.conversationId,
    this.listingId,
    required this.listingTitle,
    this.repository,
  }) : assert(conversationId != null || listingId != null);

  final String? conversationId;
  final String? listingId;
  final String listingTitle;
  final MarketplaceMessagesRepository? repository;

  @override
  State<MarketplaceConversationPage> createState() => _MarketplaceConversationPageState();
}

class _MarketplaceConversationPageState extends State<MarketplaceConversationPage> {
  late final MarketplaceMessagesRepository _repository =
      widget.repository ?? MarketplaceMessagesRepository();
  final TextEditingController _controller = TextEditingController();
  MarketplaceConversation? _conversation;
  List<MarketplaceMessage> _messages = const [];
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(_pollInterval, (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      var id = _conversation?.id ?? widget.conversationId;
      id ??= (await _repository.conversationForListing(widget.listingId!))?.id;
      if (id == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final thread = await _repository.readThread(id);
      if (!mounted) return;
      setState(() {
        _conversation = thread.conversation;
        _messages = thread.messages;
        _loading = false;
        _failed = false;
      });
      if (thread.conversation.unreadCount > 0) await _markRead(id);
    } on Exception {
      // What is on screen stays; only a first load shows the error.
      if (mounted) {
        setState(() {
          _failed = _loading;
          _loading = false;
        });
      }
    }
  }

  Future<void> _markRead(String id) async {
    await _repository.markRead(id);
    await MarketplaceUnreadStore.instance.refresh(_repository);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final id = _conversation?.id;
      final sent = id == null
          ? await _repository.writeToSeller(widget.listingId!, text)
          : await _repository.sendMessage(id, text);
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _conversation = sent.conversation;
        _messages = [..._messages, sent.message];
      });
    } on NewConversationLimitException catch (error) {
      if (mounted) _showMessage(context.l10n.marketplaceMessagesDailyLimit(error.limit));
    } on ConversationClosedException {
      if (mounted) _showMessage(context.l10n.marketplaceMessagesClosed);
      await _load();
    } on MarketplaceRestrictedException catch (error) {
      if (mounted) _showMessage(error.restriction.message(context.l10n));
      await _load();
    } on ConversationNotFoundException {
      if (mounted) _showMessage(context.l10n.marketplaceMessagesUnavailable);
    } on MessagesPlanRequiredException {
      // Already on the paywall.
    } on Exception {
      if (mounted) _showMessage(context.l10n.marketplaceMessagesSendFailed);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmBlock(MarketplaceConversation conversation) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.marketplaceMessagesBlockTitle),
        content: Text(l10n.marketplaceMessagesBlockBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const ValueKey('marketplace-messages-block-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l10n.marketplaceMessagesBlockConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _changeBlock(
      () => _repository.block(conversation.id),
      l10n.marketplaceMessagesBlocked,
    );
  }

  Future<void> _changeBlock(
    Future<MarketplaceConversation> Function() change,
    String done,
  ) async {
    final failed = context.l10n.marketplaceMessagesActionFailed;
    try {
      final updated = await change();
      if (!mounted) return;
      setState(() => _conversation = updated);
      _showMessage(done);
    } on Exception {
      if (mounted) _showMessage(failed);
    }
  }

  Future<void> _report(MarketplaceConversation conversation) async {
    final l10n = context.l10n;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.marketplaceMessagesReport),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Text(l10n.marketplaceMessagesReportPrivacy, style: AppTextStyles.bodySmall),
          ),
          for (final entry in {
            'spam': l10n.marketplaceReasonSpam,
            'scam': l10n.marketplaceReasonScam,
            'harassment': l10n.marketplaceMessagesReasonHarassment,
            'inappropriate': l10n.marketplaceReasonInappropriate,
            'other': l10n.marketplaceOther,
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(entry.key),
              child: Text(entry.value),
            ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await _repository.report(conversation.id, reason);
      if (mounted) _showMessage(l10n.marketplaceReportSent);
    } on Exception {
      if (mounted) _showMessage(l10n.marketplaceMessagesActionFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(
          conversation?.listingTitle ?? widget.listingTitle,
          style: AppTextStyles.title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (conversation != null) _menu(context, conversation),
        ],
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _menu(BuildContext context, MarketplaceConversation conversation) {
    final l10n = context.l10n;
    final blocked = conversation.closedReason == ConversationClosedReason.blockedByMe;
    return PopupMenuButton<String>(
      key: const ValueKey('marketplace-messages-menu'),
      tooltip: l10n.marketplaceMessagesMoreActions,
      onSelected: (action) {
        switch (action) {
          case 'block':
            unawaited(_confirmBlock(conversation));
          case 'unblock':
            unawaited(_changeBlock(
              () => _repository.unblock(conversation.id),
              l10n.marketplaceMessagesUnblocked,
            ));
          case 'report':
            unawaited(_report(conversation));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: blocked ? 'unblock' : 'block',
          child: Text(blocked ? l10n.marketplaceMessagesUnblock : l10n.marketplaceMessagesBlock),
        ),
        PopupMenuItem(value: 'report', child: Text(l10n.marketplaceMessagesReport)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: PetLoader());
    if (_failed) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.marketplaceMessagesLoadFailed,
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () {
                  setState(() {
                    _failed = false;
                    _loading = true;
                  });
                  unawaited(_load());
                },
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }
    final reversed = _messages.reversed.toList();
    return Column(
      children: [
        Expanded(
          // Reversed, so the newest message sits above the composer and the list
          // stays there when the keyboard opens. The last item is the top one.
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: reversed.length + 1,
            itemBuilder: (context, index) {
              if (index == reversed.length) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: MessagesSafetyNotice(),
                );
              }
              return _MessageBubble(message: reversed[index]);
            },
          ),
        ),
        _footer(context),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final conversation = _conversation;
    final closure = conversation?.closedReason;
    if (closure != null) {
      return _Banner(
        key: const ValueKey('marketplace-messages-closed'),
        text: closure == ConversationClosedReason.restricted
            ? context.l10n.marketplaceRestrictedConversation
            : closure == ConversationClosedReason.blockedByMe
                ? context.l10n.marketplaceMessagesBlockedByMe
                : context.l10n.marketplaceMessagesClosed,
      );
    }
    if (!BillingDemoStore.instance.hasAccess) {
      return _Banner(
        key: const ValueKey('marketplace-messages-plan-required'),
        text: context.l10n.marketplaceMessagesPlanRequired,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('marketplace-messages-field'),
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              maxLength: _maxMessageLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: context.l10n.marketplaceMessagesHint,
                counterText: '',
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('marketplace-messages-send'),
            tooltip: context.l10n.marketplaceMessagesSend,
            onPressed: _busy ? null : _send,
            color: AppColors.primary,
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final MarketplaceMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.8;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: mine ? AppColors.primarySoft : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.large),
          border: mine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plain text: what people write is never interpreted as markup or links.
            SelectableText(message.body, style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatAppDate(message.createdAt.toLocal(), 'd MMM HH:mm'),
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.backgroundDeep,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Text(text, style: AppTextStyles.bodySmall),
    );
  }
}
