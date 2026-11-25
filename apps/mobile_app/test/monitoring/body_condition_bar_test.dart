import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/features/monitoring/domain/body_condition.dart';
import 'package:vet_app_mobile/features/monitoring/presentation/widgets/body_condition_bar.dart';

Widget _bar({
  required double width,
  required double textScale,
  ValueChanged<BodyCondition>? onSelected,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 640), textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width - 48,
            child: BodyConditionBar(
              selected: BodyCondition.slightlyOverweight,
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    ),
  );
}

BoxDecoration _segment(WidgetTester tester, int score) => tester
    .widget<Container>(find.byKey(ValueKey('bcs-segment-$score')))
    .decoration! as BoxDecoration;

/// The level is not told by the colour alone (test round, card A02).
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final textScale in [1.0, 1.3, 2.0]) {
    testWidgets('320 px, text x$textScale: every level has its number, at 14 or more, no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_bar(width: 320, textScale: textScale));
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
      for (final condition in BodyCondition.values) {
        final label =
            tester.widget<Text>(find.byKey(ValueKey('bcs-label-${condition.score}')));
        expect(label.data, '${condition.score}');
        expect(label.style!.fontSize, greaterThanOrEqualTo(14));
      }
      // The ends of the scale are written in words.
      expect(find.text(BodyCondition.veryThin.label), findsOneWidget);
      expect(find.text(BodyCondition.overweight.label), findsOneWidget);
    });
  }

  testWidgets('without colours the chosen level still shows: outline and weight', (tester) async {
    await tester.pumpWidget(_bar(width: 390, textScale: 1));
    for (final condition in BodyCondition.values) {
      final chosen = condition == BodyCondition.slightlyOverweight;
      expect(_segment(tester, condition.score).border, chosen ? isNotNull : isNull);
      final label = tester.widget<Text>(find.byKey(ValueKey('bcs-label-${condition.score}')));
      expect(label.style!.fontWeight, chosen ? FontWeight.w800 : FontWeight.w500);
    }
  });

  testWidgets('as a choice: 48 px to touch, spoken with its name', (tester) async {
    final handle = tester.ensureSemantics();
    BodyCondition? picked;
    await tester.pumpWidget(_bar(width: 390, textScale: 1, onSelected: (c) => picked = c));
    final level = find.byKey(const ValueKey('bcs-level-2'));
    expect(tester.getSize(level).height, greaterThanOrEqualTo(48));
    await tester.tap(level);
    expect(picked, BodyCondition.thin);
    expect(find.bySemanticsLabel('2/5 · ${BodyCondition.thin.label}'), findsOneWidget);
    handle.dispose();
  });
}
