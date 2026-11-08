import 'billing_models.dart';

/// Mirrors `GetOrCreateSubscriptionOutput`
/// (packages/core/application/services/get_or_create_subscription.py).
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.trialEndsAt,
    required this.plan,
    required this.isDeveloper,
    required this.hasAccess,
    this.limits,
    this.planLimits = const {},
    this.testPeriod = false,
    this.dataKeptUntil,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final subscription = json['subscription'] as Map<String, dynamic>;
    final rawLimits = json['limits'] as Map<String, dynamic>?;
    final rawCatalog = json['plan_limits'] as Map<String, dynamic>? ?? const {};
    return SubscriptionStatus(
      trialEndsAt: DateTime.parse(subscription['trial_ends_at'] as String),
      plan: planTierFromKey(subscription['plan'] as String?),
      isDeveloper: json['is_developer'] as bool,
      hasAccess: json['has_access'] as bool,
      testPeriod: json['test_period'] as bool? ?? false,
      // tryParse: a malformed date must never break the access gate.
      dataKeptUntil: DateTime.tryParse(json['data_kept_until'] as String? ?? ''),
      limits: rawLimits == null ? null : PlanLimits.fromJson(rawLimits),
      planLimits: {
        for (final entry in rawCatalog.entries)
          if (planTierFromKey(entry.key) case final tier?)
            tier: PlanLimits.fromJson(entry.value as Map<String, dynamic>),
      },
    );
  }

  final DateTime trialEndsAt;

  /// The chosen plan; null while on the trial or once it has ended.
  final PlanTier? plan;
  final bool isDeveloper;
  final bool hasAccess;

  /// What the account may do right now; null = no limits (developer).
  final PlanLimits? limits;

  /// The limits of every plan, as the backend enforces them.
  final Map<PlanTier, PlanLimits> planLimits;

  /// True during a public test of the app: every account is on [plan]
  /// (reported by the backend, set by its environment) and nobody pays, so
  /// the app must not ask for a payment or a choice of plan.
  final bool testPeriod;

  /// When the data of an account without access is erased if nothing changes
  /// (four months after the access was lost); null while it has access.
  /// Parsed only: no screen shows it until the legal texts for it exist.
  final DateTime? dataKeptUntil;

  bool get isTrialActive => DateTime.now().isBefore(trialEndsAt);

  int get trialDaysLeft {
    final remaining = trialEndsAt.difference(DateTime.now());
    return remaining.isNegative ? 0 : remaining.inDays + 1;
  }
}

/// A plan key from the backend, or null for no plan. A key this build does
/// not know (a retired plan such as "free", or one added later) reads as no
/// plan: a parse failure here would make the access gate fail open.
PlanTier? planTierFromKey(String? key) {
  for (final tier in PlanTier.values) {
    if (tier.name == key) return tier;
  }
  return null;
}
