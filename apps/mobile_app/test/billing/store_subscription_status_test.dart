import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/billing/domain/subscription_status.dart';

void main() {
  Map<String, dynamic> body({Map<String, dynamic>? store}) => {
        'subscription': {'trial_ends_at': '2026-01-01T00:00:00Z', 'plan': 'pro'},
        'is_developer': false,
        'has_access': true,
        if (store != null) 'store_subscription': store,
      };

  test('parses the verified store subscription', () {
    final status = SubscriptionStatus.fromJson(body(store: {
      'store': 'apple',
      'product_id': 'net.quokkapet.pro.monthly',
      'plan': 'pro',
      'period': 'monthly',
      'state': 'canceled',
      'expires_at': '2030-01-01T00:00:00Z',
      'auto_renew': false,
      'grants_access': true,
      'last_verified_at': '2026-01-01T00:00:00Z',
    }));
    expect(status.plan, PlanTier.pro);
    expect(status.storeSubscription?.autoRenew, isFalse);
    expect(status.storeSubscription?.expiresAt, DateTime.utc(2030));
  });

  test('a status without a store subscription still parses', () {
    expect(SubscriptionStatus.fromJson(body()).storeSubscription, isNull);
  });

  test('payment issue and refund flags', () {
    final status = SubscriptionStatus.fromJson(body(store: {
      'state': 'in_grace_period',
      'grants_access': true,
    }));
    expect(status.storeSubscription!.isPaymentIssue, isTrue);
    expect(status.storeSubscription!.isRefundedOrRevoked, isFalse);
  });
}
