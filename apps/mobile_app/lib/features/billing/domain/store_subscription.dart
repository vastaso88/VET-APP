/// Mirrors `StoreSubscriptionView`
/// (packages/core/application/services/get_or_create_subscription.py): the
/// verified store subscription the backend knows for this account.
class StoreSubscription {
  const StoreSubscription({
    required this.store,
    required this.productId,
    required this.plan,
    required this.period,
    required this.state,
    required this.expiresAt,
    required this.autoRenew,
    required this.grantsAccess,
    this.graceExpiresAt,
  });

  factory StoreSubscription.fromJson(Map<String, dynamic> json) => StoreSubscription(
        store: json['store'] as String? ?? '',
        productId: json['product_id'] as String? ?? '',
        plan: json['plan'] as String? ?? '',
        period: json['period'] as String? ?? '',
        state: json['state'] as String? ?? '',
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
        graceExpiresAt: DateTime.tryParse(json['grace_expires_at'] as String? ?? ''),
        autoRenew: json['auto_renew'] as bool? ?? false,
        grantsAccess: json['grants_access'] as bool? ?? false,
      );

  /// `apple`, `google` or `admin_test`.
  final String store;
  final String productId;
  final String plan;
  final String period;

  /// active, canceled, in_grace_period, billing_retry, on_hold, paused,
  /// expired, revoked, refunded, replaced, pending.
  final String state;
  final DateTime? expiresAt;
  final DateTime? graceExpiresAt;
  final bool autoRenew;
  final bool grantsAccess;

  bool get isPaymentIssue =>
      state == 'in_grace_period' || state == 'billing_retry' || state == 'on_hold';
  bool get isRefundedOrRevoked => state == 'refunded' || state == 'revoked';

  /// Bought in a store (a plan given by the team has no store).
  bool get isFromStore => store == 'apple' || store == 'google';

  /// The store will charge it again: the one there is something to cancel. False
  /// once the owner has cancelled (the renewal is off) or the subscription is over.
  bool get renews =>
      isFromStore &&
      autoRenew &&
      const {'active', 'in_grace_period', 'billing_retry', 'on_hold', 'paused'}.contains(state);
}

/// One purchasable product as the app asks the store for it
/// (GET /billing/catalog). Prices are never taken from here.
class StoreCatalogProduct {
  const StoreCatalogProduct({
    required this.plan,
    required this.period,
    required this.appleProductId,
    required this.googleProductId,
    required this.googleBasePlanId,
  });

  factory StoreCatalogProduct.fromJson(Map<String, dynamic> json) => StoreCatalogProduct(
        plan: json['plan'] as String,
        period: json['period'] as String,
        appleProductId: json['apple_product_id'] as String,
        googleProductId: json['google_product_id'] as String,
        googleBasePlanId: json['google_base_plan_id'] as String,
      );

  final String plan;
  final String period;
  final String appleProductId;
  final String googleProductId;
  final String googleBasePlanId;
}
