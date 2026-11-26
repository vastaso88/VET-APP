import 'package:flutter/material.dart';

/// Every colour of the app lives here and nowhere else (a test fails when a
/// page writes `Color(0x...)` or `Colors.white` itself), arranged by the 60/30/10
/// rule of colour:
///
/// * 60% NEUTRAL - the warm paper the screens are made of: [background],
///   [surface], [surfaceElevated], their borders and the three text greys.
/// * 30% SECONDARY - sage, the colour of structure: soft panels, chips that are
///   not selected, the navigation indicator, section headers, quiet icons.
/// * 10% ACCENT - petrol teal, only where the owner must act or look: primary
///   buttons, the selected tab or chip, links, focus, the current step.
///
/// Status colours (success, warning, danger, info), the colours that tell the
/// radar categories apart and the colour a pet picks for itself are not part of
/// the 60/30/10: they carry meaning and keep their own hue. Over photos, maps
/// and video the `onMedia`/`scrim` family is used instead of black and white.
/// Contrast is checked by scripts/design/contrast_check.py (WCAG AA).
///
/// The app follows the phone's light or dark setting: the colours that change
/// with it are read through [AppColors] from the [AppPalette] in use, never
/// from [AppPalette.light] directly (test/theme/dark_theme_test.dart). The
/// brand ground of the opening screen and the colours over photos and maps are
/// the same in both themes.
class AppColors {
  static AppPalette _palette = AppPalette.light;

  /// The palette in use. Set by the app from the phone's setting
  /// (lib/app/app.dart); every widget is rebuilt when it changes.
  static AppPalette get palette => _palette;

  static bool get isDark => identical(_palette, AppPalette.dark);

  static void use(AppPalette palette) => _palette = palette;

  static AppPalette paletteFor(Brightness brightness) =>
      brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;

  // --- Brand ground of the opening screen (same as the native splash) -----
  // The same in both themes: the quokka is always paper on petrol.
  static const brandDeep = Color(0xFF0E3B47);
  static const brandPaper = Color(0xFFF7F5F0);

  // --- 60% neutral ---------------------------------------------------------
  static Color get background => _palette.background;
  static Color get backgroundDeep => _palette.backgroundDeep;
  static Color get surface => _palette.surface;
  static Color get surfaceElevated => _palette.surfaceElevated;

  /// Hairlines and panels nobody has to find (a separator, a card that is
  /// only read). Never the edge of a field or of something to tap.
  static Color get border => _palette.border;

  /// The edge of what is written in or tapped: fields, pills that are not
  /// chosen, cards that open, outlined buttons. At least 3 to 1 (WCAG 1.4.11)
  /// on every ground of the app, soft panels included.
  static Color get borderStrong => _palette.borderStrong;
  static Color get text => _palette.text;
  static Color get secondaryText => _palette.secondaryText;
  static Color get mutedText => _palette.mutedText;

  // --- 30% secondary: sage -------------------------------------------------
  static Color get secondary => _palette.secondary;
  static Color get secondarySoft => _palette.secondarySoft;
  static Color get secondaryMid => _palette.secondaryMid;
  static Color get secondaryStrong => _palette.secondaryStrong;

  // --- 10% accent: petrol teal --------------------------------------------
  static Color get primary => _palette.primary;
  static Color get primarySoft => _palette.primarySoft;

  /// Text and icons on [primary] and on the full status colours: paper in the
  /// light theme, deep petrol ink in the dark one (where [primary] is light).
  static Color get onPrimary => _palette.onPrimary;

  /// Text and marks on the grounds that invert with the theme (a chart's
  /// tooltip on [primary], a snack bar): white in the light theme, the deep
  /// ink of [onPrimary] in the dark one, where those grounds are light.
  static Color get onInverse => _palette.onInverse;

  // --- status (meaning, outside the 60/30/10) -------------------------------
  static Color get success => _palette.success;
  static Color get successStrong => _palette.successStrong;
  static Color get successSoft => _palette.successSoft;
  static Color get warning => _palette.warning;
  static Color get warningStrong => _palette.warningStrong;
  static Color get warningSoft => _palette.warningSoft;

  /// A mark drawn on a [warning] fill (the "?" of a place not yet confirmed).
  static Color get onWarning => _palette.onWarning;
  static Color get danger => _palette.danger;
  static Color get dangerStrong => _palette.dangerStrong;
  static Color get dangerSoft => _palette.dangerSoft;
  static Color get info => _palette.info;
  static Color get infoStrong => _palette.infoStrong;
  static Color get infoSoft => _palette.infoSoft;

  // --- over photos, maps and video (the same in both themes) ----------------
  static const onMedia = Color(0xFFFFFFFF);
  static const onMediaMuted = Color(0xB3FFFFFF);
  static const onMediaSoft = Color(0x61FFFFFF);
  static const onMediaFaint = Color(0x3DFFFFFF);
  static const onMediaClear = Color(0x00FFFFFF);
  static const mediaBackground = Color(0xFF000000);
  static const scrim = Color(0x8A000000);
  static const scrimSoft = Color(0x59000000);
  static const scrimLight = Color(0x26000000);

  /// What is drawn on the map tiles (markers, routes, the circle of the
  /// search), which stay light in both themes: always the light palette.
  static const map = AppPalette.light;

  // --- shadows ---------------------------------------------------------------
  static Color get shadow => _palette.shadow;
  static Color get shadowSoft => _palette.shadowSoft;
  static Color get shadowStrong => _palette.shadowStrong;
}

/// The colours that change with the theme, one set for the light theme and
/// one for the dark one. Names and roles are those of [AppColors].
@immutable
class AppPalette {
  const AppPalette._({
    required this.brightness,
    required this.background,
    required this.backgroundDeep,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.secondaryText,
    required this.mutedText,
    required this.secondary,
    required this.secondarySoft,
    required this.secondaryMid,
    required this.secondaryStrong,
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.onInverse,
    required this.success,
    required this.successStrong,
    required this.successSoft,
    required this.warning,
    required this.warningStrong,
    required this.warningSoft,
    required this.onWarning,
    required this.danger,
    required this.dangerStrong,
    required this.dangerSoft,
    required this.info,
    required this.infoStrong,
    required this.infoSoft,
    required this.shadow,
    required this.shadowSoft,
    required this.shadowStrong,
  });

  final Brightness brightness;
  final Color background;
  final Color backgroundDeep;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color secondaryText;
  final Color mutedText;
  final Color secondary;
  final Color secondarySoft;
  final Color secondaryMid;
  final Color secondaryStrong;
  final Color primary;
  final Color primarySoft;
  final Color onPrimary;
  final Color onInverse;
  final Color success;
  final Color successStrong;
  final Color successSoft;
  final Color warning;
  final Color warningStrong;
  final Color warningSoft;
  final Color onWarning;
  final Color danger;
  final Color dangerStrong;
  final Color dangerSoft;
  final Color info;
  final Color infoStrong;
  final Color infoSoft;
  final Color shadow;
  final Color shadowSoft;
  final Color shadowStrong;

  /// Warm paper, sage and petrol.
  static const light = AppPalette._(
    brightness: Brightness.light,
    background: Color(0xFFF6F1EA),
    backgroundDeep: Color(0xFFEDE6DC),
    surface: Color(0xFFFCFAF7),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFE6DDD2),
    borderStrong: Color(0xFF648A78),
    text: Color(0xFF213134),
    secondaryText: Color(0xFF52645F),
    mutedText: Color(0xFF5E6E6B),
    secondary: Color(0xFF6E9482),
    secondarySoft: Color(0xFFE4EDE7),
    secondaryMid: Color(0xFFCADBD0),
    secondaryStrong: Color(0xFF35604F),
    primary: Color(0xFF2E686A),
    primarySoft: Color(0xFFDCEBEA),
    onPrimary: Color(0xFFF9F6F0),
    onInverse: Color(0xFFFFFFFF),
    success: Color(0xFF4A8F73),
    successStrong: Color(0xFF2F6F55),
    successSoft: Color(0xFFE2F0EA),
    warning: Color(0xFFB8791C),
    warningStrong: Color(0xFF7A5416),
    warningSoft: Color(0xFFF8EBD4),
    onWarning: Color(0xFF213134),
    danger: Color(0xFFB73E34),
    dangerStrong: Color(0xFF8E2F27),
    dangerSoft: Color(0xFFF8E3DE),
    info: Color(0xFF5C8194),
    infoStrong: Color(0xFF3F6275),
    infoSoft: Color(0xFFE3EDF2),
    shadow: Color(0x1A6D5E4C),
    shadowSoft: Color(0x0F6D5E4C),
    shadowStrong: Color(0x266D5E4C),
  );

  /// Deep petrol night (art director's table, rapporto giro 1 §7): the same
  /// roles, light ink on dark grounds, the accent a light petrol with dark ink.
  static const dark = AppPalette._(
    brightness: Brightness.dark,
    background: Color(0xFF152022),
    backgroundDeep: Color(0xFF101A1C),
    surface: Color(0xFF1C292B),
    surfaceElevated: Color(0xFF243335),
    border: Color(0xFF34474A),
    borderStrong: Color(0xFF728A88),
    text: Color(0xFFF1ECE4),
    secondaryText: Color(0xFFC3CDC8),
    mutedText: Color(0xFFA5B3AE),
    secondary: Color(0xFF8FB5A3),
    secondarySoft: Color(0xFF263A34),
    secondaryMid: Color(0xFF3A554C),
    secondaryStrong: Color(0xFFB5D3C4),
    primary: Color(0xFF7CC0BE),
    primarySoft: Color(0xFF23403F),
    onPrimary: Color(0xFF10282A),
    onInverse: Color(0xFF10282A),
    success: Color(0xFF6CC39C),
    successStrong: Color(0xFFA8DCC2),
    successSoft: Color(0xFF1C3A2E),
    warning: Color(0xFFE0A04A),
    warningStrong: Color(0xFFEFC98A),
    warningSoft: Color(0xFF3D2E17),
    onWarning: Color(0xFF10282A),
    danger: Color(0xFFEE8E84),
    dangerStrong: Color(0xFFF2B0A8),
    dangerSoft: Color(0xFF43241F),
    info: Color(0xFF8DB4C8),
    infoStrong: Color(0xFFB4D2E2),
    infoSoft: Color(0xFF1F3540),
    shadow: Color(0x40000000),
    shadowSoft: Color(0x26000000),
    shadowStrong: Color(0x59000000),
  );
}

/// What tells the kinds of place of the radar ("Vicino a me") apart. They keep
/// their own hues on purpose and stay clear of the accent teal and the sage.
/// The constants are the light-theme values, also used for the markers on the
/// map (light tiles in both themes, white icon on top). On the app's own
/// grounds use [shown]: in the dark theme it gives the same hue, lighter.
class AppCategoryColors {
  static const veterinary = Color(0xFFB3261E);
  static const shop = Color(0xFF8A5A00);
  static const dogPark = Color(0xFF3F8F2A);
  static const shelter = Color(0xFF3949AB);
  static const association = Color(0xFFD2640C);
  static const grooming = Color(0xFF7B4FA3);
  static const hotel = Color(0xFF1F6FA5);
  static const school = Color(0xFF7C7A0B);
  static const petSitting = Color(0xFFAD1457);
  static const breeder = Color(0xFF6D4C41);
  static const other = Color(0xFF546E7A);

  /// Dark-theme value of each category colour: the smallest lift of its
  /// lightness that reaches 3 to 1 on every dark ground (icons, WCAG 1.4.11).
  static final onDark = <Color, Color>{
    veterinary: Color(0xFFE25850),
    shop: Color(0xFFB87800),
    dogPark: Color(0xFF43992D),
    shelter: Color(0xFF7481D1),
    association: Color(0xFFD7660C),
    grooming: Color(0xFF9C77BD),
    hotel: Color(0xFF278CD0),
    school: Color(0xFF8C8A0C),
    petSitting: Color(0xFFEA458D),
    breeder: Color(0xFFA97D6E),
    other: Color(0xFF6C8B9A),
  };

  /// [color] as drawn on the app's grounds in the theme in use.
  static Color shown(Color color) => AppColors.isDark ? onDark[color] ?? color : color;
}

/// The colour a pet gets for itself (avatar ring, calendar dots) and the pale
/// tint of its card. Picked per animal, not part of the app's own palette.
/// The stored value is always one of the constants; [shown] gives the colour
/// to draw in the theme in use.
class AppIdentityColors {
  static const green = Color(0xFF2F9E68);
  static const amber = Color(0xFFD98C3D);
  static const blue = Color(0xFF5B7FD6);
  static const terracotta = Color(0xFFB5563C);
  static const teal = Color(0xFF3D9E9E);
  static const violet = Color(0xFF9B6BD7);
  static const coral = Color(0xFFC94F6D);
  static const olive = Color(0xFF7A8C3D);

  static const palette = <Color>[green, amber, blue, terracotta, teal, violet, coral, olive];

  /// Dark-theme value of the identity colours below 3 to 1 on a dark ground:
  /// the smallest lift of lightness, same hue. The others are kept.
  static final onDark = <Color, Color>{
    blue: Color(0xFF6184D8),
    terracotta: Color(0xFFC76E56),
    violet: Color(0xFF9F71D9),
    coral: Color(0xFFCF637D),
  };

  /// [color] (a pet's stored colour) as drawn in the theme in use.
  static Color shown(Color color) => AppColors.isDark ? onDark[color] ?? color : color;

  static const tintGreen = Color(0xFFE7F2EE);
  static const tintAmber = Color(0xFFF6EADF);
  static const tintYellow = Color(0xFFF5F0D8);
  static const tintBlue = Color(0xFFE3EBF0);
  static const tintOlive = Color(0xFFEDF0DF);
  static const tintTeal = Color(0xFFE1EEEE);
  static const tintViolet = Color(0xFFF1E7F3);
}
