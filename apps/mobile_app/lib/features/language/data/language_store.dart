import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../../settings/data/unit_settings_store.dart';
import '../../settings/domain/unit_system.dart';
import '../domain/app_language.dart';
import 'account_language_store.dart';

/// The language (and country) the app is shown in, saved on the phone.
///
/// A [ChangeNotifier] singleton like `UnitSettingsStore`: `VetApp` listens to
/// it to rebuild with the new `Locale`. Until the owner picks a variant the
/// store proposes one from the phone's language; with a single translation
/// available that is always Italian, and nothing is ever shown to the owner.
class LanguageStore extends ChangeNotifier {
  LanguageStore._();

  static final LanguageStore instance = LanguageStore._();

  static const _storageKey = 'vet_app.language_variant';

  /// Variants with a translation. Overridable in tests.
  @visibleForTesting
  static List<AppLanguageVariant> Function() availableOverride =
      () => availableLanguageVariants(AppLocalizations.supportedLocales);

  /// The phone's language. Overridable in tests.
  @visibleForTesting
  static Locale Function() deviceLocale =
      () => PlatformDispatcher.instance.locale;

  List<AppLanguageVariant> get available => availableOverride();

  AppLanguageVariant variantForLanguage(String code) {
    if (_variant.languageCode == code) return _variant;
    return suggestLanguageVariant(
      deviceLocale(),
      available.where((variant) => variant.languageCode == code).toList(),
    );
  }

  /// More than one translation exists: the first-run page and the Settings
  /// section only appear then.
  bool get hasChoice => available.length > 1;

  AppLanguageVariant _variant = allLanguageVariants.first;
  AppLanguageVariant get variant => _variant;
  Locale get locale => _variant.locale;

  bool _chosen = false;

  /// The owner picked a variant (now or in an earlier session).
  bool get hasChosen => _chosen;

  /// The first-run language page is still to be shown.
  bool get needsFirstRunChoice => hasChoice && !_chosen;

  bool _loaded = false;
  bool _explicitInSession = false;
  int _selectionRevision = 0;

  @visibleForTesting
  AccountLanguageStore accountStore = const SupabaseAccountLanguageStore();

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    AppLanguageVariant? stored;
    try {
      final preferences = await SharedPreferences.getInstance();
      stored = languageVariantById(preferences.getString(_storageKey));
    } catch (_) {
      // No readable preference: fall through to the suggestion.
    }
    final options = available;
    final storedId = stored?.id;
    if (stored != null && options.any((v) => v.id == storedId)) {
      _chosen = true;
      await _apply(stored, announce: false);
    } else {
      await _apply(suggestLanguageVariant(deviceLocale(), options),
          announce: false);
    }
  }

  /// The owner's choice: applies immediately, remembers it, and moves the
  /// default measurement units to the variant's country unless the owner
  /// already picked units by hand.
  Future<void> choose(AppLanguageVariant variant) async {
    _explicitInSession = true;
    _selectionRevision++;
    _loaded = true;
    _chosen = true;
    await _apply(variant, announce: true);
    await _persistDevicePreference();
    await _saveAccount();
  }

  /// Session choice > account > saved device choice > device language > IT.
  Future<void> syncAfterAuthentication() async {
    final revision = _selectionRevision;
    if (_explicitInSession) {
      await _saveAccount();
      return;
    }
    try {
      final remote =
          await accountStore.read().timeout(const Duration(seconds: 5));
      if (revision != _selectionRevision) return;
      final exact = languageVariantById(remote);
      final candidates =
          available.where((v) => v.languageCode == remote).toList();
      final variant = exact ?? (candidates.isEmpty ? null : candidates.first);
      if (variant != null && available.any((v) => v.id == variant.id)) {
        await _apply(variant, announce: true);
        await _persistDevicePreference();
        _chosen = true;
      } else {
        await _saveAccount();
      }
    } catch (_) {
      // Keep the device preference during a network failure.
    }
  }

  Future<void> _saveAccount() async {
    try {
      await accountStore
          .write(_variant.languageCode, _variant.id)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // The local preference remains usable while offline.
    }
  }

  Future<void> _persistDevicePreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_storageKey, _variant.id);
      unawaited(_refreshNativeWidget());
    } catch (_) {
      // Preference and widget refresh are best-effort; UI already changed.
    }
  }

  Future<void> _refreshNativeWidget() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await HomeWidget.updateWidget(androidName: 'DogWalksWidgetProvider');
    } catch (_) {
      // No widget installed or native bridge unavailable: no impact on UI.
    }
  }

  void resetSessionChoice() {
    _explicitInSession = false;
    _selectionRevision++;
  }

  Future<void> _apply(AppLanguageVariant variant,
      {required bool announce}) async {
    final changed = variant.id != _variant.id;
    _variant = variant;
    AppLocaleHolder.current = variant.locale;
    try {
      await initializeDateFormatting(appIntlLocale);
    } catch (_) {
      // Date patterns fall back to the default locale data.
    }
    UnitSettingsStore.instance
        .applyLocaleDefault(defaultUnitsForLocale(variant.countryCode));
    if (announce || changed) notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _loaded = false;
    _explicitInSession = false;
    _selectionRevision = 0;
    accountStore = const SupabaseAccountLanguageStore();
    _chosen = false;
    _variant = allLanguageVariants.first;
    AppLocaleHolder.current = _variant.locale;
    availableOverride =
        () => availableLanguageVariants(AppLocalizations.supportedLocales);
    deviceLocale = () => PlatformDispatcher.instance.locale;
  }
}
