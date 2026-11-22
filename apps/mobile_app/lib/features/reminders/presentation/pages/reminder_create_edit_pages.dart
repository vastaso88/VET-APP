import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../l10n/l10n.dart';
import '../../../../app/router/app_router.dart';
import '../../../notifications/presentation/reminder_notification_permission.dart';
import '../../data/reminders_repository.dart';
import '../widgets/reminder_form.dart';
import '../widgets/reminder_page_parts.dart';

class ReminderCreatePage extends StatefulWidget {
  const ReminderCreatePage({super.key, this.petName = ''});

  final String petName;

  @override
  State<ReminderCreatePage> createState() => _ReminderCreatePageState();
}

class _ReminderCreatePageState extends State<ReminderCreatePage> {
  final RemindersRepository _repository = RemindersRepository();

  void _save(ReminderEntry reminder) {
    saveReminderInBackground(_repository, reminder);
    Navigator.of(context).pop();
    // A reminder that can never ring is worse than none: ask for the
    // notification permission now if the phone has not allowed it yet.
    unawaited(maybeAskReminderNotificationPermission(AppRouter.navigatorKey.currentContext));
  }

  @override
  Widget build(BuildContext context) {
    return ReminderPageShell(
      title: widget.petName.isEmpty
          ? context.l10n.remindersCreateTitle
          : context.l10n.remindersCreateTitleForPet(widget.petName),
      subtitle: context.l10n.remindersCreateSubtitle,
      petName: widget.petName,
      child: ReminderForm(
        petName: widget.petName,
        initial: null,
        onSave: _save,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class ReminderEditPage extends StatefulWidget {
  const ReminderEditPage({super.key, this.reminder});

  final ReminderEntry? reminder;

  @override
  State<ReminderEditPage> createState() => _ReminderEditPageState();
}

class _ReminderEditPageState extends State<ReminderEditPage> {
  final RemindersRepository _repository = RemindersRepository();

  void _save(ReminderEntry reminder) {
    saveReminderInBackground(_repository, reminder);
    Navigator.of(context).pop(reminder);
    unawaited(maybeAskReminderNotificationPermission(AppRouter.navigatorKey.currentContext));
  }

  @override
  Widget build(BuildContext context) {
    return ReminderPageShell(
      title: context.l10n.remindersEditTitle,
      subtitle: context.l10n.remindersEditSubtitle,
      petName: widget.reminder?.petName,
      child: ReminderForm(
        petName: widget.reminder?.petName ?? '',
        initial: widget.reminder,
        onSave: _save,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}
