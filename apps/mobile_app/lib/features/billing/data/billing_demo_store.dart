import 'package:flutter/foundation.dart';

import '../domain/billing_models.dart';
import '../domain/subscription_status.dart';
import 'subscription_remote_data_source.dart';

/// In-memory demo data for the pricing/payment-methods settings section —
/// same pattern as PetDemoStore/ChatDemoStore: no billing backend exists
/// yet, but the UI can be built and exercised end-to-end against this
/// store, then swapped for a real remote data source later.
class BillingDemoStore extends ChangeNotifier {
  BillingDemoStore._() {
    _paymentMethods = List<PaymentMethod>.of(_initialPaymentMethods);
  }

  static final BillingDemoStore instance = BillingDemoStore._();

  /// What every plan shares. Each line maps to a real backend route (pets,
  /// chat + chat attachments + speech_to_text, reminders, local_services).
  /// What changes from plan to plan is the four limits, see
  /// [limitFeaturesFor].
  static const List<PlanFeature> includedInAllPlans = [
    PlanFeature(PlanFeatureId.includedPets),
    PlanFeature(PlanFeatureId.includedAssistant),
    PlanFeature(PlanFeatureId.includedChatMedia),
    PlanFeature(PlanFeatureId.includedReminders),
    PlanFeature(PlanFeatureId.includedNearbyServices),
  ];

  /// Starting prices for Italy (docs/marketing/03_prezzi_per_paese.md):
  /// the yearly price is ten months. Prices for the other countries are set
  /// in the store consoles, and once real subscriptions exist the app shows
  /// the price the store returns, not these figures.
  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      tier: PlanTier.plus,
      displayName: 'Plus',
      monthlyPrice: 4.59,
      yearlyPrice: 45.99,
    ),
    SubscriptionPlan(
      tier: PlanTier.pro,
      displayName: 'Pro',
      monthlyPrice: 8.59,
      yearlyPrice: 85.99,
      // "Più scelto" would claim a real popularity ranking we don't have
      // data for yet (no paying users exist). "Consigliato" makes the same
      // visual point without asserting an unverified fact — see legal
      // review note in docs/auth/01_brainstorm.md (2026-09-26).
      isRecommended: true,
    ),
    SubscriptionPlan(
      tier: PlanTier.ultra,
      displayName: 'Ultra',
      monthlyPrice: 15.59,
      yearlyPrice: 155.99,
    ),
  ];

  static final List<PaymentMethod> _initialPaymentMethods = [
    const PaymentMethod(
      id: 'pm_demo_1',
      brand: CardBrand.visa,
      last4: '4242',
      expiryMonth: 9,
      expiryYear: 2028,
      isDefault: true,
    ),
  ];

  PlanTier? _currentTier;
  BillingCycle _billingCycle = BillingCycle.yearly;
  DateTime? _renewalDate;
  late List<PaymentMethod> _paymentMethods;

  // Real trial/plan state from the backend (packages/core/domain/subscription).
  // Null until the first successful syncFromBackend() call.
  SubscriptionStatus? _subscriptionStatus;

  /// The chosen plan; null while on the trial or once it has ended.
  PlanTier? get currentTier => _currentTier;

  BillingCycle get billingCycle => _billingCycle;

  DateTime? get renewalDate => _renewalDate;

  static SubscriptionPlan planFor(PlanTier tier) =>
      plans.firstWhere((plan) => plan.tier == tier);

  SubscriptionPlan? get currentPlan {
    final tier = _currentTier;
    return tier == null ? null : planFor(tier);
  }

  List<PaymentMethod> get paymentMethods => List.unmodifiable(_paymentMethods);

  /// The limits of [tier] as the backend enforces them; null until the first
  /// successful sync (the screens then simply leave the limit lines out).
  PlanLimits? planLimitsFor(PlanTier tier) => _subscriptionStatus?.planLimits[tier];

  /// The four limit lines of [tier], empty until the backend has answered.
  List<PlanFeature> limitFeaturesFor(PlanTier tier) {
    final limits = planLimitsFor(tier);
    return limits == null ? const [] : PlanFeature.forLimits(limits);
  }

  /// True while the account has no chosen plan yet and the 14-day free
  /// trial (no card required) is still running.
  bool get isOnTrial => _subscriptionStatus != null &&
      _subscriptionStatus!.plan == null &&
      _subscriptionStatus!.isTrialActive;

  /// True while the backend runs a public test: everyone on the same plan,
  /// nobody pays, nothing to choose.
  bool get isTestPeriod => _subscriptionStatus?.testPeriod ?? false;

  /// False until the first answer of the backend.
  bool get hasLoadedStatus => _subscriptionStatus != null;

  int get trialDaysLeft => _subscriptionStatus?.trialDaysLeft ?? 0;

  DateTime? get trialEndsAt => _subscriptionStatus?.trialEndsAt;

  bool get isDeveloperAccount => _subscriptionStatus?.isDeveloper ?? false;

  /// False once the trial has expired and no plan has been chosen (and the
  /// account isn't on the developer allowlist) — the paywall gate reads this.
  bool get hasAccess => _subscriptionStatus?.hasAccess ?? true;

  Future<void> syncFromBackend({SubscriptionRemoteDataSource? dataSource}) async {
    final source = dataSource ?? HttpSubscriptionRemoteDataSource();
    final result = await source.fetchStatus();
    result.fold(
      onSuccess: (status) {
        _subscriptionStatus = status;
        _currentTier = status.plan;
        notifyListeners();
      },
      onFailure: (_) {
        // Keep the previous (or default) local state — the billing page
        // still works from cached/demo data if the backend is unreachable.
      },
    );
  }

  void setBillingCycle(BillingCycle cycle) {
    if (_billingCycle == cycle) return;
    _billingCycle = cycle;
    notifyListeners();
  }

  void switchToPlan(PlanTier tier) {
    _currentTier = tier;
    _renewalDate = DateTime.now().add(
      _billingCycle == BillingCycle.yearly
          ? const Duration(days: 365)
          : const Duration(days: 30),
    );
    notifyListeners();
  }

  void addPaymentMethod(PaymentMethod method) {
    final makeDefault = _paymentMethods.isEmpty || method.isDefault;
    _paymentMethods = [
      if (makeDefault) ..._paymentMethods.map((m) => m.copyWith(isDefault: false)),
      if (!makeDefault) ..._paymentMethods,
      method.copyWith(isDefault: makeDefault),
    ];
    notifyListeners();
  }

  void removePaymentMethod(String id) {
    final wasDefault = _paymentMethods.any((m) => m.id == id && m.isDefault);
    _paymentMethods = _paymentMethods.where((m) => m.id != id).toList();
    if (wasDefault && _paymentMethods.isNotEmpty) {
      _paymentMethods[0] = _paymentMethods[0].copyWith(isDefault: true);
    }
    notifyListeners();
  }

  void setDefaultPaymentMethod(String id) {
    _paymentMethods = [
      for (final method in _paymentMethods) method.copyWith(isDefault: method.id == id),
    ];
    notifyListeners();
  }
}
