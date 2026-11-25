import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/shell/shell_bottom_bar.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/app_text_scaler.dart';
import 'package:vet_app_mobile/design_system/responsive.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final language in ['it', 'en', 'es', 'de', 'fr']) {
    for (final width in [320.0, 360.0, 390.0]) {
      for (final text in [1.0, 1.3]) {
        testWidgets('$language, $width px, text $text: names whole, on one line, off the edge',
            (tester) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final l10n = lookupAppLocalizations(Locale(language));
          final labels = [
            l10n.shellTabHome,
            l10n.shellTabPets,
            l10n.shellTabActivities,
            l10n.shellTabSettings,
          ];
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
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
                bottomNavigationBar: ShellBottomBar(
                  width: width,
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  destinations: [
                    for (final label in labels)
                      NavigationDestination(icon: const Icon(Icons.circle), label: label),
                  ],
                ),
              ),
            ),
          );

          for (final label in labels) {
            final rect = tester.getRect(find.text(label));
            final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
            expect(
              rect.width + 0.01,
              greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity)),
              reason: '$label is broken on two lines',
            );
            expect(rect.left, greaterThanOrEqualTo(8), reason: label);
            expect(rect.right, lessThanOrEqualTo(width - 8), reason: label);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
