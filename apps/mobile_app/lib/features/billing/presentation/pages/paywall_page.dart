import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/pet_loader.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../account/presentation/pages/delete_account_page.dart';
import '../../../account/presentation/pages/export_data_page.dart';
import '../../../marketplace/presentation/pages/marketplace_page.dart';
import '../../data/billing_demo_store.dart';
import '../../data/subscription_remote_data_source.dart';
import '../../domain/billing_models.dart';
import '../widgets/plan_feature_list.dart';

/// Blocking screen shown when the free trial has ended and no plan has
/// been chosen (packages/core/domain/subscription/models.py:
/// Subscription.has_access). No back button, no bottom nav — reached
/// directly from SubscriptionGate, replacing the whole navigation stack.
///
/// Without a plan the owner still reaches their own data: export and account
/// deletion are always possible, and the emergency guidance stays visible.
class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  final _dataSource = HttpSubscriptionRemoteDataSource();
  final _store = BillingDemoStore.instance;
  PlanTier? _selecting;

  @override
  void initState() {
    super.initState();
    unawaited(_store.syncFromBackend(dataSource: _dataSource));
  }

  Future<void> _selectPlan(PlanTier tier) async {
    if (_selecting != null) return;
    setState(() => _selecting = tier);
    final result = await _dataSource.selectPlan(tier);
    if (!mounted) return;
    setState(() => _selecting = null);
    result.fold(
      onSuccess: (_) {
        _store.switchToPlan(tier);
        Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.homeShell, (route) => false);
      },
      onFailure: (error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _store,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xxxl,
              ),
              children: [
                Text(
                  context.l10n.billingPaywallTitle,
                  style: AppTextStyles.display.copyWith(fontSize: 26),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(context.l10n.billingPaywallSubtitle, style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.lg),
                const IncludedInAllPlansCard(),
                const SizedBox(height: AppSpacing.xl),
                for (final plan in BillingDemoStore.plans) ...[
                  _PaywallPlanCard(
                    plan: plan,
                    features: _store.limitFeaturesFor(plan.tier),
                    isLoading: _selecting == plan.tier,
                    onSelect: () => _selectPlan(plan.tier),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                const SizedBox(height: AppSpacing.lg),
                _DataActionRow(
                  icon: Icons.storefront_outlined,
                  label: context.l10n.billingPaywallBrowseMarketplace,
                  onTap: () => _open(const MarketplacePage()),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(context.l10n.billingPaywallDataTitle,
                    style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.xs),
                Text(context.l10n.billingPaywallDataBody, style: AppTextStyles.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                _DataActionRow(
                  icon: Icons.download_outlined,
                  label: context.l10n.settingsAccountExport,
                  onTap: () => _open(const ExportDataPage()),
                ),
                _DataActionRow(
                  icon: Icons.delete_outline_rounded,
                  label: context.l10n.settingsAccountDelete,
                  color: AppColors.danger,
                  onTap: () => _open(const DeleteAccountPage()),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _EmergencyNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DataActionRow extends StatelessWidget {
  const _DataActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.text,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fixed guidance, no model involved: someone whose animal is in danger
/// must find it here even with no plan.
class _EmergencyNote extends StatelessWidget {
  const _EmergencyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_hospital_outlined, color: AppColors.danger, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.billingPaywallEmergencyTitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(context.l10n.billingPaywallEmergencyBody, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaywallPlanCard extends StatelessWidget {
  const _PaywallPlanCard({
    required this.plan,
    required this.features,
    required this.isLoading,
    required this.onSelect,
  });

  final SubscriptionPlan plan;
  final List<PlanFeature> features;
  final bool isLoading;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final priceLabel =
        '${l10n.billingPricePerYear(formatPlanAmount(plan.priceFor(BillingCycle.yearly)))}'
        ' · ${l10n.billingPricePerMonth(formatPlanAmount(plan.priceFor(BillingCycle.monthly)))}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(
          color: plan.badge != null ? AppColors.primary : AppColors.border,
          width: plan.badge != null ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(plan.displayName, style: AppTextStyles.title.copyWith(fontSize: 18)),
              if (plan.badge != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondarySoft,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(plan.badge!, style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(priceLabel, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.md),
          PlanFeatureList(features: features),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : onSelect,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: PetLoader.small(),
                    )
                  : Text(l10n.billingChoosePlan(plan.displayName)),
            ),
          ),
        ],
      ),
    );
  }
}
