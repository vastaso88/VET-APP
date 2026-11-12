import '../../../l10n/l10n.dart';
import '../../../l10n/regional_defaults.dart';

/// There is no free plan: after the 14-day trial an owner without a plan
/// reaches only their own data (export, account deletion).
enum PlanTier { plus, pro, ultra }

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

/// What one plan allows. The backend is the single source of these numbers
/// (`packages/core/domain/subscription/limits.py`, sent by
/// `GET /subscription/status`): the app never keeps its own copy.
class PlanLimits {
  const PlanLimits({
    required this.maxPets,
    required this.maxChatsPerPet,
    required this.dailyQuestions,
    required this.maxDevices,
  });

  factory PlanLimits.fromJson(Map<String, dynamic> json) {
    return PlanLimits(
      maxPets: json['max_pets'] as int,
      maxChatsPerPet: json['max_chats_per_pet'] as int,
      dailyQuestions: json['daily_questions'] as int,
      maxDevices: json['max_devices'] as int,
    );
  }

  final int maxPets;
  final int maxChatsPerPet;
  final int dailyQuestions;
  final int maxDevices;
}

/// Every feature line the plan screens can show; the wording lives in the
/// ARB catalog and is resolved when read (see [PlanFeature.label]).
enum PlanFeatureId {
  includedPets,
  includedAssistant,
  includedChatMedia,
  includedReminders,
  includedNearbyServices,
  limitPets,
  limitChatsPerPet,
  limitQuestionsPerDay,
  limitDevices,
}

/// One line in a plan's "what's included" list. [count] fills the number of
/// the limit lines.
class PlanFeature {
  const PlanFeature(this.id, {this.count = 0});

  final PlanFeatureId id;
  final int count;

  String get label {
    final l10n = appL10n;
    return switch (id) {
      PlanFeatureId.includedPets => l10n.billingIncludedPets,
      PlanFeatureId.includedAssistant => l10n.billingIncludedAssistant,
      PlanFeatureId.includedChatMedia => l10n.billingIncludedChatMedia,
      PlanFeatureId.includedReminders => l10n.billingIncludedReminders,
      PlanFeatureId.includedNearbyServices => l10n.billingIncludedNearbyServices,
      PlanFeatureId.limitPets => l10n.billingLimitPets(count),
      PlanFeatureId.limitChatsPerPet => l10n.billingLimitChatsPerPet(count),
      PlanFeatureId.limitQuestionsPerDay => l10n.billingLimitQuestionsPerDay(count),
      PlanFeatureId.limitDevices => l10n.billingLimitDevices(count),
    };
  }

  /// The four limit lines of a plan, in display order.
  static List<PlanFeature> forLimits(PlanLimits limits) => [
        PlanFeature(PlanFeatureId.limitPets, count: limits.maxPets),
        PlanFeature(PlanFeatureId.limitChatsPerPet, count: limits.maxChatsPerPet),
        PlanFeature(PlanFeatureId.limitQuestionsPerDay, count: limits.dailyQuestions),
        PlanFeature(PlanFeatureId.limitDevices, count: limits.maxDevices),
      ];
}

/// "4,99 €", "£4.99", "$4.99", "A$4.99" or "CHF 4.99": the placeholder price
/// in the chosen variant's currency (the figure is not converted: real prices
/// per country are still to be set).
String formatPlanAmount(double price) => formatAppMoney(price);

/// A subscription tier as shown in the plan comparison: Plus, Pro, Ultra.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.tier,
    required this.displayName,
    required this.monthlyPrice,
    required this.yearlyPrice,
    this.isRecommended = false,
  });

  final PlanTier tier;
  final String displayName;

  /// Placeholder price for one month, billed monthly, in the chosen
  /// variant's currency (see [formatPlanAmount]).
  final double monthlyPrice;

  /// Placeholder price for the whole year, billed yearly: ten months, so the
  /// discount stays within 16.67%.
  final double yearlyPrice;

  /// Highlights the plan with a "Consigliato" badge.
  final bool isRecommended;

  /// Short label shown on the plan card, or null when not highlighted.
  String? get badge => isRecommended ? appL10n.billingPlanBadgeRecommended : null;

  /// What a purchase of this [cycle] costs: one month, or the whole year.
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
