import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/settings/presentation/pages/settings_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/widgets/min_tap_target.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    return initializeDateFormatting('it');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the Layout choices are spoken as choices, with the one in use (A01)',
      (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsPage(),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('LAYOUT'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final monday = find.ancestor(of: find.text('Lunedì'), matching: find.byType(MinTapTarget));
    expect(tester.getSize(monday).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(find.text('Lunedì')),
      isSemantics(
        label: 'Lunedì',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Domenica')),
      isSemantics(label: 'Domenica', isButton: true, isSelected: false, hasSelectedState: true),
    );
    handle.dispose();
  });
}
