import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../data/chat_demo_store.dart';
import '../../data/chat_seed_data.dart';
import '../../domain/chat_models.dart';
import '../widgets/chat_conversation_card.dart';
import '../widgets/chat_empty_state.dart';
import '../widgets/chat_error_state.dart';
import '../widgets/chat_loading_state.dart';
import 'chat_conversation_detail_page.dart';

class ChatConversationsPage extends StatelessWidget {
  const ChatConversationsPage({
    super.key,
    this.state = ChatScreenState.success,
    this.conversations = ChatSeedData.conversations,
    this.onRetry,
    this.onConversationTap,
  });

  final ChatScreenState state;
  final List<ChatConversationSummary> conversations;
  final VoidCallback? onRetry;
  final ValueChanged<ChatConversationSummary>? onConversationTap;

  @override
  Widget build(BuildContext context) {
    final store = ChatDemoStore.instance;
    final usingStoreData = identical(conversations, ChatSeedData.conversations);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF6FAF8),
              Color(0xFFEAF3EE),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) {
              final visibleConversations =
                  state == ChatScreenState.success && usingStoreData
                      ? store.conversations.toList(growable: false)
                      : conversations;
              final totalUnread = visibleConversations.fold<int>(
                0,
                (sum, conversation) => sum + conversation.unreadCount,
              );
              final activePetName = visibleConversations.isEmpty
                  ? 'Moka'
                  : visibleConversations.first.activePetName;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                      AppSpacing.md,
                    ),
                    child: _Header(
                      totalCount: visibleConversations.length,
                      totalUnread: totalUnread,
                      activePetName: activePetName,
                      onStartConversation: () => _startConversation(context),
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: switch (state) {
                        ChatScreenState.loading => const ChatLoadingState(
                            key: ValueKey('loading'),
                            title: 'Carichiamo la chat del pet',
                            subtitle:
                                'Stiamo recuperando i thread piu utili del tuo profilo demo.',
                          ),
                        ChatScreenState.empty => ChatEmptyState(
                            key: const ValueKey('empty'),
                            title: 'Nessuna conversazione ancora',
                            subtitle:
                                'Avvia una chat vera per vedere il flusso completo dell assistente veterinario.',
                            actionLabel: 'Apri la prima chat',
                            onAction: visibleConversations.isEmpty
                                ? () => _startConversation(context)
                                : () => _openConversation(
                                      context,
                                      visibleConversations.first,
                                    ),
                          ),
                        ChatScreenState.error => ChatErrorState(
                            key: const ValueKey('error'),
                            title: 'Non riusciamo a caricare le chat',
                            subtitle:
                                'Controlla la connessione e riprova tra un momento.',
                            actionLabel: 'Indietro',
                            onAction:
                                onRetry ?? () => Navigator.of(context).maybePop(),
                          ),
                        ChatScreenState.success => _ConversationList(
                            key: const ValueKey('success'),
                            conversations: visibleConversations,
                            onConversationTap: onConversationTap ??
                                (conversation) =>
                                    _openConversation(context, conversation),
                            onCreateConversation: () =>
                                _startConversation(context),
                          ),
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openConversation(
    BuildContext context,
    ChatConversationSummary conversation,
  ) {
    final detail = ChatDemoStore.instance.openConversation(conversation.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatConversationDetailPage(
          conversationId: detail.id,
          initialConversation: detail,
        ),
      ),
    );
  }

  void _startConversation(BuildContext context) {
    final conversation = ChatDemoStore.instance.startConversation();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatConversationDetailPage(
          conversationId: conversation.id,
          initialConversation: conversation,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.totalCount,
    required this.totalUnread,
    required this.activePetName,
    required this.onStartConversation,
  });

  final int totalCount;
  final int totalUnread;
  final String activePetName;
  final VoidCallback onStartConversation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14163A35),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'CHAT',
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$totalCount conversazion${totalCount == 1 ? 'e' : 'i'}',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '$activePetName e le sue conversazioni',
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 20,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Domande, risposte e prossimi passi nello stesso flusso, senza perdere il contesto del pet.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _HeaderChip(
                label: '$totalCount conversazioni',
                backgroundColor: AppColors.accentSoft,
                foregroundColor: AppColors.primary,
              ),
              _HeaderChip(
                label: '$totalUnread non lett${totalUnread == 1 ? 'a' : 'e'}',
                backgroundColor: AppColors.warmSurface,
                foregroundColor: const Color(0xFF8B5B3E),
              ),
              const _HeaderChip(
                label: 'Demo pronta',
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onStartConversation,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Nuova chat demo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    super.key,
    required this.conversations,
    required this.onConversationTap,
    required this.onCreateConversation,
  });

  final List<ChatConversationSummary> conversations;
  final ValueChanged<ChatConversationSummary>? onConversationTap;
  final VoidCallback onCreateConversation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        0,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      children: [
        _NewConversationBanner(onCreateConversation: onCreateConversation),
        const SizedBox(height: AppSpacing.lg),
        ...conversations.asMap().entries.expand(
          (entry) {
            final conversation = entry.value;
            return <Widget>[
              ChatConversationCard(
                conversation: conversation,
                onTap: onConversationTap == null
                    ? null
                    : () => onConversationTap!.call(conversation),
              ),
              if (entry.key != conversations.length - 1)
                const SizedBox(height: AppSpacing.md),
            ];
          },
        ),
      ],
    );
  }
}

class _NewConversationBanner extends StatelessWidget {
  const _NewConversationBanner({required this.onCreateConversation});

  final VoidCallback onCreateConversation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avvia una chat reale',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Crea un thread demo con un primo scambio utile, non un placeholder vuoto.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: Size.zero),
            onPressed: onCreateConversation,
            child: const Text('Nuova'),
          ),
        ],
      ),
    );
  }
}
