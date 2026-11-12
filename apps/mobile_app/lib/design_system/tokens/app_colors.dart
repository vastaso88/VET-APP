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
class AppColors {
  // --- 60% neutral ---------------------------------------------------------
  static const background = Color(0xFFF6F1EA);
  static const backgroundDeep = Color(0xFFEDE6DC);
  static const surface = Color(0xFFFCFAF7);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const border = Color(0xFFE6DDD2);
  static const borderStrong = Color(0xFFD8CCBF);
  static const text = Color(0xFF213134);
  static const secondaryText = Color(0xFF52645F);
  static const mutedText = Color(0xFF5E6E6B);

  // --- 30% secondary: sage -------------------------------------------------
  static const secondary = Color(0xFF6E9482);
  static const secondarySoft = Color(0xFFE4EDE7);
  static const secondaryMid = Color(0xFFCADBD0);
  static const secondaryStrong = Color(0xFF35604F);

  // --- 10% accent: petrol teal --------------------------------------------
  static const primary = Color(0xFF2E686A);
  static const primaryStrong = Color(0xFF214E50);
  static const primarySoft = Color(0xFFDCEBEA);
  static const onPrimary = Color(0xFFF9F6F0);

  // --- status (meaning, outside the 60/30/10) -------------------------------
  static const success = Color(0xFF4A8F73);
  static const successStrong = Color(0xFF2F6F55);
  static const successSoft = Color(0xFFE2F0EA);
  static const warning = Color(0xFFB8791C);
  static const warningStrong = Color(0xFF7A5416);
  static const warningSoft = Color(0xFFF8EBD4);
  static const danger = Color(0xFFB73E34);
  static const dangerStrong = Color(0xFF8E2F27);
  static const dangerSoft = Color(0xFFF8E3DE);
  static const info = Color(0xFF5C8194);
  static const infoStrong = Color(0xFF3F6275);
  static const infoSoft = Color(0xFFE3EDF2);

  // --- over photos, maps and video ------------------------------------------
  static const onMedia = Color(0xFFFFFFFF);
  static const onMediaMuted = Color(0xB3FFFFFF);
  static const onMediaSoft = Color(0x61FFFFFF);
  static const onMediaFaint = Color(0x3DFFFFFF);
  static const onMediaClear = Color(0x00FFFFFF);
  static const mediaBackground = Color(0xFF000000);
  static const scrim = Color(0x8A000000);
  static const scrimSoft = Color(0x59000000);
  static const scrimLight = Color(0x26000000);

  // --- shadows ---------------------------------------------------------------
  static const shadow = Color(0x1A6D5E4C);
  static const shadowSoft = Color(0x0F6D5E4C);
  static const shadowStrong = Color(0x266D5E4C);

  /// Top to bottom of the page background where a screen has a gradient: the
  /// same three steps everywhere, so no screen drifts to a different tint.
  static const backgroundGradient = <Color>[surface, background, backgroundDeep];
}

/// What tells the kinds of place of the radar ("Vicino a me") apart. They keep
/// their own hues on purpose and stay clear of the accent teal and the sage.
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
}

/// The colour a pet gets for itself (avatar ring, calendar dots) and the pale
/// tint of its card. Picked per animal, not part of the app's own palette.
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

  static const tintGreen = Color(0xFFE7F2EE);
  static const tintAmber = Color(0xFFF6EADF);
  static const tintYellow = Color(0xFFF5F0D8);
  static const tintBlue = Color(0xFFE3EBF0);
  static const tintOlive = Color(0xFFEDF0DF);
  static const tintTeal = Color(0xFFE1EEEE);
  static const tintViolet = Color(0xFFF1E7F3);
}
