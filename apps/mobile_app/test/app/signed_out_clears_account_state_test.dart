import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/billing/data/billing_demo_store.dart';
import 'package:vet_app_mobile/features/billing/data/subscription_remote_data_source.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/billing/domain/subscription_status.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

class _OneStatus implements SubscriptionRemoteDataSource {
  _OneStatus(this.status);

  final SubscriptionStatus status;

  @override
  Future<Result<SubscriptionStatus>> fetchStatus() async => Result.success(status);

  @override
  Future<Result<SubscriptionStatus>> selectPlan(PlanTier plan) async =>
      Result.failure(const AppNetworkError(code: 'no', message: 'no'));
}

/// Project rule: every in-memory store that holds an account's data is
/// emptied when that account signs out, so the next one on the same device
/// starts clean (CLAUDE.md, "Sicurezza e protezione dati").
void main() {
  test('the sign-out handler empties every account store', () {
    final source = File('lib/app/bootstrap.dart').readAsStringSync();
    final handler = source.substring(
      source.indexOf('AuthChangeEvent.signedOut'),
      source.indexOf('AuthChangeEvent.signedIn'),
    );
    for (final reset in [
      'PetDemoStore.instance.reset()',
      'MarketplaceUnreadStore.instance.reset()',
      'BillingDemoStore.instance.reset()',
      'OwnerJsonCache.clearAll()',
      'RouteRestoration.instance.forget()',
    ]) {
      expect(handler, contains(reset), reason: reset);
    }
  });

  test('a new account never inherits the previous account\'s plan access', () async {
    final store = BillingDemoStore.instance;
    await store.syncFromBackend(
      dataSource: _OneStatus(
        SubscriptionStatus(
          trialEndsAt: DateTime.now().subtract(const Duration(days: 3)),
          plan: null,
          isDeveloper: false,
          hasAccess: false,
        ),
      ),
    );
    expect(store.hasAccess, isFalse);

    store.reset();

    expect(store.hasLoadedStatus, isFalse);
    expect(store.hasAccess, isTrue, reason: 'unknown until the gate asks the backend');
    expect(store.currentTier, isNull);
  });
}
