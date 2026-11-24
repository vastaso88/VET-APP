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

/// Owner decision of 24 November 2026: the acknowledgement that Quokka does not handle
/// emergencies is a condition of the chat only, asked when the first chat is opened
/// (chat_notice_test.dart); registration asks for the Terms and the Privacy Policy alone.
void main() {
  testWidgets('registration asks for the Terms alone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.byKey(const ValueKey('emergency-notice-switch')), findsNothing);
    expect(find.byKey(const ValueKey('emergency-notice-short')), findsNothing);
  });
}
