import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../territory/domain/territory.dart';

/// The Mercatino search radius the owner chose, kept on the phone so it
/// survives restarts. Always whole kilometres (1-300), whatever unit is
/// shown; a missing, unreadable or out-of-range stored value is the default.
class ListingRadiusStore extends ChangeNotifier {
  ListingRadiusStore._();

  static final ListingRadiusStore instance = ListingRadiusStore._();

  static const _storageKey = 'vet_app.marketplace_radius_km';

  double _radiusKm = defaultMarketplaceRadiusKm();
  double get radiusKm => _radiusKm;

  Future<void>? _loading;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final stored = (await SharedPreferences.getInstance()).getInt(_storageKey);
      if (stored != null && stored >= marketplaceMinRadiusKm && stored <= marketplaceMaxRadiusKm) {
        _radiusKm = stored.toDouble();
        notifyListeners();
      }
    } catch (_) {
      // Storage unavailable: the default radius is a fine answer.
    }
  }

  Future<void> save(double km) async {
    _radiusKm = clampMarketplaceRadiusKm(km).roundToDouble();
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setInt(_storageKey, _radiusKm.round());
    } catch (_) {
      // Kept for this session at least.
    }
  }

  /// Test hook: forget the loaded value so the next [ensureLoaded] re-reads.
  @visibleForTesting
  void resetForTest() {
    _radiusKm = defaultMarketplaceRadiusKm();
    _loading = null;
  }
}
