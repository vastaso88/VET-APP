import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/growth_reference.dart';

/// Loads the growth bands shipped with the app, and remembers, on this device
/// only, the adult size class the owner chose for each dog (the profile has
/// no field for the expected adult weight, and nothing is sent anywhere).
class GrowthReferenceRepository {
  GrowthReferenceRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const puppyAsset = 'assets/growth/puppy_growth_bands.json';
  static const kittenAsset = 'assets/growth/kitten_growth_bands.json';

  static GrowthBands? _cached;

  static void resetForTest() => _cached = null;

  Future<GrowthBands?> loadBands() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final bands = GrowthBands.fromJson(
        await _bundle.loadString(puppyAsset, cache: false),
        await _bundle.loadString(kittenAsset, cache: false),
      );
      return _cached = bands;
    } catch (_) {
      // No bands: the chart simply has no reference.
      return null;
    }
  }

  static String _key(String petId) => 'growth_adult_size_class_$petId';

  Future<AdultSizeClass?> loadSizeClass(String petId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return AdultSizeClass.fromCode(preferences.getString(_key(petId)));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSizeClass(String petId, AdultSizeClass? sizeClass) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (sizeClass == null) {
        await preferences.remove(_key(petId));
      } else {
        await preferences.setString(_key(petId), sizeClass.code);
      }
    } catch (_) {
      // Not saved: the choice only lasts for this visit to the page.
    }
  }
}
