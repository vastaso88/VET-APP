import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../pets/data/pet_demo_store.dart';
import '../data/billing_demo_store.dart';
import '../domain/billing_models.dart';

/// Before choosing [tier]: when the owner has more pets than that plan has places
/// for, says so calmly and asks (synthetic users, round 2, 2026-11-16: the change
/// used to go through without a word). Nothing is deleted or moved, only new pets
/// are held back until the owner has fewer than the limit (Terms it/03 §4).
///
/// True when the change can go on: nothing to warn about, or the owner agreed.
/// [petCount] and [store] are for tests; by default the pets on this phone and the
/// limits the backend reported.
Future<bool> confirmPlanFitsPets(
  BuildContext context,
  PlanTier tier, {
  int? petCount,
  BillingDemoStore? store,
}) async {
  final billing = store ?? BillingDemoStore.instance;
  // During a public test nothing changes: no warning for a change that is not made.
  if (billing.isTestPeriod) return true;
  final limit = billing.planLimitsFor(tier)?.maxPets;
  final count = petCount ?? PetDemoStore.instance.list().length;
  if (limit == null || count <= limit) return true;

  final l10n = context.l10n;
  final agreed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('plan-over-pets'),
      content: Text(
        l10n.billingPlanOverPetsWarning(count, limit, BillingDemoStore.planFor(tier).displayName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.billingPlanOverPetsConfirm),
        ),
      ],
    ),
  );
  return agreed ?? false;
}
