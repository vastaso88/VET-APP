import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../data/reminders_repository.dart';
import '../pages/reminders_pages.dart';

/// Three-dot menu of one reminder row (same pattern as the chat rows):
/// Modifica, Segna come fatto, Elimina (red, with confirmation). Failures from
/// the server are shown, never swallowed.
class ReminderMenuButton extends StatelessWidget {
  const ReminderMenuButton({
    required this.reminder,
    required this.repository,
    this.onChanged,
    super.key,
  });

  final ReminderEntry reminder;
  final RemindersRepository repository;

  /// Called after a change that went through, so a list can refresh.
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Action>(
      tooltip: 'Opzioni promemoria',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.text),
      onSelected: (action) => _run(context, action),
      itemBuilder: (_) => [
        const PopupMenuItem(value: _Action.edit, child: Text('Modifica')),
        if (!reminder.isDone)
          const PopupMenuItem(value: _Action.done, child: Text('Segna come fatto')),
        const PopupMenuItem(
          value: _Action.delete,
          child: Text('Elimina', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }

  Future<void> _run(BuildContext context, _Action action) async {
    switch (action) {
      case _Action.edit:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ReminderEditPage(reminder: reminder)),
        );
        onChanged?.call();
      case _Action.done:
        await _guard(() => repository.saveReminder(reminder.copyWith(isDone: true)));
      case _Action.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminare questo promemoria?'),
            content: Text('"${reminder.title}" verrà eliminato definitivamente.'),
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
        if (confirmed == true) await _guard(() => repository.deleteReminder(reminder.id));
    }
  }

  Future<void> _guard(Future<void> Function() change) async {
    try {
      await change();
      onChanged?.call();
    } on ReminderSyncException catch (error) {
      showReminderFailure(error.message);
    }
  }
}

enum _Action { edit, done, delete }
