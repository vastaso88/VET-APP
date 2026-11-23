import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/features/reminders/presentation/widgets/reminder_form.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/formatters/date_input_formatter.dart';
import 'package:vet_app_mobile/shared/widgets/typed_date_field.dart';

/// Collaudo giro 1 (TITOLO): a new reminder needs a title (not only spaces) and
/// cannot start in the past; one being edited can keep its (past) date.

Widget _app(ReminderForm form) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('it'),
      home: Scaffold(body: SingleChildScrollView(child: form)),
    );

Finder get _titleField => find.byType(TextFormField).first;
Finder get _dateField => find.descendant(
      of: find.byType(TypedDateField),
      matching: find.byType(TextFormField),
    );

Future<void> _save(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Salva');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

DateTime _daysFromToday(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late List<ReminderEntry> saved;

  Future<void> pumpNew(WidgetTester tester) async {
    saved = [];
    await tester.binding.setSurfaceSize(const Size(420, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(ReminderForm(petName: 'Moka', initial: null, onSave: saved.add, onCancel: () {})),
    );
    await tester.pump();
  }

  testWidgets('a title of only spaces is refused', (tester) async {
    await pumpNew(tester);

    await tester.enterText(_titleField, '    ');
    await _save(tester);

    expect(saved, isEmpty);
    expect(find.text('Inserisci un titolo.'), findsOneWidget);
  });

  testWidgets('a date in the past is refused when creating', (tester) async {
    await pumpNew(tester);

    await tester.enterText(_titleField, 'Vaccino');
    await tester.enterText(_dateField, formatDateForInput(_daysFromToday(-30)));
    await _save(tester);

    expect(saved, isEmpty);
    expect(find.text('Questa data è già passata: scegli oggi o un giorno futuro.'), findsOneWidget);
  });

  testWidgets('a future date is saved, with the title cleaned of the spaces around it',
      (tester) async {
    await pumpNew(tester);

    await tester.enterText(_titleField, '  Vaccino  ');
    await tester.enterText(_dateField, formatDateForInput(_daysFromToday(3)));
    await _save(tester);

    expect(saved, hasLength(1));
    expect(saved.single.title, 'Vaccino');
  });

  testWidgets('today at an hour already gone is refused, later today is not', (tester) async {
    // The default time of a new reminder is 09:00: only a run after it, and not near
    // it, can show the refusal; a run well before it shows the acceptance.
    final hour = DateTime.now().hour;
    if (hour >= 8 && hour <= 9) return; // too close to 09:00 to tell either way
    await pumpNew(tester);

    await tester.enterText(_titleField, 'Controllo');
    await tester.enterText(_dateField, formatDateForInput(_daysFromToday(0)));
    await _save(tester);

    if (hour > 9) {
      expect(saved, isEmpty);
      expect(find.text('Quest\'ora è già passata: scegli un orario più tardi.'), findsOneWidget);
    } else {
      expect(saved, hasLength(1));
    }
  });

  testWidgets('editing keeps a reminder whose date has already passed', (tester) async {
    saved = [];
    await tester.binding.setSurfaceSize(const Size(420, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final overdue = ReminderEntry(
      id: 'old-1',
      petName: 'Moka',
      title: 'Richiamo scaduto',
      kind: EventKind.spot,
      dueAt: _daysFromToday(-10).add(const Duration(hours: 9)),
    );

    await tester.pumpWidget(
      _app(ReminderForm(petName: 'Moka', initial: overdue, onSave: saved.add, onCancel: () {})),
    );
    await tester.pump();
    await tester.enterText(_titleField, 'Richiamo scaduto (modificato)');
    await _save(tester);

    expect(saved, hasLength(1));
    expect(saved.single.title, 'Richiamo scaduto (modificato)');
  });
}
