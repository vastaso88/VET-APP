import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/tokens/app_colors.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// What identifies a field, a pill or a button is at least 3 to 1 against what is
/// around it and against its own fill (WCAG 1.4.11; test round, card A03).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  void visible(Color edge, {required Color fill}) {
    for (final ground in [
      fill,
      AppColors.background,
      AppColors.surface,
      AppColors.surfaceElevated,
      AppColors.secondarySoft,
    ]) {
      expect(_contrast(edge, ground), greaterThanOrEqualTo(3), reason: '$edge on $ground');
    }
  }

  testWidgets('a field, in every state that can be written in', (tester) async {
    final field = AppTheme.light().inputDecorationTheme;
    for (final border in [
      field.border,
      field.enabledBorder,
      field.focusedBorder,
      field.errorBorder,
      field.focusedErrorBorder,
    ]) {
      final side = border!.borderSide;
      visible(side.color, fill: field.fillColor!);
      expect(side.width, greaterThanOrEqualTo(1.5));
    }
  });

  testWidgets('a pill that is not chosen, an outlined button, a segment', (tester) async {
    final theme = AppTheme.light();
    visible(theme.chipTheme.side!.color, fill: theme.chipTheme.backgroundColor!);
    final outlined = theme.outlinedButtonTheme.style!;
    visible(outlined.side!.resolve({})!.color, fill: outlined.backgroundColor!.resolve({})!);
    // What Material gives to segments, switches and menus.
    visible(theme.colorScheme.outline, fill: AppColors.surface);
  });

  testWidgets('the field of a page paints the edge of the theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: TextField()),
      ),
    );
    final decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
    expect(decorator.decoration.enabledBorder!.borderSide.color, AppColors.borderStrong);
  });

  test('no page draws the edge of a field by itself', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path == 'lib/app/theme/app_theme.dart') continue;
      if (entity.readAsStringSync().contains('OutlineInputBorder')) offenders.add(path);
    }
    expect(offenders, isEmpty, reason: 'the theme gives every field its border');
  });
}
