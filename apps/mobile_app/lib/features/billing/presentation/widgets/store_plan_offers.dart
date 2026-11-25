import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/regional_defaults.dart';
import '../../data/billing_demo_store.dart';
import '../../domain/billing_models.dart';
import '../../domain/renewal_terms.dart';
import '../../domain/store_subscription.dart';
import 'plan_feature_list.dart';

/// The plans the store sells, with the automatic renewal declared where the
/// owner pays (owner decision 2026-11-25): price, period and date right above
/// the button, how to cancel and who handles the payment once, under the plans.
/// Values only: it knows no store and buys nothing by itself.
class StorePlanOffers extends StatelessWidget {
  const StorePlanOffers({
    super.key,
    required this.cycle,
    required this.onCycleChanged,
    required this.priceFor,
    required this.featuresFor,
    required this.current,
    required this.storeName,
    required this.busy,
    required this.onBuy,
    this.today,
  });

  final BillingCycle cycle;
  final ValueChanged<BillingCycle> onCycleChanged;

  /// The store's own price text; null = the store does not sell that plan here.
  final String? Function(PlanTier tier) priceFor;
  final List<PlanFeature> Function(PlanTier tier) featuresFor;

  /// The verified store subscription of the account, if any.
  final StoreSubscription? current;

  /// «Apple» or «Google»: who handles the payment and the renewal.
  final String storeName;
  final bool busy;
  final ValueChanged<PlanTier> onBuy;

  /// The day of the purchase, for the date of the first renewal (tests).
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasPlan = current?.grantsAccess ?? false;
    // Whoever already pays a plan and moves to another one keeps the days already paid: the
    // date of the next charge is worked out by the store, so none is written here.
    final changing = hasPlan && (current?.isFromStore ?? false);
    final date = formatAppDate(
      firstRenewalDate(today ?? DateTime.now(), cycle),
      appNumericDatePattern(l10n.settingsNumericDatePattern),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<BillingCycle>(
          segments: [
            ButtonSegment(value: BillingCycle.monthly, label: Text(l10n.billingCycleMonthly)),
            ButtonSegment(value: BillingCycle.yearly, label: Text(l10n.billingCycleYearly)),
          ],
          selected: {cycle},
          onSelectionChanged: (value) => onCycleChanged(value.first),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final plan in BillingDemoStore.plans)
          if (priceFor(plan.tier) case final price?) ...[
            _StorePlanCard(
              key: ValueKey('store-plan-${plan.tier.name}'),
              name: plan.displayName,
              priceLine: cycle == BillingCycle.yearly
                  ? l10n.storeBillingSubscribeYearly(price)
                  : l10n.storeBillingSubscribeMonthly(price),
              renewal: changing
                  ? null
                  : renewalSentence(l10n, cycle: cycle, price: price, date: date),
              isCurrent: hasPlan && current?.plan == plan.tier.name,
              busy: busy,
              features: featuresFor(plan.tier),
              onBuy: () => onBuy(plan.tier),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        Text(
          l10n.renewCancelLine(storeName),
          key: const ValueKey('renewal-cancel-line'),
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.storeBillingPricesFromStore, style: AppTextStyles.caption),
      ],
    );
  }
}

class _StorePlanCard extends StatelessWidget {
  const _StorePlanCard({
    super.key,
    required this.name,
    required this.priceLine,
    required this.renewal,
    required this.isCurrent,
    required this.busy,
    required this.features,
    required this.onBuy,
  });

  final String name;

  /// «Annuale · 85,99 €»: only where [renewal] is not shown.
  final String priceLine;

  /// The whole declaration of the renewal; null when the date is the store's to say.
  final String? renewal;
  final bool isCurrent;
  final bool busy;
  final List<PlanFeature> features;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final renewal = isCurrent ? null : this.renewal;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: isCurrent ? AppColors.primary : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: AppTextStyles.title),
          if (renewal == null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(priceLine, style: AppTextStyles.body),
          ],
          if (features.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            PlanFeatureList(features: features),
          ],
          const SizedBox(height: AppSpacing.md),
          if (isCurrent)
            Text(context.l10n.billingCurrentPlanLabel, style: AppTextStyles.caption)
          else ...[
            if (renewal != null) ...[
              Text(renewal, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.sm),
            ],
            FilledButton(
              onPressed: busy ? null : onBuy,
              child: Text(context.l10n.subscribeButton, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }
}
