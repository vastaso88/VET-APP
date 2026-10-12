import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/types/result.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../data/chat_demo_store.dart';
import '../../domain/chat_models.dart';

/// The three-dot menu of one conversation: Rinomina, Esporta chat, Riassunto
/// and Elimina. Used in the conversation header and on each conversation row.
class ChatConversationMenuButton extends StatelessWidget {
  const ChatConversationMenuButton({
    required this.conversationId,
    required this.title,
    required this.petName,
    super.key,
  });

  final String conversationId;
  final String title;
  final String petName;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Action>(
      tooltip: context.l10n.chatMenuTooltip,
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.text),
      onSelected: (action) => _run(context, action),
      itemBuilder: (_) => [
        PopupMenuItem(value: _Action.rename, child: Text(context.l10n.chatMenuRename)),
        PopupMenuItem(value: _Action.export, child: Text(context.l10n.chatMenuExport)),
        PopupMenuItem(value: _Action.summary, child: Text(context.l10n.chatMenuSummary)),
        PopupMenuItem(
          value: _Action.delete,
          child: Text(
            context.l10n.commonDelete,
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    );
  }

  String _displayTitle(BuildContext context) =>
      title.trim().isEmpty || title.startsWith('Chat for')
          ? context.l10n.chatDefaultTitle(petName)
          : title;

  Future<void> _run(BuildContext context, _Action action) async {
    switch (action) {
      case _Action.rename:
        await _rename(context);
      case _Action.export:
        await _export(context);
      case _Action.summary:
        await _showSummary(context);
      case _Action.delete:
        await _delete(context);
    }
  }

  void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _export(BuildContext context) async {
    final detail = ChatDemoStore.instance.conversationById(conversationId);
    if (detail == null) {
      _message(context, context.l10n.chatExportOpenFirst);
      return;
    }
    final you = context.l10n.chatSenderYou;
    final assistant = context.l10n.chatSenderAssistant;
    final displayTitle = _displayTitle(context);
    final lines = [
      for (final message in detail.messages)
        '${message.author == ChatMessageAuthor.user ? you : assistant}: ${message.text}',
    ];
    await Share.share('$displayTitle\n\n${lines.join('\n\n')}', subject: displayTitle);
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: _displayTitle(context));
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.chatRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: dialogContext.l10n.chatRenameFieldLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(dialogContext.l10n.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newTitle == null || newTitle.isEmpty || !context.mounted) return;
    final result = await ChatDemoStore.instance.renameConversation(conversationId, newTitle);
    if (!context.mounted) return;
    result.fold(
      onSuccess: (_) {},
      onFailure: (error) => _message(context, error.message),
    );
  }

  Future<void> _showSummary(BuildContext context) async {
    final future = ChatDemoStore.instance.conversationSummary(conversationId);
    final displayTitle = _displayTitle(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FutureBuilder<Result<String>>(
            future: future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: PetLoader(label: context.l10n.chatSummaryLoading)),
                );
              }
              final result = snapshot.data!;
              final summary = result.fold(onSuccess: (text) => text, onFailure: (_) => null);
              final failure = result.fold(onSuccess: (_) => null, onFailure: (e) => e.message);
              final hasSummary = summary != null && summary.isNotEmpty;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.chatSummaryTitle, style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.l10n.chatSummaryDisclaimer,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (hasSummary)
                    Flexible(
                      child: SingleChildScrollView(child: Text(summary, style: AppTextStyles.bodySmall)),
                    )
                  else
                    Text(failure ?? context.l10n.chatSummaryEmpty, style: AppTextStyles.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  if (hasSummary)
                    FilledButton.icon(
                      onPressed: () => Share.share(summary, subject: displayTitle),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(context.l10n.commonShare),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.chatDeleteTitle),
        content: Text(dialogContext.l10n.chatDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ChatDemoStore.instance.deleteConversation(conversationId);
  }
}

enum _Action { rename, export, summary, delete }
