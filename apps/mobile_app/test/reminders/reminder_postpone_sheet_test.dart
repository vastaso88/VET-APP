import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/features/reminders/presentation/widgets/reminder_postpone_sheet.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

final _reminder = ReminderEntry(
  id: 'postpone',
  petName: 'Moka',
  title: 'Richiamo vaccinale',
  kind: EventKind.spot,
  dueAt: DateTime(2026, 10, 21, 9),
);

/// The popup opened from a button, the clock in the test's hands.
class _Popup {
  _Popup(this.now);

  DateTime now;
  bool canRing = true;
  bool closed = false;
  DateTime? chosen;

  Future<void> open(WidgetTester tester, {Locale locale = const Locale('it')}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  chosen = await askPostponeMoment(
                    context,
                    _reminder,
                    now: () => now,
                    alertsCanRing: (_) async => canRing,
                  );
                  closed = true;
                },
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }
}

const _past = "Quest'ora è già passata: scegli un orario più tardi.";
const _noAlerts =
    "Qui gli avvisi sono spenti: non suonerà nulla, ma ti rifarò la domanda nell'app.";

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('asks when, with the four choices and the time each one means', (tester) async {
    final popup = _Popup(DateTime(2026, 10, 21, 14, 23, 40));
    await popup.open(tester);

    expect(find.text('Quando vuoi che te lo ricordi?'), findsOneWidget);
    expect(find.text('Tra 1 ora'), findsOneWidget);
    expect(find.text('15:23'), findsOneWidget);
    expect(find.text('Stasera'), findsOneWidget);
    expect(find.text('19:00'), findsOneWidget);
    expect(find.text('Domani mattina'), findsOneWidget);
    expect(find.text('gio 22 ott, 09:00'), findsOneWidget);
    expect(find.text('Scegli giorno e ora'), findsOneWidget);
    expect(find.text(_noAlerts), findsNothing);
  });

  for (final (label, at) in [
    ('Tra 1 ora', DateTime(2026, 10, 21, 15, 23)),
    ('Stasera', DateTime(2026, 10, 21, 19)),
    ('Domani mattina', DateTime(2026, 10, 22, 9)),
  ]) {
    testWidgets('"$label" answers with that moment, to the minute', (tester) async {
      final popup = _Popup(DateTime(2026, 10, 21, 14, 23, 40));
      await popup.open(tester);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(popup.chosen, at);
    });
  }

  testWidgets('"Stasera" is not offered once seven is gone', (tester) async {
    final popup = _Popup(DateTime(2026, 10, 21, 19));
    await popup.open(tester);

    expect(find.text('Stasera'), findsNothing);
    expect(find.text('Tra 1 ora'), findsOneWidget);
    expect(find.text('Domani mattina'), findsOneWidget);
    expect(find.text('Scegli giorno e ora'), findsOneWidget);
  });

  testWidgets('"Stasera" left on screen past seven is refused, not scheduled in the past',
      (tester) async {
    final popup = _Popup(DateTime(2026, 10, 21, 18, 59));
    await popup.open(tester);
    popup.now = DateTime(2026, 10, 21, 19, 1);
    await tester.tap(find.text('Stasera'));
    await tester.pumpAndSettle();

    expect(popup.closed, isFalse);
    expect(find.text(_past), findsOneWidget);
    expect(find.text('Stasera'), findsNothing);
  });

  testWidgets('"Scegli giorno e ora" takes a day, then a time', (tester) async {
    final popup = _Popup(DateTime(2026, 10, 21, 10));
    await popup.open(tester);
    await tester.tap(find.text('Scegli giorno e ora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('23'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // The time: nine in the morning is proposed for another day.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(popup.chosen, DateTime(2026, 10, 23, 9));
  });

  testWidgets('a day that is gone cannot be picked', (tester) async {
    final popup = _Popup(DateTime(2026, 10, 21, 10));
    await popup.open(tester);
    await tester.tap(find.text('Scegli giorno e ora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Still today, at the proposed time: an hour from now.
    expect(popup.chosen, DateTime(2026, 10, 21, 11));
  });

  testWidgets('an hour already gone today is refused and the popup stays open', (tester) async {
    final popup = _Popup(DateTime(2026, 10, 21, 10));
    await popup.open(tester);
    await tester.tap(find.text('Scegli giorno e ora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    popup.now = DateTime(2026, 10, 21, 11);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // 11:00 at 11:00 is not ahead any more.
    expect(popup.closed, isFalse);
    expect(find.text(_past), findsOneWidget);

    await tester.tap(find.text('Domani mattina'));
    await tester.pumpAndSettle();
    expect(popup.chosen, DateTime(2026, 10, 22, 9));
  });

  testWidgets('closing the calendar goes back to the choices; closing the popup chooses nothing',
      (tester) async {
    final popup = _Popup(DateTime(2026, 10, 21, 10));
    await popup.open(tester);
    await tester.tap(find.text('Scegli giorno e ora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(popup.closed, isFalse);
    expect(find.text('Tra 1 ora'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(popup.closed, isTrue);
    expect(popup.chosen, isNull);
  });

  testWidgets('when nothing can ring here it says so, and still lets the owner choose',
      (tester) async {
    final popup = _Popup(DateTime(2026, 10, 21, 14))..canRing = false;
    await popup.open(tester);

    expect(find.text(_noAlerts), findsOneWidget);

    await tester.tap(find.text('Tra 1 ora'));
    await tester.pumpAndSettle();
    expect(popup.chosen, DateTime(2026, 10, 21, 15));
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('${locale.languageCode}: fits a small phone with large text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final popup = _Popup(DateTime(2026, 10, 21, 14))..canRing = false;
      await popup.open(tester, locale: locale);
      final l10n = lookupAppLocalizations(locale);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.remindersPostponeTitle), findsOneWidget);
      expect(find.text(l10n.remindersPostponeNoAlerts), findsOneWidget);
      await tester.ensureVisible(find.text(l10n.remindersPostponePick));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
