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

  // TODO(human): questi sono placeholder — sostituisci con i prezzi reali
  // di Plus e Pro (mensile ed equivalente mensile se fatturato annuale, in
  // euro). Free resta a 0.
  static const double _plusMonthly = 4.99;
  static const double _plusYearly = 3.99;
  static const double _proMonthly = 9.99;
  static const double _proYearly = 7.99;

  /// Features that exist today and work the same on every plan: nothing in
  /// the code (backend `Subscription.has_access` or the Flutter side) limits
  /// anything per plan yet, so this is the whole honest "what's included".
  /// Each line maps to a real backend route (pets, chat + chat attachments +
  /// speech_to_text, reminders, local_services).
  static const List<PlanFeature> includedInAllPlans = [
    PlanFeature('Profili dei tuoi animali'),
    PlanFeature('Assistente per dubbi su salute, comportamento e routine'),
    PlanFeature('Foto, PDF e dettatura vocale nella chat'),
    PlanFeature('Promemoria'),
    PlanFeature('Servizi per animali nei dintorni'),
  ];

  // TODO(owner): le differenze reali tra i piani sono una scelta commerciale
  // non ancora presa. Finché non le decidi, ogni piano mostra una riga
  // segnaposto (isPlaceholder) al posto di promesse non applicate dal codice.
  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      tier: PlanTier.free,
      displayName: 'Free',
      monthlyPrice: 0,
      yearlyPrice: 0,
      features: [
        PlanFeature('Limiti del piano Free: da definire', isPlaceholder: true),
      ],
    ),
    SubscriptionPlan(
      tier: PlanTier.plus,
      displayName: 'Plus',
      monthlyPrice: _plusMonthly,
      yearlyPrice: _plusYearly,
      features: [
        PlanFeature('Funzioni extra del piano Plus: da definire', isPlaceholder: true),
      ],
    ),
    SubscriptionPlan(
      tier: PlanTier.pro,
      displayName: 'Pro',
      monthlyPrice: _proMonthly,
      yearlyPrice: _proYearly,
      features: [
        PlanFeature('Funzioni extra del piano Pro: da definire', isPlaceholder: true),
      ],
      // "Più scelto" would claim a real popularity ranking we don't have
      // data for yet (no paying users exist). "Consigliato" makes the same
      // visual point without asserting an unverified fact — see legal
      // review note in docs/auth/01_brainstorm.md (2026-09-26).
      badge: 'Consigliato',
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

  PlanTier _currentTier = PlanTier.free;
  BillingCycle _billingCycle = BillingCycle.monthly;
  DateTime? _renewalDate;
  late List<PaymentMethod> _paymentMethods;

  // Real trial/plan state from the backend (packages/core/domain/subscription).
  // Null until the first successful syncFromBackend() call.
  SubscriptionStatus? _subscriptionStatus;

  PlanTier get currentTier => _currentTier;

  BillingCycle get billingCycle => _billingCycle;

  DateTime? get renewalDate => _renewalDate;

  SubscriptionPlan get currentPlan =>
      plans.firstWhere((plan) => plan.tier == _currentTier);

  List<PaymentMethod> get paymentMethods => List.unmodifiable(_paymentMethods);

  /// True while the account has no chosen plan yet and the 10-day free
  /// trial (no card required) is still running.
  bool get isOnTrial => _subscriptionStatus != null &&
      _subscriptionStatus!.plan == null &&
      _subscriptionStatus!.isTrialActive;

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
        _currentTier = status.plan ?? PlanTier.free;
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
    _renewalDate = tier == PlanTier.free
        ? null
        : DateTime.now().add(
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
