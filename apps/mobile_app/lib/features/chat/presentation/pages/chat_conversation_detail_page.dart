import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../shared/widgets/pet_loader.dart';


import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../data/chat_demo_store.dart';
import '../../data/chat_seed_data.dart';
import '../../domain/chat_models.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_conversation_menu.dart';
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

  /// The reply that just arrived: the list keeps its start in view (at a
  /// third from the top) instead of jumping to its end, until the owner
  /// sends the next message.
  String? _anchoredReplyId;
  final GlobalKey _anchoredReplyKey = GlobalKey();

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
    String? retryOfMessageId,
  }) async {
    if (_isSending) return;

    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) return;

    setState(() {
      _isSending = true;
      // The owner's own message and the typing indicator go to the bottom.
      _anchoredReplyId = null;
    });

    final result = await _store.sendMessage(
      widget.conversationId,
      cleanMessage,
      attachmentId: attachmentId,
      attachmentImageBytes: attachmentImageBytes,
      retryOfMessageId: retryOfMessageId,
    );

    if (!mounted) return;
    setState(() {
      _isSending = false;
    });

    result.fold(
      onSuccess: (_) {},
      onFailure: (error) {
        _scrollToBottom();
        // A reached conversation limit is expected, not a failure to
        // retry — retrying would just hit the same 400 again.
        final isLimitReached = error.code == 'chat_conversation_limit_reached';
        // A retry reuses the message already shown (and its attachment):
        // the backend recognises it and returns the answer it may already
        // have produced, so nothing is sent or shown twice.
        final failed = _store.lastUserMessage(widget.conversationId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            action: isLimitReached
                ? null
                : SnackBarAction(
                    label: 'Riprova',
                    onPressed: () => _sendMessage(
                      cleanMessage,
                      attachmentId: attachmentId,
                      retryOfMessageId: failed?.text == cleanMessage ? failed?.id : null,
                    ),
                  ),
          ),
        );
      },
    );
  }

  /// After a list change: a reply that just arrived is shown from its
  /// start (see [chatReplyScrollOffset]); anything else scrolls to the end.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final reply = _anchoredReplyId == null ? null : _anchoredReplyKey.currentContext;
      final box = reply?.findRenderObject();
      if (box != null && box.attached) {
        final revealTop = RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset;
        _scrollController.jumpTo(
          chatReplyScrollOffset(
            replyTop: revealTop,
            viewportExtent: position.viewportDimension,
            minScrollExtent: position.minScrollExtent,
            maxScrollExtent: position.maxScrollExtent,
          ),
        );
        return;
      }
      _scrollController.jumpTo(position.maxScrollExtent);
    });
  }

  /// Called while the list lays out a reply that just arrived.
  void _anchorFreshReply(String messageId) {
    _anchoredReplyId = messageId;
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
                _headerTitle(conversation),
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
        ChatConversationMenuButton(
          conversationId: conversation.id,
          title: conversation.title,
          petName: conversation.petName,
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
                          // The whole reply at once (build 26: no more
                          // letter-by-letter reveal); the page keeps its
                          // start in view.
                          if (message.author == ChatMessageAuthor.assistant &&
                              ChatDemoStore.instance.takeFreshReply(message.id)) {
                            state?._anchorFreshReply(message.id);
                          }
                          if (state != null && message.id == state._anchoredReplyId) {
                            return KeyedSubtree(
                              key: state._anchoredReplyKey,
                              child: ChatMessageBubble(message: message),
                            );
                          }
                          return ChatMessageBubble(message: message);
                        }

                        return const ChatTypingBubble();
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

/// Shown while the answer is being produced. After [slowAfter] it says so:
/// an answer can take longer than usual, and the owner should not think
/// the app has stopped (build 26).
class ChatTypingBubble extends StatefulWidget {
  const ChatTypingBubble({super.key, this.slowAfter = const Duration(seconds: 12)});

  final Duration slowAfter;

  static const typingText = 'Sta scrivendo una risposta...';
  static const slowText = 'Ci sto mettendo più del solito, la risposta arriva tra poco...';

  @override
  State<ChatTypingBubble> createState() => _ChatTypingBubbleState();
}

class _ChatTypingBubbleState extends State<ChatTypingBubble> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PetLoader.small(),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                _slow ? ChatTypingBubble.slowText : ChatTypingBubble.typingText,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the list should stand once a reply has arrived: the reply's start
/// a third of the way down the screen, so the owner reads it from the top
/// and scrolls for the rest. A reply short enough to fit below that point
/// simply ends at the bottom of the list, as before.
double chatReplyScrollOffset({
  required double replyTop,
  required double viewportExtent,
  required double minScrollExtent,
  required double maxScrollExtent,
}) {
  final anchored = replyTop - viewportExtent / 3;
  final target = anchored < maxScrollExtent ? anchored : maxScrollExtent;
  return target < minScrollExtent ? minScrollExtent : target;
}

/// The stored title is a placeholder until the backend names the chat.
String _headerTitle(ChatConversationDetail conversation) {
  if (conversation.title.trim().isEmpty || conversation.title.startsWith('Chat for')) {
    return 'Chat con ${conversation.petName}';
  }
  return conversation.title;
}
