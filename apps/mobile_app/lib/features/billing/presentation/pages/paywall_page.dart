import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../data/billing_demo_store.dart';
import '../../data/subscription_remote_data_source.dart';
import '../../domain/billing_models.dart';

/// Blocking screen shown when the free trial has ended and no plan has
/// been chosen (packages/core/domain/subscription/models.py:
/// Subscription.has_access). No back button, no bottom nav — reached
/// directly from SubscriptionGate, replacing the whole navigation stack.
class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  final _dataSource = HttpSubscriptionRemoteDataSource();
  PlanTier? _selecting;

  Future<void> _selectPlan(PlanTier tier) async {
    if (_selecting != null) return;
    setState(() => _selecting = tier);
    final result = await _dataSource.selectPlan(tier);
    if (!mounted) return;
    setState(() => _selecting = null);
    result.fold(
      onSuccess: (_) {
        BillingDemoStore.instance.switchToPlan(tier);
        Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.homeShell, (route) => false);
      },
      onFailure: (error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            children: [
              Text('La tua prova gratuita è terminata.', style: AppTextStyles.display.copyWith(fontSize: 26)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Scegli un piano per continuare a usare VetApp. Puoi cambiare piano in qualsiasi momento da Impostazioni.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final plan in BillingDemoStore.plans) ...[
                _PaywallPlanCard(
                  plan: plan,
                  isLoading: _selecting == plan.tier,
                  onSelect: () => _selectPlan(plan.tier),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaywallPlanCard extends StatelessWidget {
  const _PaywallPlanCard({
    required this.plan,
    required this.isLoading,
    required this.onSelect,
  });

  final SubscriptionPlan plan;
  final bool isLoading;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final price = plan.priceFor(BillingCycle.monthly);
    final priceLabel = price == 0
        ? 'Gratis'
        : '${NumberFormat.currency(locale: 'it_IT', symbol: '€').format(price)}/mese';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.border),
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
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(plan.badge!, style: AppTextStyles.caption.copyWith(color: AppColors.accent)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(priceLabel, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.md),
          for (final feature in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_rounded, size: 18, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(feature, style: AppTextStyles.bodySmall)),
                ],
              ),
            ),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Scegli ${plan.displayName}'),
            ),
          ),
        ],
      ),
    );
  }
}
