import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../design_system/tokens/app_colors.dart';
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
      tooltip: 'Opzioni chat',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.text),
      onSelected: (action) => _run(context, action),
      itemBuilder: (_) => const [
        PopupMenuItem(value: _Action.rename, child: Text('Rinomina')),
        PopupMenuItem(value: _Action.export, child: Text('Esporta chat')),
        PopupMenuItem(value: _Action.summary, child: Text('Riassunto')),
        PopupMenuItem(
          value: _Action.delete,
          child: Text('Elimina', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }

  String get _displayTitle =>
      title.trim().isEmpty || title.startsWith('Chat for') ? 'Chat con $petName' : title;

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
      _message(context, 'Apri la chat per esportarla.');
      return;
    }
    final lines = [
      for (final message in detail.messages)
        '${message.author == ChatMessageAuthor.user ? 'Tu' : 'Assistente'}: ${message.text}',
    ];
    await Share.share('$_displayTitle\n\n${lines.join('\n\n')}', subject: _displayTitle);
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: _displayTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rinomina chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Titolo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Salva'),
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
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: PetLoader(label: 'Preparo il riassunto…')),
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
                  Text('Riassunto per il veterinario', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Questo riassunto è generato automaticamente e non è una diagnosi. Per decisioni cliniche consulta il veterinario.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (hasSummary)
                    Flexible(
                      child: SingleChildScrollView(child: Text(summary, style: AppTextStyles.bodySmall)),
                    )
                  else
                    Text(failure ?? 'Nessun riassunto disponibile.', style: AppTextStyles.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  if (hasSummary)
                    FilledButton.icon(
                      onPressed: () => Share.share(summary, subject: _displayTitle),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Condividi'),
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
        title: const Text('Eliminare questa chat?'),
        content: const Text('La conversazione e i suoi messaggi verranno eliminati.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ChatDemoStore.instance.deleteConversation(conversationId);
  }
}

enum _Action { rename, export, summary, delete }
