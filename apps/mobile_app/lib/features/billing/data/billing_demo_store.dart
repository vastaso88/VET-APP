import 'package:flutter/foundation.dart';

import '../domain/billing_models.dart';

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

  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      tier: PlanTier.free,
      displayName: 'Free',
      monthlyPrice: 0,
      yearlyPrice: 0,
      features: [
        'Profilo di un animale',
        'Promemoria di base',
        '5 domande all\'assistente al mese',
      ],
    ),
    SubscriptionPlan(
      tier: PlanTier.plus,
      displayName: 'Plus',
      monthlyPrice: _plusMonthly,
      yearlyPrice: _plusYearly,
      features: [
        'Fino a 3 animali',
        'Promemoria illimitati',
        'Domande illimitate all\'assistente',
        'Cartella clinica digitale',
      ],
    ),
    SubscriptionPlan(
      tier: PlanTier.pro,
      displayName: 'Pro',
      monthlyPrice: _proMonthly,
      yearlyPrice: _proYearly,
      features: [
        'Animali illimitati',
        'Tutto quanto incluso in Plus',
        'Riepilogo pre-visita per il veterinario',
        'Supporto prioritario',
      ],
      badge: 'Più scelto',
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

  PlanTier get currentTier => _currentTier;

  BillingCycle get billingCycle => _billingCycle;

  DateTime? get renewalDate => _renewalDate;

  SubscriptionPlan get currentPlan =>
      plans.firstWhere((plan) => plan.tier == _currentTier);

  List<PaymentMethod> get paymentMethods => List.unmodifiable(_paymentMethods);

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
