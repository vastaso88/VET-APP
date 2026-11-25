import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/app_text_scaler.dart';
import 'package:vet_app_mobile/design_system/responsive.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/pet_tab_bar.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

const _languages = ['it', 'en', 'es', 'de', 'fr'];

List<String> _labels(String language, int count) {
  final l10n = lookupAppLocalizations(Locale(language));
  return [
    l10n.petsDetailTabReminders,
    l10n.petsDetailTabChat,
    l10n.petsDetailTabRecords,
    l10n.petsDetailTabMonitoring,
    l10n.petsDetailTabWalks,
  ].take(count).toList();
}

Future<TabController> _pump(
  WidgetTester tester,
  List<String> labels, {
  double width = 320,
  double text = 1,
  String language = 'it',
}) async {
  tester.view.physicalSize = Size(width, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = TabController(length: labels.length, vsync: tester);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // The scaler of the app (app.dart): the width's own factor, then the phone's.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: AppTextScaler(
            system: TextScaler.linear(text),
            appFactor: appScaleOf(context),
          ),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [PetTabBar(controller: controller, labels: labels)]),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rows', () {
    test('one row when the titles fit', () {
      expect(PetTabBar.rowsFor([90, 45, 60, 100], 358), [
        [0, 1, 2, 3],
      ]);
    });

    test('four titles that do not fit: two and two', () {
      expect(PetTabBar.rowsFor([120, 60, 80, 130], 288), [
        [0, 1],
        [2, 3],
      ]);
    });

    test("a dog's five: three and two", () {
      expect(PetTabBar.rowsFor([100, 45, 65, 110, 100], 358), [
        [0, 1, 2],
        [3, 4],
      ]);
    });

    test('whatever the size, every tab has its place', () {
      for (final max in [10.0, 150.0, 288.0, 2000.0]) {
        final rows = PetTabBar.rowsFor([120, 60, 80, 130, 120], max);
        expect(rows.expand((row) => row), [0, 1, 2, 3, 4], reason: '$max');
      }
    });
  });

  for (final language in _languages) {
    for (final count in [3, 4, 5]) {
      for (final text in [1.0, 1.3]) {
        for (final width in [320.0, 390.0]) {
          testWidgets('$language, $count tabs, $width px, text $text: whole and in view',
              (tester) async {
            final labels = _labels(language, count);
            await _pump(tester, labels, width: width, text: text, language: language);

            final sizes = <double?>{};
            for (final label in labels) {
              final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
              final rect = tester.getRect(find.text(label));
              expect(rect.left, greaterThanOrEqualTo(16), reason: label);
              expect(rect.right, lessThanOrEqualTo(width - 16 + 0.01), reason: label);
              expect(
                rect.width + 0.01,
                greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity)),
                reason: '$label is cut',
              );
              sizes.add(DefaultTextStyle.of(tester.element(find.text(label))).style.fontSize);
            }
            expect(sizes, hasLength(1), reason: 'no title smaller than the others');

            // Across the full width, at least 48 px to touch.
            final bar = tester.getRect(find.byType(PetTabBar));
            expect(bar.left, 16);
            expect(bar.right, width - 16);
            for (final cell in tester.widgetList(find.byType(InkWell))) {
              expect(tester.getSize(find.byWidget(cell)).height, greaterThanOrEqualTo(48));
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }

  testWidgets('a tap opens that tab and shows which one is open', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = await _pump(tester, _labels('it', 4), text: 1.3);

    await tester.tap(find.text('Monitoraggio'));
    await tester.pumpAndSettle();
    expect(controller.index, 3);
    expect(
      tester.getSemantics(find.text('Monitoraggio')),
      isSemantics(isSelected: true, hint: 'Scheda 4 di 4'),
    );
    expect(tester.getSemantics(find.text('Chat')), isSemantics(isSelected: false));
    handle.dispose();
  });
}
