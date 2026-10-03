import 'billing_models.dart';
import 'subscription_status.dart';

/// Upgrade nudges for owners who picked the Free plan while still inside the
/// 10-day trial (so the trial clock is still running). Fires once per
/// threshold day, never for developers, never after the trial has ended.
class TrialReminderRule {
  const TrialReminderRule._();

  static const trialLengthDays = 10;
  static const reminderDays = {5, 7, 9, 10};

  /// 1-based day of the trial for [now], clamped to 1..[trialLengthDays].
  static int trialDayFor(DateTime trialEndsAt, DateTime now) {
    final start = trialEndsAt.subtract(const Duration(days: trialLengthDays));
    final elapsed = now.difference(start).inDays + 1;
    return elapsed.clamp(1, trialLengthDays);
  }

  static int daysLeftFor(int trialDay) => trialLengthDays + 1 - trialDay;

  /// The threshold day to show right now, or null if no reminder is due.
  static int? dueDay(SubscriptionStatus status, DateTime now) {
    if (status.isDeveloper) return null;
    if (status.plan != PlanTier.free) return null;
    if (now.isAfter(status.trialEndsAt)) return null;

    final day = trialDayFor(status.trialEndsAt, now);
    return reminderDays.contains(day) ? day : null;
  }
}
