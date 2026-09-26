import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../billing/data/billing_demo_store.dart';
import '../../../billing/data/subscription_remote_data_source.dart';
import '../../../billing/domain/billing_models.dart';

/// First screen after signup: proposes the 10-day free trial (already
/// started server-side by the time this shows — see register_page.dart)
/// or an immediate plan choice. Pops when the owner is ready to continue,
/// same "push and await" pattern as the other first-run pages.
class PlanIntroPage extends StatefulWidget {
  const PlanIntroPage({super.key});

  @override
  State<PlanIntroPage> createState() => _PlanIntroPageState();
}

class _PlanIntroPageState extends State<PlanIntroPage> {
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
        Navigator.of(context).pop();
      },
      onFailure: (error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            Text('Benvenuto in VetApp.', style: AppTextStyles.display.copyWith(fontSize: 26)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Scegli come iniziare: puoi provare tutto gratis per 10 giorni, senza carta, '
              'oppure scegliere subito un piano.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.xl),
            _TrialCard(
              isLoading: _selecting != null,
              onStart: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'OPPURE SCEGLI SUBITO UN PIANO',
              style: AppTextStyles.caption.copyWith(letterSpacing: 0.8),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final plan in BillingDemoStore.plans) ...[
              _CompactPlanCard(
                plan: plan,
                isLoading: _selecting == plan.tier,
                onSelect: () => _selectPlan(plan.tier),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrialCard extends StatelessWidget {
  const _TrialCard({required this.isLoading, required this.onStart});

  final bool isLoading;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryStrong,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.celebration_outlined, color: AppColors.onPrimary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Prova gratuita — 10 giorni',
                style: AppTextStyles.title.copyWith(color: AppColors.onPrimary, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nessuna carta richiesta. Alla scadenza dei 10 giorni ti chiederemo di '
            'scegliere un piano per continuare.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onPrimary.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : onStart,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.onPrimary,
                foregroundColor: AppColors.primaryStrong,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
              ),
              child: const Text('Inizia la prova gratuita'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactPlanCard extends StatelessWidget {
  const _CompactPlanCard({
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.displayName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                Text(priceLabel, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: isLoading ? null : onSelect,
            style: OutlinedButton.styleFrom(
              // The app-wide OutlinedButtonTheme defaults to a full-width
              // minimumSize (Size.fromHeight) — override it here since this
              // button sits inline in a Row, not full-width.
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Scegli'),
          ),
        ],
      ),
    );
  }
}
