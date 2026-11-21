import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/regional_defaults.dart';
import '../../../account_consents/domain/account_consent_models.dart';
import '../../../age/presentation/age_flow.dart';
import '../../../auth/presentation/pages/legal_text_page.dart';
import '../../data/billing_demo_store.dart';
import '../../data/store_billing_controller.dart';
import '../../domain/billing_models.dart';
import 'plan_feature_list.dart';

/// Native subscriptions in the billing page and the paywall: status (trial,
/// verified plan, renewal, cancellation, payment issue), store prices for
/// monthly/yearly, purchase, restore and a link to the store's own
/// subscription management. Shown only in the Android/iOS apps.
class StoreSubscriptionSection extends StatefulWidget {
  const StoreSubscriptionSection({super.key, this.onAccessGranted});

  /// Called once a verified purchase gave the account access (paywall).
  final VoidCallback? onAccessGranted;

  @override
  State<StoreSubscriptionSection> createState() => _StoreSubscriptionSectionState();
}

class _StoreSubscriptionSectionState extends State<StoreSubscriptionSection> {
  final _billing = StoreBillingController.instance;
  final _store = BillingDemoStore.instance;
  StorePurchasePhase _lastPhase = StorePurchasePhase.idle;

  @override
  void initState() {
    super.initState();
    unawaited(_billing.initialize());
    _billing.addListener(_onPhase);
  }

  @override
  void dispose() {
    _billing.removeListener(_onPhase);
    super.dispose();
  }

  void _onPhase() {
    final phase = _billing.phase;
    if (phase == _lastPhase || !mounted) return;
    _lastPhase = phase;
    final l10n = context.l10n;
    final message = switch (phase) {
      StorePurchasePhase.pending => l10n.storeBillingPending,
      StorePurchasePhase.verified => l10n.storeBillingVerified,
      StorePurchasePhase.failed => l10n.storeBillingFailed,
      StorePurchasePhase.ownedByOther => l10n.storeBillingOwnedByOther,
      _ => null,
    };
    if (phase == StorePurchasePhase.verified && _store.hasAccess) {
      widget.onAccessGranted?.call();
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _buy(PlanTier tier) async {
    // A paid plan needs a declared age (and a parent's OK for a minor).
    if (!await ensureCanChoosePaidPlan(context) || !mounted) return;
    await _billing.buy(tier, _store.billingCycle);
  }

  String _date(BuildContext context, DateTime date) =>
      formatAppDate(date.toLocal(), appNumericDatePattern(context.l10n.settingsNumericDatePattern));

  void _openLegal(String consentKey, String title) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LegalTextPage(consentKey: consentKey, title: title, shareable: true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!StoreBillingController.platformSupported) return const SizedBox.shrink();
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge([_billing, _store]),
      builder: (context, _) {
        final verified = _store.storeSubscription;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_store.isOnTrial)
              _StatusLine(
                icon: Icons.spa_outlined,
                text: l10n.storeBillingTrialDaysLeft('${_store.trialDaysLeft}'),
              ),
            if (verified != null) ...[
              if (verified.isPaymentIssue)
                _StatusLine(icon: Icons.error_outline, text: l10n.storeBillingPaymentIssue)
              else if (verified.isRefundedOrRevoked)
                _StatusLine(icon: Icons.block_outlined, text: l10n.storeBillingRefunded)
              else if (!verified.grantsAccess)
                _StatusLine(icon: Icons.event_busy_outlined, text: l10n.storeBillingExpired)
              else if (!verified.autoRenew && verified.expiresAt != null)
                _StatusLine(
                  icon: Icons.event_outlined,
                  text: l10n.storeBillingCanceledUntil(_date(context, verified.expiresAt!)),
                )
              else if (verified.expiresAt != null)
                _StatusLine(
                  icon: Icons.autorenew,
                  text: l10n.billingRenewalOn(_date(context, verified.expiresAt!)),
                ),
            ],
            if (!_billing.isAvailable)
              _StatusLine(icon: Icons.info_outline, text: l10n.storeBillingUnavailable)
            else ...[
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<BillingCycle>(
                segments: [
                  ButtonSegment(value: BillingCycle.monthly, label: Text(l10n.billingCycleMonthly)),
                  ButtonSegment(value: BillingCycle.yearly, label: Text(l10n.billingCycleYearly)),
                ],
                selected: {_store.billingCycle},
                onSelectionChanged: (value) => _store.setBillingCycle(value.first),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final plan in BillingDemoStore.plans)
                if (_billing.priceFor(plan.tier, _store.billingCycle) case final price?) ...[
                  _StorePlanCard(
                    name: plan.displayName,
                    price: _store.billingCycle == BillingCycle.yearly
                        ? l10n.storeBillingSubscribeYearly(price)
                        : l10n.storeBillingSubscribeMonthly(price),
                    isCurrent: verified?.grantsAccess == true && verified?.plan == plan.tier.name,
                    busy: _billing.isBusy,
                    features: _store.limitFeaturesFor(plan.tier),
                    onBuy: () => _buy(plan.tier),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              Text(l10n.storeBillingPricesFromStore, style: AppTextStyles.caption),
            ],
            if (_billing.phase == StorePurchasePhase.verifying)
              _StatusLine(icon: Icons.hourglass_top, text: l10n.storeBillingVerifying),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: _billing.isBusy ? null : () => unawaited(_billing.restore()),
              icon: const Icon(Icons.restore),
              label: Text(l10n.storeBillingRestore),
            ),
            TextButton.icon(
              onPressed: () => unawaited(_billing.openManagement(verified)),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.storeBillingManage),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _openLegal(
                    AccountConsentKeys.termsOfService, l10n.authTermsOfServiceLabel,
                  ),
                  child: Text(l10n.authTermsOfServiceLabel),
                ),
                TextButton(
                  onPressed: () => _openLegal(
                    AccountConsentKeys.privacyPolicy, l10n.authPrivacyPolicyLabel,
                  ),
                  child: Text(l10n.authPrivacyPolicyLabel),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.secondaryText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}

class _StorePlanCard extends StatelessWidget {
  const _StorePlanCard({
    required this.name,
    required this.price,
    required this.isCurrent,
    required this.busy,
    required this.features,
    required this.onBuy,
  });

  final String name;
  final String price;
  final bool isCurrent;
  final bool busy;
  final List<PlanFeature> features;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: AppSpacing.xs),
          Text(price, style: AppTextStyles.body),
          if (features.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            PlanFeatureList(features: features),
          ],
          const SizedBox(height: AppSpacing.md),
          if (isCurrent)
            Text(context.l10n.billingCurrentPlanLabel, style: AppTextStyles.caption)
          else
            FilledButton(
              onPressed: busy ? null : onBuy,
              child: Text(name),
            ),
        ],
      ),
    );
  }
}
