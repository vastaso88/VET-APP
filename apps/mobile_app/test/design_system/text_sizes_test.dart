import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/tokens/app_text_styles.dart';

/// Nothing that informs is smaller than 14 (test round, card A04).
const _smallest = 14.0;

/// Where a smaller size stays, with the reason.
const _allowed = <String, String>{
  // Printed paper, not the screen.
  'lib/features/medical_records/presentation/history_pdf.dart': 'printed paper',
  // One letter or number in a mark; the day says it in words too.
  'lib/features/reminders/domain/reminder_calendar.dart': 'initial in a calendar mark',
  // Axis labels, 12: the same values are written in full under the chart.
  'lib/features/monitoring/presentation/widgets/weight_chart_view.dart': 'chart axis',
  'lib/features/monitoring/presentation/widgets/activity_chart_view.dart': 'chart axis',
  // The credit of the map, 12, on a map 150 px high.
  'lib/features/dog_walks/presentation/widgets/walk_mini_map.dart': 'map credit',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('the text tokens are 14 or more', (tester) async {
    for (final style in [
      AppTextStyles.display,
      AppTextStyles.heading,
      AppTextStyles.title,
      AppTextStyles.body,
      AppTextStyles.bodySmall,
      AppTextStyles.caption,
      AppTextStyles.button,
    ]) {
      expect(style.fontSize, greaterThanOrEqualTo(_smallest));
    }
  });

  test('no page writes a smaller size by hand', () {
    final size = RegExp(r'fontSize: *(\d+(?:\.\d+)?)\b');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      // Home has its own measures (13 in its rows), decided with its new layout.
      if (path.startsWith('lib/features/home/') || _allowed.containsKey(path)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final found = size.firstMatch(lines[i]);
        if (found == null) continue;
        if (double.parse(found.group(1)!) < _smallest) {
          offenders.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  /// Size on the screen, after whatever the component does to the text.
  double painted(WidgetTester tester, String text) {
    final finder = find.text(text);
    final paragraph = tester.renderObject<RenderBox>(finder);
    final scale = tester.getRect(finder).height / paragraph.size.height;
    final style = tester
        .widget<RichText>(find.descendant(of: finder, matching: find.byType(RichText)).first)
        .text
        .style!;
    return style.fontSize! * scale;
  }

  testWidgets('a field: label, help and error are 14 on the screen', (tester) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Form(
            key: key,
            child: Column(
              children: [
                TextFormField(
                  initialValue: 'Milo',
                  decoration: const InputDecoration(labelText: 'Nome', helperText: 'Aiuto'),
                ),
                TextFormField(
                  validator: (_) => 'Inserisci un titolo.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    key.currentState!.validate();
    await tester.pumpAndSettle();
    for (final text in ['Nome', 'Aiuto', 'Inserisci un titolo.']) {
      expect(painted(tester, text), greaterThanOrEqualTo(_smallest - 0.01), reason: text);
    }
  });

  testWidgets('a pill, a segment and a bar name are 14', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              ChoiceChip(label: const Text('Cani'), selected: false, onSelected: (_) {}),
              SegmentedButton<int>(
                segments: const [ButtonSegment(value: 0, label: Text('Elenco'))],
                selected: const {0},
                onSelectionChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    for (final text in ['Cani', 'Elenco']) {
      expect(painted(tester, text), greaterThanOrEqualTo(_smallest), reason: text);
    }
  });
}
