import 'subscription_status.dart';

/// Nudges to pick a plan for owners who are still inside the 14-day trial
/// and have not chosen one. Fires once per threshold day, never for
/// developers, never once a plan is chosen or the trial has ended.
class TrialReminderRule {
  const TrialReminderRule._();

  static const trialLengthDays = 14;
  static const reminderDays = {7, 10, 12, 14};

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
    if (status.plan != null) return null;
    if (now.isAfter(status.trialEndsAt)) return null;

    final day = trialDayFor(status.trialEndsAt, now);
    return reminderDays.contains(day) ? day : null;
  }
}
