import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../data/chat_demo_store.dart';
import '../../data/chat_seed_data.dart';
import '../../domain/chat_models.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_empty_state.dart';
import '../widgets/chat_error_state.dart';
import '../widgets/chat_loading_state.dart';
import '../widgets/chat_message_bubble.dart';

class ChatConversationDetailPage extends StatefulWidget {
  const ChatConversationDetailPage({
    super.key,
    required this.conversationId,
    this.initialConversation,
    this.state = ChatScreenState.success,
    this.onRetry,
  });

  final String conversationId;
  final ChatConversationDetail? initialConversation;
  final ChatScreenState state;
  final VoidCallback? onRetry;

  @override
  State<ChatConversationDetailPage> createState() =>
      _ChatConversationDetailPageState();
}

class _ChatConversationDetailPageState extends State<ChatConversationDetailPage> {
  final ChatDemoStore _store = ChatDemoStore.instance;
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  int _lastRenderedMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // Deferred to after this frame: marking the conversation as opened
    // notifies ChatDemoStore listeners, which must not happen while this
    // page itself is still being built during a route transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _store.openConversation(widget.conversationId, fallback: widget.initialConversation);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _store,
          builder: (context, _) {
            final conversation = _store.conversationById(widget.conversationId) ??
                widget.initialConversation ??
                ChatSeedData.detail;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: _Header(conversation: conversation),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (widget.state) {
                      ChatScreenState.loading => const ChatLoadingState(
                          key: ValueKey('loading'),
                          title: 'Apriamo la conversazione',
                          subtitle:
                              'Stiamo caricando il thread e l ultimo contesto disponibile.',
                        ),
                      ChatScreenState.empty => ChatEmptyState(
                          key: const ValueKey('empty'),
                          title: 'La conversazione e vuota',
                          subtitle:
                              'Scrivi il primo messaggio per iniziare il dialogo con l assistente.',
                          actionLabel: 'Scrivi ora',
                          onAction: () => _sendMessage(
                            'Ciao, ho una domanda per ${conversation.petName}.',
                          ),
                        ),
                      ChatScreenState.error => ChatErrorState(
                          key: const ValueKey('error'),
                          title: 'Conversazione non disponibile',
                          subtitle:
                              'Qualcosa e andato storto nel recupero del thread.',
                          actionLabel: 'Torna alle chat',
                          onAction:
                              widget.onRetry ?? () => Navigator.of(context).maybePop(),
                        ),
                      ChatScreenState.success => _SuccessConversationView(
                          key: const ValueKey('success'),
                          conversation: conversation,
                          isSending: _isSending,
                          onSendMessage: _sendMessage,
                          scrollController: _scrollController,
                        ),
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _sendMessage(
    String message, {
    String? attachmentId,
    Uint8List? attachmentImageBytes,
  }) async {
    if (_isSending) return;

    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    final result = await _store.sendMessage(
      widget.conversationId,
      cleanMessage,
      attachmentId: attachmentId,
      attachmentImageBytes: attachmentImageBytes,
    );

    if (!mounted) return;
    setState(() {
      _isSending = false;
    });
    _scrollToBottom();

    result.fold(
      onSuccess: (_) {},
      onFailure: (error) {
        // A reached conversation limit is expected, not a failure to
        // retry — retrying would just hit the same 400 again.
        final isLimitReached = error.code == 'chat_conversation_limit_reached';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            action: isLimitReached
                ? null
                : SnackBarAction(
                    label: 'Riprova',
                    onPressed: () => _sendMessage(cleanMessage),
                  ),
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _scheduleScrollIfNeeded(int messageCount) {
    if (_lastRenderedMessageCount == messageCount) {
      return;
    }

    _lastRenderedMessageCount = messageCount;
    _scrollToBottom();
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.conversation,
  });

  final ChatConversationDetail conversation;

  @override
  Widget build(BuildContext context) {
    // Capped at 2 lines total (title + pet name) — this header doesn't
    // scroll away, so every extra line here is a line the message list
    // below permanently loses.
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                conversation.petName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuccessConversationView extends StatelessWidget {
  const _SuccessConversationView({
    super.key,
    required this.conversation,
    required this.isSending,
    required this.onSendMessage,
    required this.scrollController,
  });

  final ChatConversationDetail conversation;
  final bool isSending;
  final void Function(String text, {String? attachmentId, Uint8List? attachmentImageBytes})
      onSendMessage;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final totalItems = conversation.messages.length + (isSending ? 1 : 0);
        final state = context
            .findAncestorStateOfType<_ChatConversationDetailPageState>();
        state?._scheduleScrollIfNeeded(totalItems);

        return Column(
          children: [
            Expanded(
              child: totalItems == 0
                  ? _NewConversationPlaceholder(petName: conversation.petName)
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      itemBuilder: (context, index) {
                        if (index < conversation.messages.length) {
                          final message = conversation.messages[index];
                          return ChatMessageBubble(message: message);
                        }

                        return const _TypingBubble();
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemCount: totalItems,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: ChatComposer(
                hintText: 'Scrivi una domanda su ${conversation.petName}',
                petName: conversation.petName,
                onSend: onSendMessage,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NewConversationPlaceholder extends StatelessWidget {
  const _NewConversationPlaceholder({required this.petName});

  final String petName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nuova conversazione su $petName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Scrivi qui sotto cosa stai osservando: ti rispondo subito.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Sta scrivendo una risposta...',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
