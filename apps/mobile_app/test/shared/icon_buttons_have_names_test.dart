import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/widgets/typed_date_field.dart';

void main() {
  testWidgets('the calendar button of a date field has a spoken name', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TypedDateField(
            controller: TextEditingController(),
            decoration: const InputDecoration(),
            onPick: () {},
            pickIcon: const Icon(Icons.calendar_today_outlined),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Apri il calendario'), findsOneWidget);
    handle.dispose();
  });
}
