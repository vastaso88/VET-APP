import 'billing_models.dart';

/// Mirrors `GetOrCreateSubscriptionOutput`
/// (packages/core/application/services/get_or_create_subscription.py).
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.trialEndsAt,
    required this.plan,
    required this.isDeveloper,
    required this.hasAccess,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final subscription = json['subscription'] as Map<String, dynamic>;
    final planKey = subscription['plan'] as String?;
    return SubscriptionStatus(
      trialEndsAt: DateTime.parse(subscription['trial_ends_at'] as String),
      plan: planKey == null ? null : PlanTier.values.byName(planKey),
      isDeveloper: json['is_developer'] as bool,
      hasAccess: json['has_access'] as bool,
    );
  }

  final DateTime trialEndsAt;
  final PlanTier? plan;
  final bool isDeveloper;
  final bool hasAccess;

  bool get isTrialActive => DateTime.now().isBefore(trialEndsAt);

  int get trialDaysLeft {
    final remaining = trialEndsAt.difference(DateTime.now());
    return remaining.isNegative ? 0 : remaining.inDays + 1;
  }
}
