import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radii.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_text_styles.dart';
import 'slide_page_transitions_builder.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.text,
      ).copyWith(
        brightness: Brightness.light,
        primaryContainer: AppColors.primarySoft,
        onPrimaryContainer: AppColors.primary,
        secondaryContainer: AppColors.secondarySoft,
        onSecondaryContainer: AppColors.secondaryStrong,
        tertiary: AppColors.info,
        onTertiary: AppColors.onPrimary,
        errorContainer: AppColors.dangerSoft,
        onErrorContainer: AppColors.dangerStrong,
        surfaceTint: Colors.transparent,
        error: AppColors.danger,
        onError: AppColors.onPrimary,
        outline: AppColors.borderStrong,
        outlineVariant: AppColors.border,
        shadow: AppColors.shadow,
        surfaceContainerLowest: AppColors.surfaceElevated,
        surfaceContainerLow: AppColors.surface,
        surfaceContainer: AppColors.surface,
        surfaceContainerHigh: AppColors.surfaceElevated,
        surfaceContainerHighest: AppColors.surfaceElevated,
      ),
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
    );

    // The one look of the main action, whichever button widget a page uses.
    final mainButton = FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
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
        iconTheme: const IconThemeData(color: AppColors.secondaryText),
        actionsIconTheme: const IconThemeData(color: AppColors.secondaryText),
        titleTextStyle: AppTextStyles.title,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.secondarySoft,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.secondaryText),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.secondarySoft,
        selectionHandleColor: AppColors.primary,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display,
        displayMedium: AppTextStyles.heading,
        displaySmall: AppTextStyles.title,
        headlineMedium: AppTextStyles.heading,
        headlineSmall: AppTextStyles.title,
        titleLarge: AppTextStyles.title,
        titleMedium: AppTextStyles.body,
        titleSmall: AppTextStyles.caption,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.bodySmall,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.button,
        labelMedium: AppTextStyles.caption,
        labelSmall: AppTextStyles.caption,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: mainButton),
      filledButtonTheme: FilledButtonThemeData(style: mainButton),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
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
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.secondary),
          backgroundColor: AppColors.surfaceElevated,
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
        fillColor: AppColors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.mutedText),
        labelStyle:
            AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText),
        floatingLabelStyle:
            AppTextStyles.caption.copyWith(color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: AppColors.shadow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.secondarySoft,
        disabledColor: AppColors.secondarySoft,
        selectedColor: AppColors.primary,
        secondarySelectedColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        labelStyle: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
        ),
        // Selected chips fill with `selectedColor` (dark primary), so their
        // label and checkmark must be the light on-primary tone.
        secondaryLabelStyle: AppTextStyles.caption.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w700,
        ),
        checkmarkColor: AppColors.onPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
    );
  }
}
