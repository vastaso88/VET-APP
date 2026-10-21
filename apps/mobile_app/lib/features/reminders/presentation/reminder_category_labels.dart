import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../medical_records/presentation/record_category_labels.dart';
import '../domain/reminder_category.dart';

/// What the owner reads for a reminder category and its symbol. The clinical
/// ones are the cartella clinica's own (same name, same icon), so a reminder and
/// the record it becomes look alike.
extension ReminderCategoryLabels on ReminderCategory {
  /// "Visita", "Vaccino"... (singular, as on one record).
  String label(AppLocalizations l10n) => switch (this) {
        ReminderCategory.grooming => l10n.reminderCatGrooming,
        ReminderCategory.other => l10n.reminderCatOther,
        _ => recordCategory!.singularLabel(l10n),
      };

  IconData get icon => switch (this) {
        ReminderCategory.grooming => Icons.content_cut_outlined,
        ReminderCategory.other => Icons.event_outlined,
        _ => recordCategory!.icon,
      };
}
