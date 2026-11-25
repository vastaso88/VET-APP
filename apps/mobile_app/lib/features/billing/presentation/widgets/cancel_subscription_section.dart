import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../data/billing_demo_store.dart';
import '../../data/store_billing_controller.dart';
import '../../domain/store_subscription.dart';

/// «Disdici l'abbonamento»: always in sight at the top of Impostazioni →
/// Abbonamento e pagamenti while a store subscription renews by itself (owner
/// decision 2026-11-25). Same weight as the button that buys a plan, one tap,
/// no question in between: it opens the store's own page. Nothing at all for
/// an account with no store subscription, or that has already cancelled.
class CancelSubscriptionSection extends StatelessWidget {
  const CancelSubscriptionSection({super.key, this.openStore});

  /// Replaces the store's page in the tests.
  final Future<bool> Function(StoreSubscription subscription)? openStore;

  Future<void> _open(BuildContext context, StoreSubscription subscription) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.billingOpenAccountError;
    var opened = false;
    try {
      opened = await (openStore ?? StoreBillingController.instance.openManagement)(subscription);
    } catch (_) {
      opened = false;
    }
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final store = BillingDemoStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final subscription = store.storeSubscription;
        if (subscription == null || !subscription.renews) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                key: const ValueKey('cancel-subscription'),
                onPressed: () => unawaited(_open(context, subscription)),
                child: Text(context.l10n.cancelButton, textAlign: TextAlign.center),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(context.l10n.cancelButtonNote, style: AppTextStyles.bodySmall),
            ],
          ),
        );
      },
    );
  }
}
