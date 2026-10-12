import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// The language the app is currently showing, readable without a
/// [BuildContext]. Kept in sync by `LanguageStore` (the owner's choice);
/// code that has a context should prefer `context.l10n`.
class AppLocaleHolder {
  AppLocaleHolder._();

  static Locale current = const Locale('it');
}

/// Strings for code that has no [BuildContext] (domain labels, notifications,
/// repositories). Falls back to Italian, the source language.
AppLocalizations get appL10n {
  final locale = Locale(AppLocaleHolder.current.languageCode);
  if (AppLocalizations.supportedLocales.contains(locale)) {
    return lookupAppLocalizations(locale);
  }
  return lookupAppLocalizations(const Locale('it'));
}

extension AppL10nContext on BuildContext {
  /// `context.l10n.settingsTitle`. Falls back to [appL10n] when the widget
  /// tree has no localization delegates (plain `MaterialApp` in tests).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ?? appL10n;
}
