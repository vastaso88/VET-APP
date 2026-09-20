import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/widgets/coming_soon_page.dart';
import '../../data/billing_demo_store.dart';
import '../../domain/billing_models.dart';

/// "Abbonamento e metodi di pagamento" — reached from Impostazioni.
/// Structured like the subscription/billing screen of most consumer apps:
/// current plan status, a plan comparison, then saved payment methods.
class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final _store = BillingDemoStore.instance;

  void _switchToPlan(PlanTier tier) {
    final plan = BillingDemoStore.plans.firstWhere((p) => p.tier == tier);
    _store.switchToPlan(tier);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ora sei sul piano ${plan.displayName}.')),
    );
  }

  void _openPaymentHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ComingSoonPage(
          title: 'Cronologia pagamenti',
          icon: Icons.receipt_long_outlined,
          description: 'Le tue fatture e ricevute saranno consultabili qui.',
        ),
      ),
    );
  }

  Future<void> _addPaymentMethod() async {
    final method = await showDialog<PaymentMethod>(
      context: context,
      builder: (_) => const _AddPaymentMethodDialog(),
    );
    if (method != null) {
      _store.addPaymentMethod(method);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Abbonamento e pagamenti', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxxl,
              ),
              children: [
                _CurrentPlanCard(store: _store),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel('Confronta i piani'),
                _BillingCycleToggle(store: _store),
                const SizedBox(height: AppSpacing.md),
                for (final plan in BillingDemoStore.plans) ...[
                  _PlanCard(
                    plan: plan,
                    cycle: _store.billingCycle,
                    isCurrent: plan.tier == _store.currentTier,
                    onSelect: () => _switchToPlan(plan.tier),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                const _SectionLabel('Metodi di pagamento'),
                for (final method in _store.paymentMethods)
                  _PaymentMethodTile(
                    method: method,
                    onSetDefault: () => _store.setDefaultPaymentMethod(method.id),
                    onRemove: () => _store.removePaymentMethod(method.id),
                  ),
                _AddPaymentMethodRow(onTap: _addPaymentMethod),
                const _SectionLabel('Fatturazione'),
                _Row(
                  icon: Icons.receipt_long_outlined,
                  iconColor: AppColors.mutedText,
                  title: 'Cronologia pagamenti',
                  onTap: _openPaymentHistory,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _priceLabel(SubscriptionPlan plan, BillingCycle cycle) {
  final price = plan.priceFor(cycle);
  if (price == 0) return 'Gratis';
  final amount = NumberFormat.currency(locale: 'it_IT', symbol: '€').format(price);
  return cycle == BillingCycle.yearly ? '$amount/mese, fatturato annualmente' : '$amount/mese';
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.store});

  final BillingDemoStore store;

  @override
  Widget build(BuildContext context) {
    final plan = store.currentPlan;
    final renewal = store.renewalDate;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryStrong,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Il tuo piano',
                  style: AppTextStyles.caption.copyWith(color: AppColors.onPrimary.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 4),
                Text(
                  plan.displayName,
                  style: AppTextStyles.title.copyWith(color: AppColors.onPrimary),
                ),
                if (renewal != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Rinnovo il ${DateFormat('dd/MM/yyyy').format(renewal)}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.onPrimary.withValues(alpha: 0.85)),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            plan.tier == PlanTier.free ? Icons.spa_outlined : Icons.workspace_premium_outlined,
            color: AppColors.onPrimary,
            size: 32,
          ),
        ],
      ),
    );
  }
}

class _BillingCycleToggle extends StatelessWidget {
  const _BillingCycleToggle({required this.store});

  final BillingDemoStore store;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CyclePill(
            label: 'Mensile',
            selected: store.billingCycle == BillingCycle.monthly,
            onTap: () => store.setBillingCycle(BillingCycle.monthly),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _CyclePill(
            label: 'Annuale',
            selected: store.billingCycle == BillingCycle.yearly,
            onTap: () => store.setBillingCycle(BillingCycle.yearly),
          ),
        ),
      ],
    );
  }
}

class _CyclePill extends StatelessWidget {
  const _CyclePill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.cycle,
    required this.isCurrent,
    required this.onSelect,
  });

  final SubscriptionPlan plan;
  final BillingCycle cycle;
  final bool isCurrent;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: isCurrent ? AppColors.primary : AppColors.border, width: isCurrent ? 2 : 1),
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
                  child: Text(
                    plan.badge!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.accent),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(_priceLabel(plan, cycle), style: AppTextStyles.bodySmall),
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
            child: isCurrent
                ? OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      disabledForegroundColor: AppColors.mutedText,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
                    ),
                    child: const Text('Piano attuale'),
                  )
                : FilledButton(
                    onPressed: onSelect,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
                    ),
                    child: Text(plan.tier == PlanTier.free ? 'Torna a Free' : 'Passa a ${plan.displayName}'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.onSetDefault,
    required this.onRemove,
  });

  final PaymentMethod method;
  final VoidCallback onSetDefault;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: const Icon(Icons.credit_card_outlined, size: 18, color: AppColors.info),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${method.brandLabel} •••• ${method.last4}',
                  style: AppTextStyles.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  method.isDefault ? 'Scade ${method.expiryLabel} · Predefinita' : 'Scade ${method.expiryLabel}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.mutedText),
            onSelected: (value) => value == 'default' ? onSetDefault() : onRemove(),
            itemBuilder: (context) => [
              if (!method.isDefault)
                const PopupMenuItem(value: 'default', child: Text('Imposta come predefinita')),
              const PopupMenuItem(value: 'remove', child: Text('Rimuovi')),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddPaymentMethodRow extends StatelessWidget {
  const _AddPaymentMethodRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Row(
      icon: Icons.add_circle_outline_rounded,
      iconColor: AppColors.primary,
      title: 'Aggiungi metodo di pagamento',
      onTap: onTap,
    );
  }
}

class _AddPaymentMethodDialog extends StatefulWidget {
  const _AddPaymentMethodDialog();

  @override
  State<_AddPaymentMethodDialog> createState() => _AddPaymentMethodDialogState();
}

class _AddPaymentMethodDialogState extends State<_AddPaymentMethodDialog> {
  final _formKey = GlobalKey<FormState>();
  final _last4Controller = TextEditingController();
  CardBrand _brand = CardBrand.visa;
  int _expiryMonth = DateTime.now().month;
  int _expiryYear = DateTime.now().year + 1;

  @override
  void dispose() {
    _last4Controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      PaymentMethod(
        id: 'pm_${DateTime.now().microsecondsSinceEpoch}',
        brand: _brand,
        last4: _last4Controller.text,
        expiryMonth: _expiryMonth,
        expiryYear: _expiryYear,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
      title: Text('Aggiungi metodo di pagamento', style: AppTextStyles.title.copyWith(fontSize: 17)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<CardBrand>(
              initialValue: _brand,
              decoration: const InputDecoration(labelText: 'Circuito'),
              items: CardBrand.values
                  .map((brand) => DropdownMenuItem(
                        value: brand,
                        child: Text(PaymentMethod(
                          id: '',
                          brand: brand,
                          last4: '',
                          expiryMonth: 1,
                          expiryYear: 2000,
                        ).brandLabel),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _brand = value ?? _brand),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _last4Controller,
              decoration: const InputDecoration(labelText: 'Ultime 4 cifre'),
              keyboardType: TextInputType.number,
              maxLength: 4,
              validator: (value) =>
                  (value == null || value.length != 4) ? 'Inserisci 4 cifre' : null,
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _expiryMonth,
                    decoration: const InputDecoration(labelText: 'Mese'),
                    items: [
                      for (var month = 1; month <= 12; month++)
                        DropdownMenuItem(value: month, child: Text(month.toString().padLeft(2, '0'))),
                    ],
                    onChanged: (value) => setState(() => _expiryMonth = value ?? _expiryMonth),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _expiryYear,
                    decoration: const InputDecoration(labelText: 'Anno'),
                    items: [
                      for (var year = DateTime.now().year; year <= DateTime.now().year + 10; year++)
                        DropdownMenuItem(value: year, child: Text('$year')),
                    ],
                    onChanged: (value) => setState(() => _expiryYear = value ?? _expiryYear),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        TextButton(onPressed: _submit, child: const Text('Aggiungi')),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.caption.copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback? onTap;

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
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
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
