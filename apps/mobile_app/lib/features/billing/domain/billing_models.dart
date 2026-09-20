enum PlanTier { free, plus, pro }

enum BillingCycle { monthly, yearly }

enum CardBrand { visa, mastercard, amex }

/// A subscription tier as shown in the plan comparison — mirrors the
/// "Free / Plus / Pro" ladder common apps use for their pricing screen.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.tier,
    required this.displayName,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.features,
    this.badge,
  });

  final PlanTier tier;
  final String displayName;

  /// Price in euro for one month, billed monthly.
  final double monthlyPrice;

  /// Price in euro for one month, billed yearly (usually discounted).
  final double yearlyPrice;

  final List<String> features;

  /// Optional short label shown on the plan card, e.g. "Più scelto".
  final String? badge;

  double priceFor(BillingCycle cycle) =>
      cycle == BillingCycle.yearly ? yearlyPrice : monthlyPrice;
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expiryMonth,
    required this.expiryYear,
    this.isDefault = false,
  });

  final String id;
  final CardBrand brand;
  final String last4;
  final int expiryMonth;
  final int expiryYear;
  final bool isDefault;

  PaymentMethod copyWith({bool? isDefault}) {
    return PaymentMethod(
      id: id,
      brand: brand,
      last4: last4,
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  String get expiryLabel =>
      '${expiryMonth.toString().padLeft(2, '0')}/${expiryYear.toString().substring(2)}';

  String get brandLabel {
    switch (brand) {
      case CardBrand.visa:
        return 'Visa';
      case CardBrand.mastercard:
        return 'Mastercard';
      case CardBrand.amex:
        return 'American Express';
    }
  }
}
