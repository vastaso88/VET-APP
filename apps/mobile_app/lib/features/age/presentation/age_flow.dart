import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/errors/app_error.dart';
import '../data/age_store.dart';
import '../domain/age_status.dart';
import 'pages/birth_date_prompt_page.dart';
import 'pages/closed_account_page.dart';

/// Where the age rules meet the screens.
///
/// A closed account (declared age under the minimum) gets nothing but its own
/// page, from wherever it was found out.
void showClosedAccount(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const ClosedAccountPage()),
    (route) => false,
  );
}

/// Asks for the date of birth on a page of its own. Returns the status after
/// the answer, or null if the owner chose "later" / went back. A date that
/// closes the account goes straight to the closed page.
Future<AgeStatus?> askForBirthDate(
  BuildContext context, {
  required String reason,
  bool allowLater = true,
}) async {
  final status = await Navigator.of(context).push<AgeStatus>(
    MaterialPageRoute<AgeStatus>(
      builder: (_) => BirthDatePromptPage(reason: reason, allowLater: allowLater),
    ),
  );
  if (status != null && status.band == AgeBand.underMinimum && context.mounted) {
    showClosedAccount(context);
  }
  return status;
}

/// True when [error] is the backend refusing a paid plan for age reasons.
bool isAgePlanBlock(AppError error) =>
    error.code == kAgeRequiredCode || error.code == kGuardianRequiredCode;

/// Run before choosing a paid plan: the date is needed first (mandatory, no
/// "later"), and a declared minor must confirm a parent's authorisation.
/// True when the owner may go on. The backend enforces the same rules (403
/// `age_required` / `guardian_required`).
Future<bool> ensureCanChoosePaidPlan(BuildContext context) async {
  final store = AgeStore.instance;
  var status = await store.refresh() ?? store.status;
  if (!context.mounted) return false;

  if (status.band == AgeBand.unknown) {
    final declared = await askForBirthDate(
      context,
      reason: context.l10n.ageReasonPlan,
      allowLater: false,
    );
    if (declared == null || !context.mounted) return false;
    status = declared;
  }
  if (status.band == AgeBand.underMinimum) return false;
  if (status.band == AgeBand.adult || status.paidPlanAllowed) return true;

  // A declared minor.
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.ageGuardianTitle),
      content: Text(dialogContext.l10n.ageGuardianBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(minimumSize: Size.zero),
          child: Text(dialogContext.l10n.ageGuardianConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final result = await store.confirmGuardian();
  if (!context.mounted) return false;
  return result.fold(
    onSuccess: (updated) => updated.paidPlanAllowed,
    onFailure: (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      return false;
    },
  );
}

/// First start after sign-in: a pending date from registration is sent, the
/// status is read, and an account that never declared one is asked (once per
/// run, and "later" is allowed - the Mercatino and paid plans ask again).
/// A closed account is taken to its page.
Future<void> checkAgeAfterSignIn(BuildContext context) async {
  final store = AgeStore.instance;
  final status = await store.refresh();
  if (status == null || !context.mounted) return;

  if (status.band == AgeBand.underMinimum) {
    showClosedAccount(context);
    return;
  }
  if (status.band == AgeBand.unknown && !store.promptDismissed) {
    store.promptDismissed = true;
    await askForBirthDate(context, reason: context.l10n.ageReasonSignIn);
  }
}

/// Used by tests and by the sign-out handler: leaves nothing of the account.
Future<void> forgetAge() => AgeStore.instance.reset();
