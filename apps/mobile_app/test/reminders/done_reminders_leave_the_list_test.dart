import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/features/reminders/presentation/pages/reminders_pages.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

/// A completed reminder leaves the active list: from then on it lives only in
/// the Storico (reminder_completion_test.dart covers the Storico entry).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a reminder marked done disappears from Promemoria', (tester) async {
    final repository = RemindersRepository();
    final reminder = ReminderEntry(
      id: 'antiregressione-1',
      petName: 'Moka',
      title: 'Controllo antiregressione',
      kind: EventKind.spot,
      dueAt: DateTime.now().add(const Duration(days: 2)),
    );
    await tester.runAsync(() => repository.saveReminder(reminder));

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('it'),
        home: RemindersListPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Controllo antiregressione'), findsOneWidget);

    await tester.runAsync(() => repository.saveReminder(reminder.copyWith(isDone: true)));
    await tester.pumpAndSettle();
    expect(find.text('Controllo antiregressione'), findsNothing);
  });
}
