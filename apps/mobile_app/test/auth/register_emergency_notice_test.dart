import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/auth/presentation/pages/register_page.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

Widget _app() {
  AppLocaleHolder.current = const Locale('it');
  return MaterialApp(
    locale: const Locale('it'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: RegisterPage(initialBirthDate: DateTime(1990, 1, 1)),
  );
}

/// docs/compliance/22 §5: registration asks for the acknowledgement that Quokka does
/// not handle emergencies in a box of its own, never pre-ticked, with the short
/// version in front of the eyes.
void main() {
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  }

  testWidgets('the short version is on the page and the box is not pre-ticked', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pump();

    final short = find.byKey(const ValueKey('emergency-notice-short'));
    await reveal(tester, short);
    expect(short, findsOneWidget);
    expect(
      find.textContaining('Non aspettare la risposta dell'),
      findsOneWidget,
    );

    final box =
        tester.widget<SwitchListTile>(find.byKey(const ValueKey('emergency-notice-switch')));
    expect(box.value, isFalse);
  });

  testWidgets('it is a box of its own: ticking the Terms does not tick it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pump();

    final switches = find.byType(SwitchListTile);
    expect(switches, findsNWidgets(2)); // the Terms and the emergency notice
    await tester.tap(switches.first);
    await tester.pump();

    final notice =
        tester.widget<SwitchListTile>(find.byKey(const ValueKey('emergency-notice-switch')));
    expect(notice.value, isFalse);
  });
}
