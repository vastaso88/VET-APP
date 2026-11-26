import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radii.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_text_styles.dart';
import 'slide_page_transitions_builder.dart';

/// The edge of every field, whatever its state.
OutlineInputBorder _fieldBorder(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      borderSide: BorderSide(color: color, width: width),
    );

/// The app's two themes, built from the same roles: [light] from
/// [AppPalette.light], [dark] from [AppPalette.dark]. The app follows the
/// phone's setting (lib/app/app.dart).
class AppTheme {
  static ThemeData light() => _build(AppPalette.light);

  static ThemeData dark() => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final isDark = p.brightness == Brightness.dark;
    // The text styles carry the colour of the palette in use: here the
    // colour of the theme being built is set on each of them.
    TextStyle ink(TextStyle style, Color color) => style.copyWith(color: color);
    final display = ink(AppTextStyles.display, p.text);
    final heading = ink(AppTextStyles.heading, p.text);
    final title = ink(AppTextStyles.title, p.text);
    final body = ink(AppTextStyles.body, p.secondaryText);
    final bodySmall = ink(AppTextStyles.bodySmall, p.secondaryText);
    final caption = ink(AppTextStyles.caption, p.mutedText);

    var scheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.secondary,
      onSecondary: p.onPrimary,
      surface: p.surface,
      onSurface: p.text,
    ).copyWith(
      brightness: p.brightness,
      primaryContainer: p.primarySoft,
      onPrimaryContainer: p.primary,
      secondaryContainer: p.secondarySoft,
      onSecondaryContainer: p.secondaryStrong,
      tertiary: p.info,
      onTertiary: p.onPrimary,
      errorContainer: p.dangerSoft,
      onErrorContainer: p.dangerStrong,
      surfaceTint: Colors.transparent,
      error: p.danger,
      onError: p.onPrimary,
      outline: p.borderStrong,
      outlineVariant: p.border,
      shadow: p.shadow,
      surfaceContainerLowest: p.surfaceElevated,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceElevated,
      surfaceContainerHighest: p.surfaceElevated,
    );
    if (isDark) {
      // Dialogs, sheets, date pickers and snack bars read these: in the dark
      // theme they are set, not left to the seed.
      scheme = scheme.copyWith(
        onSurfaceVariant: p.secondaryText,
        surfaceDim: p.background,
        surfaceBright: p.surfaceElevated,
        inverseSurface: p.text,
        onInverseSurface: p.background,
        inversePrimary: AppPalette.light.primary,
        primaryFixed: p.primarySoft,
        onPrimaryFixed: p.text,
        secondaryFixed: p.secondarySoft,
        onSecondaryFixed: p.text,
        tertiaryContainer: p.infoSoft,
        onTertiaryContainer: p.infoStrong,
        scrim: AppColors.mediaBackground,
      );
    }
    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.border,
    );

    // The one look of the main action, whichever button widget a page uses.
    final mainButton = FilledButton.styleFrom(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      textStyle: AppTextStyles.button,
    );

    return base.copyWith(
      // Apple's own slide (with its swipe back) stays on Apple devices.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SlidePageTransitionsBuilder(),
          TargetPlatform.fuchsia: SlidePageTransitionsBuilder(),
          TargetPlatform.linux: SlidePageTransitionsBuilder(),
          TargetPlatform.windows: SlidePageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: p.secondaryText),
        actionsIconTheme: IconThemeData(color: p.secondaryText),
        titleTextStyle: title,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: p.secondarySoft,
      ),
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: p.secondaryText),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.secondarySoft,
        selectionHandleColor: p.primary,
      ),
      textTheme: TextTheme(
        displayLarge: display,
        displayMedium: heading,
        displaySmall: title,
        headlineMedium: heading,
        headlineSmall: title,
        titleLarge: title,
        titleMedium: body,
        titleSmall: caption,
        bodyLarge: body,
        bodyMedium: bodySmall,
        bodySmall: caption,
        labelLarge: AppTextStyles.button,
        labelMedium: caption,
        labelSmall: caption,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: mainButton),
      filledButtonTheme: FilledButtonThemeData(style: mainButton),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
        extendedTextStyle: AppTextStyles.button,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: p.primary,
          side: BorderSide(color: p.borderStrong),
          backgroundColor: p.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: body.copyWith(color: p.mutedText),
        labelStyle:
            bodySmall.copyWith(color: p.secondaryText),
        // Material paints a floated label at 3/4 of its size: 14 on the screen.
        floatingLabelStyle: caption
            .copyWith(fontSize: 14 / 0.75, color: p.primary),
        helperStyle: bodySmall,
        helperMaxLines: 6,
        errorStyle: bodySmall.copyWith(
          color: p.danger,
          fontWeight: FontWeight.w600,
        ),
        errorMaxLines: 4,
        border: _fieldBorder(p.borderStrong, 1.5),
        enabledBorder: _fieldBorder(p.borderStrong, 1.5),
        disabledBorder: _fieldBorder(p.border, 1),
        focusedBorder: _fieldBorder(p.primary, 2),
        errorBorder: _fieldBorder(p.danger, 2),
        focusedErrorBorder: _fieldBorder(p.danger, 2),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shadowColor: p.shadow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: BorderSide(color: p.border),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: p.surfaceElevated,
          foregroundColor: p.text,
          selectedBackgroundColor: p.primary,
          selectedForegroundColor: p.onPrimary,
          side: BorderSide(color: p.borderStrong),
          textStyle: bodySmall.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      badgeTheme: BadgeThemeData(
        largeSize: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        textStyle: caption.copyWith(height: 1, letterSpacing: 0),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.secondarySoft,
        disabledColor: p.secondarySoft,
        selectedColor: p.primary,
        secondarySelectedColor: p.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        labelStyle: caption.copyWith(
          color: p.primary,
        ),
        // Selected chips fill with `selectedColor` (dark primary), so their
        // label and checkmark must be the light on-primary tone.
        secondaryLabelStyle: caption.copyWith(
          color: p.onPrimary,
          fontWeight: FontWeight.w700,
        ),
        checkmarkColor: p.onPrimary,
        side: BorderSide(color: p.borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
    );
  }
}
