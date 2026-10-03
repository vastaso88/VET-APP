
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/tokens/app_colors.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('selected chip label meets WCAG AA (4.5:1) against the selected fill', (tester) async {
    final chip = AppTheme.light().chipTheme;
    final label = chip.secondaryLabelStyle!.color!;
    final fill = chip.selectedColor!;
    expect(_contrast(label, fill), greaterThanOrEqualTo(4.5));
  });

  testWidgets('selected chip label is light, not the dark primary tone', (tester) async {
    final chip = AppTheme.light().chipTheme;
    final label = chip.secondaryLabelStyle!.color!;
    expect(label.computeLuminance(), greaterThan(0.5));
    expect(label, isNot(AppColors.primaryStrong));
  });

  testWidgets('unselected chip label meets WCAG AA against its background', (tester) async {
    final chip = AppTheme.light().chipTheme;
    final label = chip.labelStyle!.color!;
    final background = chip.backgroundColor!;
    expect(_contrast(label, background), greaterThanOrEqualTo(4.5));
  });

  testWidgets('a rendered selected ChoiceChip paints its label with readable contrast', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: ChoiceChip(
              label: const Text('10 km'),
              selected: true,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final style = DefaultTextStyle.of(tester.element(find.text('10 km'))).style;
    expect(_contrast(style.color!, AppColors.primary), greaterThanOrEqualTo(4.5));
  });

  testWidgets('a selected SegmentedButton segment is legible on its selected fill', (tester) async {
    final theme = AppTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Un pesce')),
                ButtonSegment(value: true, label: Text('Acquario')),
              ],
              selected: const {true},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final style = DefaultTextStyle.of(tester.element(find.text('Acquario'))).style;
    expect(
      _contrast(style.color!, theme.colorScheme.secondaryContainer),
      greaterThanOrEqualTo(4.5),
    );
  });
}
