import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/features/monitoring/domain/body_condition.dart';
import 'package:vet_app_mobile/features/monitoring/presentation/widgets/body_condition_bar.dart';

Widget _bar({required double width, required double textScale}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 640), textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Center(
          child: SizedBox(width: width - 48, child: const BodyConditionBar(selected: BodyCondition.slightlyOverweight)),
        ),
      ),
    ),
  );
}

double _fontSize(WidgetTester tester, int score) =>
    tester.widget<Text>(find.byKey(ValueKey('bcs-label-$score'))).style!.fontSize!;

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final textScale in [1.0, 1.3]) {
    testWidgets('320 px, text x$textScale: the long label wraps on two lines, no overflow, same size as the others',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_bar(width: 320, textScale: textScale));
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');

      final sizes = {for (final c in BodyCondition.values) _fontSize(tester, c.score)};
      expect(sizes, hasLength(1), reason: 'every label has the same size');
      expect(sizes.single, greaterThanOrEqualTo(bodyConditionLabelMinSize));

      // "Leggermente sovrappeso" is two words: it must break onto two lines.
      // "Leggermente sovrappeso" is two words: at least two lines tall.
      final height = tester.getSize(find.byKey(const ValueKey('bcs-label-4'))).height;
      expect(height, greaterThan(sizes.single * textScale * 1.5 * 1.2));
    });
  }

  test('the common size never goes below the minimum and never above the maximum', () {
    final big = bodyConditionLabelSize(
      labels: const ['Magro', 'Ideale'],
      columnWidth: 500,
      textScaler: TextScaler.noScaling,
    );
    expect(big, bodyConditionLabelMaxSize);

    final tiny = bodyConditionLabelSize(
      labels: const ['Leggermente sovrappeso'],
      columnWidth: 5,
      textScaler: TextScaler.noScaling,
    );
    expect(tiny, bodyConditionLabelMinSize);
  });
}
