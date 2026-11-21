import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../domain/billing_models.dart';
import '../domain/store_subscription.dart';
import '../domain/subscription_status.dart';
import 'billing_demo_store.dart';

/// What the subscription section shows while a purchase moves along.
enum StorePurchasePhase { idle, purchasing, pending, verifying, verified, failed, ownedByOther }

/// Native subscriptions (Google Play Billing, StoreKit 2) through the
/// official `in_app_purchase` plugin.
///
/// The app never decides a right: every purchase/restore goes to
/// `POST /billing/purchases/verify` and the backend answers with the new
/// access status. The transaction is completed (completePurchase) only when
/// the backend says so; a pending payment is left open, as the stores ask.
class StoreBillingController extends ChangeNotifier {
  StoreBillingController._();

  static final StoreBillingController instance = StoreBillingController._();

  static const _timeout = Duration(seconds: 20);

  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _available = false;
  bool _initialized = false;
  List<StoreCatalogProduct> _catalog = const [];
  final Map<String, ProductDetails> _products = {};
  String? _accountToken;
  StorePurchasePhase _phase = StorePurchasePhase.idle;
  bool _restoring = false;

  /// Store purchases exist only in the Android and iOS apps (not on web).
  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get isAvailable => _available && _products.isNotEmpty;
  StorePurchasePhase get phase => _phase;
  bool get isBusy =>
      _phase == StorePurchasePhase.purchasing || _phase == StorePurchasePhase.verifying;

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  String get _baseUrl => const AppRuntimeConfigLoader().load().apiBaseUrl;

  Map<String, String> get _headers {
    final token = CurrentUser.accessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> initialize() async {
    if (_initialized || !platformSupported) return;
    _initialized = true;
    try {
      final catalogResponse =
          await http.get(Uri.parse('$_baseUrl/billing/catalog'), headers: _headers).timeout(_timeout);
      if (catalogResponse.statusCode != 200) return;
      final body = jsonDecode(catalogResponse.body) as Map<String, dynamic>;
      if (body['enabled'] != true) return;
      _catalog = [
        for (final raw in body['products'] as List<dynamic>)
          StoreCatalogProduct.fromJson(raw as Map<String, dynamic>),
      ];
      final iap = InAppPurchase.instance;
      _iap = iap;
      _available = await iap.isAvailable();
      if (!_available) return;
      _subscription = iap.purchaseStream.listen(_onPurchases, onError: (_) {
        _setPhase(StorePurchasePhase.failed);
      });
      final ids = {
        for (final p in _catalog) _isIos ? p.appleProductId : p.googleProductId,
      };
      final response = await iap.queryProductDetails(ids);
      for (final details in response.productDetails) {
        _products[_productKey(details)] = details;
      }
      notifyListeners();
    } catch (_) {
      _available = false;
    }
  }

  /// Android returns one ProductDetails per base plan/offer; key them by
  /// product + base plan so monthly and yearly stay apart.
  String _productKey(ProductDetails details) {
    if (details is GooglePlayProductDetails) {
      final index = details.subscriptionIndex;
      final offers = details.productDetails.subscriptionOfferDetails;
      final basePlan = (index != null && offers != null) ? offers[index].basePlanId : '';
      // Skip promotional offers: the app trial is ours, store trials are not
      // switched on automatically.
      final offerId = (index != null && offers != null) ? offers[index].offerId : null;
      return offerId == null ? '${details.id}:$basePlan' : '${details.id}:$basePlan:$offerId';
    }
    return details.id;
  }

  StoreCatalogProduct? _catalogFor(PlanTier tier, BillingCycle cycle) {
    final period = cycle == BillingCycle.yearly ? 'yearly' : 'monthly';
    for (final p in _catalog) {
      if (p.plan == tier.name && p.period == period) return p;
    }
    return null;
  }

  ProductDetails? productFor(PlanTier tier, BillingCycle cycle) {
    final entry = _catalogFor(tier, cycle);
    if (entry == null) return null;
    return _isIos
        ? _products[entry.appleProductId]
        : _products['${entry.googleProductId}:${entry.googleBasePlanId}'];
  }

  /// The localized price string from the store (currency, country, taxes).
  String? priceFor(PlanTier tier, BillingCycle cycle) => productFor(tier, cycle)?.price;

  Future<String?> _fetchAccountToken() async {
    if (_accountToken != null) return _accountToken;
    final response = await http
        .get(Uri.parse('$_baseUrl/billing/account-token'), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) return null;
    _accountToken = (jsonDecode(response.body) as Map<String, dynamic>)['account_token'] as String?;
    return _accountToken;
  }

  Future<void> buy(PlanTier tier, BillingCycle cycle) async {
    final iap = _iap;
    final product = productFor(tier, cycle);
    if (iap == null || product == null || isBusy) return;
    _setPhase(StorePurchasePhase.purchasing);
    try {
      final token = await _fetchAccountToken();
      if (token == null) {
        _setPhase(StorePurchasePhase.failed);
        return;
      }
      // The token binds the purchase to this Quokka account on the store
      // side (appAccountToken / obfuscatedAccountId); it is a pseudonym.
      PurchaseParam param = PurchaseParam(productDetails: product, applicationUserName: token);
      if (!_isIos) {
        final old = await _currentAndroidPurchase();
        if (old != null) {
          param = GooglePlayPurchaseParam(
            productDetails: product,
            applicationUserName: token,
            changeSubscriptionParam: ChangeSubscriptionParam(
              oldPurchaseDetails: old,
              replacementMode: ReplacementMode.withTimeProration,
            ),
          );
        }
      }
      final started = await iap.buyNonConsumable(purchaseParam: param);
      if (!started) _setPhase(StorePurchasePhase.idle);
    } catch (_) {
      _setPhase(StorePurchasePhase.failed);
    }
  }

  Future<GooglePlayPurchaseDetails?> _currentAndroidPurchase() async {
    final iap = _iap;
    if (iap == null) return null;
    final addition = iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    for (final purchase in response.pastPurchases) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        return purchase;
      }
    }
    return null;
  }

  Future<void> restore() async {
    final iap = _iap;
    if (iap == null || isBusy) return;
    _restoring = true;
    _setPhase(StorePurchasePhase.verifying);
    try {
      await iap.restorePurchases(applicationUserName: await _fetchAccountToken());
    } catch (_) {
      _setPhase(StorePurchasePhase.failed);
    }
    // Restored purchases arrive on the purchase stream; with none, stop here.
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (_restoring && _phase == StorePurchasePhase.verifying) {
        _restoring = false;
        _setPhase(StorePurchasePhase.idle);
      }
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _setPhase(StorePurchasePhase.pending);
        case PurchaseStatus.canceled:
          _setPhase(StorePurchasePhase.idle);
          if (purchase.pendingCompletePurchase) await _iap?.completePurchase(purchase);
        case PurchaseStatus.error:
          _setPhase(StorePurchasePhase.failed);
          if (purchase.pendingCompletePurchase) await _iap?.completePurchase(purchase);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(purchase);
      }
    }
    _restoring = false;
  }

  Future<void> _verify(PurchaseDetails purchase) async {
    _setPhase(StorePurchasePhase.verifying);
    final storeId = _isIos ? purchase.purchaseID : purchase.verificationData.serverVerificationData;
    if (storeId == null || storeId.isEmpty) {
      _setPhase(StorePurchasePhase.failed);
      return;
    }
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/billing/purchases/verify'),
            headers: _headers,
            body: jsonEncode({
              'store': _isIos ? 'apple' : 'google',
              'store_subscription_id': storeId,
              'product_id': purchase.productID,
            }),
          )
          .timeout(_timeout);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        BillingDemoStore.instance
            .applyStatus(SubscriptionStatus.fromJson(body['status'] as Map<String, dynamic>));
        // Complete only once the backend has recorded it: an uncompleted
        // purchase is redelivered by the store (and refunded by Google after
        // three days without acknowledgement).
        if (body['complete_transaction'] == true && purchase.pendingCompletePurchase) {
          await _iap?.completePurchase(purchase);
        }
        _setPhase(body['complete_transaction'] == true
            ? StorePurchasePhase.verified
            : StorePurchasePhase.pending);
        return;
      }
      _setPhase(body['code'] == 'purchase_owned_by_another_account'
          ? StorePurchasePhase.ownedByOther
          : StorePurchasePhase.failed);
      // A purchase that belongs to someone else is still finished on this
      // device (it is the store's, nothing to retry); a temporary error is not.
      if (response.statusCode == 409 && purchase.pendingCompletePurchase) {
        await _iap?.completePurchase(purchase);
      }
    } catch (_) {
      _setPhase(StorePurchasePhase.failed);
    }
  }

  /// Subscriptions are managed (cancel, change payment) in the store they
  /// were bought from.
  Future<bool> openManagement(StoreSubscription? current) {
    final Uri url;
    if (current?.store == 'apple' || (current == null && _isIos)) {
      url = Uri.parse('https://apps.apple.com/account/subscriptions');
    } else {
      url = Uri.parse('https://play.google.com/store/account/subscriptions');
    }
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _setPhase(StorePurchasePhase phase) {
    _phase = phase;
    notifyListeners();
  }

  /// Sign-out: the next account starts clean (its own account token).
  void reset() {
    _accountToken = null;
    _phase = StorePurchasePhase.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
