import '../../../l10n/l10n.dart';
import '../../../l10n/regional_defaults.dart';

enum PlanTier { free, plus, pro }

enum BillingCycle { monthly, yearly }

enum CardBrand { visa, mastercard, amex }

extension CardBrandLabel on CardBrand {
  String get label {
    switch (this) {
      case CardBrand.visa:
        return 'Visa';
      case CardBrand.mastercard:
        return 'Mastercard';
      case CardBrand.amex:
        return 'American Express';
    }
  }
}

/// Every feature line the plan screens can show; the wording lives in the
/// ARB catalog and is resolved when read (see [PlanFeature.label]).
enum PlanFeatureId {
  includedPets,
  includedAssistant,
  includedChatMedia,
  includedReminders,
  includedNearbyServices,
  freePlaceholder,
  plusPlaceholder,
  proPlaceholder,
}

/// One line in a plan's "what's included" list. [isPlaceholder] marks a
/// commercial decision the owner hasn't made yet, so the UI renders it as an
/// obvious "to be defined" line instead of a promise.
class PlanFeature {
  const PlanFeature(this.id, {this.isPlaceholder = false});

  final PlanFeatureId id;
  final bool isPlaceholder;

  String get label {
    final l10n = appL10n;
    return switch (id) {
      PlanFeatureId.includedPets => l10n.billingIncludedPets,
      PlanFeatureId.includedAssistant => l10n.billingIncludedAssistant,
      PlanFeatureId.includedChatMedia => l10n.billingIncludedChatMedia,
      PlanFeatureId.includedReminders => l10n.billingIncludedReminders,
      PlanFeatureId.includedNearbyServices => l10n.billingIncludedNearbyServices,
      PlanFeatureId.freePlaceholder => l10n.billingFreePlaceholder,
      PlanFeatureId.plusPlaceholder => l10n.billingPlusPlaceholder,
      PlanFeatureId.proPlaceholder => l10n.billingProPlaceholder,
    };
  }
}

/// "4,99 €", "£4.99", "$4.99", "A$4.99" or "CHF 4.99": the placeholder price
/// in the chosen variant's currency (the figure is not converted: real prices
/// per country are still to be set).
String formatPlanAmount(double price) => formatAppMoney(price);

/// A subscription tier as shown in the plan comparison — mirrors the
/// "Free / Plus / Pro" ladder common apps use for their pricing screen.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.tier,
    required this.displayName,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.features,
    this.isRecommended = false,
  });

  final PlanTier tier;
  final String displayName;

  /// Placeholder price for one month, billed monthly, in the chosen
  /// variant's currency (see [formatPlanAmount]).
  final double monthlyPrice;

  /// Placeholder price for one month, billed yearly (usually discounted).
  final double yearlyPrice;

  /// What this plan has beyond (or instead of) the shared baseline in
  /// `BillingDemoStore.includedInAllPlans`.
  final List<PlanFeature> features;

  /// Highlights the plan with a "Consigliato" badge.
  final bool isRecommended;

  /// Short label shown on the plan card, or null when not highlighted.
  String? get badge => isRecommended ? appL10n.billingPlanBadgeRecommended : null;

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

  String get brandLabel => brand.label;
}
