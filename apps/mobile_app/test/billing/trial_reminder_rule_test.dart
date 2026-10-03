import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/billing/domain/subscription_status.dart';
import 'package:vet_app_mobile/features/billing/domain/trial_reminder_rule.dart';

SubscriptionStatus _status({
  required DateTime trialEndsAt,
  PlanTier? plan = PlanTier.free,
  bool isDeveloper = false,
}) {
  return SubscriptionStatus(
    trialEndsAt: trialEndsAt,
    plan: plan,
    isDeveloper: isDeveloper,
    hasAccess: true,
  );
}

void main() {
  final trialStart = DateTime(2026, 10, 1, 9);
  final trialEnd = trialStart.add(const Duration(days: 10));

  DateTime dayAt(int day) => trialStart.add(Duration(days: day - 1, hours: 1));

  test('trial day counts from trial start, 1-based', () {
    expect(TrialReminderRule.trialDayFor(trialEnd, dayAt(1)), 1);
    expect(TrialReminderRule.trialDayFor(trialEnd, dayAt(5)), 5);
    expect(TrialReminderRule.trialDayFor(trialEnd, dayAt(10)), 10);
  });

  test('reminders fire only on days 5, 7, 9 and 10 for Free-plan owners', () {
    for (final day in [5, 7, 9, 10]) {
      expect(
        TrialReminderRule.dueDay(_status(trialEndsAt: trialEnd), dayAt(day)),
        day,
        reason: 'day $day should be due',
      );
    }
    for (final day in [1, 2, 3, 4, 6, 8]) {
      expect(
        TrialReminderRule.dueDay(_status(trialEndsAt: trialEnd), dayAt(day)),
        isNull,
        reason: 'day $day should not be due',
      );
    }
  });

  test('no reminder for developers, non-Free plans, or after the trial', () {
    expect(
      TrialReminderRule.dueDay(_status(trialEndsAt: trialEnd, isDeveloper: true), dayAt(5)),
      isNull,
    );
    expect(
      TrialReminderRule.dueDay(_status(trialEndsAt: trialEnd, plan: PlanTier.plus), dayAt(5)),
      isNull,
    );
    expect(
      TrialReminderRule.dueDay(_status(trialEndsAt: trialEnd, plan: null), dayAt(5)),
      isNull,
    );
    expect(
      TrialReminderRule.dueDay(
        _status(trialEndsAt: trialEnd),
        trialEnd.add(const Duration(hours: 1)),
      ),
      isNull,
    );
  });

  test('days left counts down to 1 on the last day', () {
    expect(TrialReminderRule.daysLeftFor(5), 6);
    expect(TrialReminderRule.daysLeftFor(10), 1);
  });
}
