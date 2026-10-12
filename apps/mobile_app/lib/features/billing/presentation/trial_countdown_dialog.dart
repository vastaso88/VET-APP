import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_text_styles.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/auth/current_user.dart';
import '../domain/subscription_status.dart';
import '../domain/trial_reminder_rule.dart';
import 'pages/billing_page.dart';

/// Shows the trial countdown on a threshold day (see [TrialReminderRule]),
/// at most once per owner per day, remembered in shared_preferences.
Future<void> showTrialCountdownIfDue(
  BuildContext context,
  SubscriptionStatus status,
) async {
  final now = DateTime.now();
  final day = TrialReminderRule.dueDay(status, now);
  final owner = CurrentUser.get()?.id;
  if (day == null || owner == null) return;

  final preferences = await SharedPreferences.getInstance();
  final key = 'trial_countdown_shown.$owner.$day';
  if (preferences.getBool(key) ?? false) return;
  await preferences.setBool(key, true);

  if (!context.mounted) return;
  final daysLeft = TrialReminderRule.daysLeftFor(day);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
      title: Text(
        dialogContext.l10n.billingTrialDialogTitle(daysLeft),
        style: AppTextStyles.title.copyWith(fontSize: 17),
      ),
      content: Text(
        dialogContext.l10n.billingTrialDialogBody,
        style: AppTextStyles.bodySmall,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.l10n.billingTrialDialogLater),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BillingPage()),
            );
          },
          child: Text(dialogContext.l10n.billingTrialDialogSeePlans),
        ),
      ],
    ),
  );
}
