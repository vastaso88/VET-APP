import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/billing/domain/subscription_status.dart';
import 'package:vet_app_mobile/features/billing/domain/trial_reminder_rule.dart';

SubscriptionStatus _status({
  required DateTime trialEndsAt,
  PlanTier? plan,
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
  final trialEnd = trialStart.add(const Duration(days: 14));

  DateTime dayAt(int day) => trialStart.add(Duration(days: day - 1, hours: 1));

  test('trial day counts from trial start, 1-based', () {
    expect(TrialReminderRule.trialDayFor(trialEnd, dayAt(1)), 1);
    expect(TrialReminderRule.trialDayFor(trialEnd, dayAt(7)), 7);
    expect(TrialReminderRule.trialDayFor(trialEnd, dayAt(14)), 14);
  });

  test('reminders fire only on days 7, 10, 12 and 14 for owners without a plan', () {
    for (final day in [7, 10, 12, 14]) {
      expect(
        TrialReminderRule.dueDay(_status(trialEndsAt: trialEnd), dayAt(day)),
        day,
        reason: 'day $day should be due',
      );
    }
    for (final day in [1, 2, 3, 4, 5, 6, 8, 9, 11, 13]) {
      expect(
        TrialReminderRule.dueDay(_status(trialEndsAt: trialEnd), dayAt(day)),
        isNull,
        reason: 'day $day should not be due',
      );
    }
  });

  test('no reminder for developers, owners with a plan, or after the trial', () {
    expect(
      TrialReminderRule.dueDay(_status(trialEndsAt: trialEnd, isDeveloper: true), dayAt(7)),
      isNull,
    );
    for (final plan in PlanTier.values) {
      expect(
        TrialReminderRule.dueDay(_status(trialEndsAt: trialEnd, plan: plan), dayAt(7)),
        isNull,
        reason: '${plan.name} owners already chose',
      );
    }
    expect(
      TrialReminderRule.dueDay(
        _status(trialEndsAt: trialEnd),
        trialEnd.add(const Duration(hours: 1)),
      ),
      isNull,
    );
  });

  test('days left counts down to 1 on the last day', () {
    expect(TrialReminderRule.daysLeftFor(7), 8);
    expect(TrialReminderRule.daysLeftFor(14), 1);
  });

  group('SubscriptionStatus.fromJson', () {
    Map<String, dynamic> json({String? plan}) => {
          'subscription': {
            'owner_id': 'owner-a',
            'trial_ends_at': '2026-10-15T09:00:00Z',
            'plan': plan,
            'created_at': '2026-10-01T09:00:00Z',
          },
          'is_developer': false,
          'has_access': true,
          'limits': {
            'max_pets': 8,
            'max_chats_per_pet': 4,
            'daily_questions': 16,
            'max_devices': 3,
          },
          'plan_limits': {
            'plus': {
              'max_pets': 4,
              'max_chats_per_pet': 2,
              'daily_questions': 9,
              'max_devices': 2,
            },
            'ultra': {
              'max_pets': 15,
              'max_chats_per_pet': 6,
              'daily_questions': 30,
              'max_devices': 3,
            },
          },
        };

    test('reads the plan, the limits and the catalogue', () {
      final status = SubscriptionStatus.fromJson(json(plan: 'pro'));

      expect(status.plan, PlanTier.pro);
      expect(status.limits?.dailyQuestions, 16);
      expect(status.planLimits[PlanTier.plus]?.maxPets, 4);
      expect(status.planLimits[PlanTier.ultra]?.maxChatsPerPet, 6);
    });

    test('a retired plan key such as "free" reads as no plan instead of failing', () {
      expect(SubscriptionStatus.fromJson(json(plan: 'free')).plan, isNull);
      expect(SubscriptionStatus.fromJson(json(plan: 'gold')).plan, isNull);
      expect(SubscriptionStatus.fromJson(json()).plan, isNull);
    });

    test('a status without limits (older backend) still parses', () {
      final raw = json(plan: 'plus')
        ..remove('limits')
        ..remove('plan_limits');

      final status = SubscriptionStatus.fromJson(raw);

      expect(status.limits, isNull);
      expect(status.planLimits, isEmpty);
    });

    test('reads the date the data is kept until, and tolerates its absence', () {
      expect(SubscriptionStatus.fromJson(json()).dataKeptUntil, isNull);

      final withDate = json()..['data_kept_until'] = '2027-03-10T09:00:00Z';
      expect(
        SubscriptionStatus.fromJson(withDate).dataKeptUntil,
        DateTime.utc(2027, 3, 10, 9),
      );

      // A malformed date must never break the access gate.
      final broken = json()..['data_kept_until'] = 'not-a-date';
      expect(SubscriptionStatus.fromJson(broken).dataKeptUntil, isNull);
    });
  });
}
