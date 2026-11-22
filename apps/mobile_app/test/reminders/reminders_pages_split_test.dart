import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
// The one import the routes and the other features use (QK-22): it must keep
// giving all the public pages and helpers, now that they live in their own files.
import 'package:vet_app_mobile/features/reminders/presentation/pages/reminders_pages.dart';
import 'package:vet_app_mobile/features/reminders/presentation/widgets/reminder_form.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

ReminderEntry _reminder() => ReminderEntry(
      id: 'split-1',
      petName: 'Moka',
      title: 'Vaccino di prova',
      kind: EventKind.spot,
      dueAt: DateTime.now().add(const Duration(days: 3)),
    );

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('it'),
      home: home,
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the original import still gives every public symbol the app uses', () {
    // Compile-time check as much as a runtime one.
    expect(const RemindersListPage(), isA<StatefulWidget>());
    expect(const ReminderCreatePage(), isA<StatefulWidget>());
    expect(const ReminderEditPage(), isA<StatefulWidget>());
    expect(const ReminderDetailPage(), isA<StatefulWidget>());
    expect(showReminderFailure, isA<Function>());
    expect(saveReminderInBackground, isA<Function>());
  });

  testWidgets('creating shows the form once', (tester) async {
    await tester.pumpWidget(_app(const ReminderCreatePage(petName: 'Moka')));
    await tester.pump();

    expect(find.byType(ReminderForm), findsOneWidget);
  });

  testWidgets('editing shows the form once, filled with the reminder', (tester) async {
    await tester.pumpWidget(_app(ReminderEditPage(reminder: _reminder())));
    await tester.pump();

    expect(find.byType(ReminderForm), findsOneWidget);
    expect(find.text('Vaccino di prova'), findsWidgets);
  });

  testWidgets('the detail has no form until Modifica is chosen, then exactly one',
      (tester) async {
    await tester.pumpWidget(_app(ReminderDetailPage(reminder: _reminder())));
    await tester.pump();
    expect(find.byType(ReminderForm), findsNothing);
    expect(find.text('Vaccino di prova'), findsWidgets);

    await tester.tap(find.text('Modifica').first);
    await tester.pumpAndSettle();

    expect(find.byType(ReminderForm), findsOneWidget);
  });

  testWidgets('saving from the form refreshes the reminders once', (tester) async {
    var ticks = 0;
    void onChange() => ticks++;
    RemindersRepository.changes.addListener(onChange);
    addTearDown(() => RemindersRepository.changes.removeListener(onChange));

    await tester.pumpWidget(_app(const ReminderCreatePage(petName: 'Moka')));
    await tester.pump();
    final form = tester.widget<ReminderForm>(find.byType(ReminderForm));
    final before = ticks;

    // The form hands the page its result; the page saves in the background once.
    form.onSave(_reminder());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(ticks - before, lessThanOrEqualTo(2), reason: 'one save, not a doubled one');
    expect(ticks - before, greaterThan(0));
  });
}
