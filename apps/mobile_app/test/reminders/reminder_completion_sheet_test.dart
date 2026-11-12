import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/app/router/app_router.dart';
import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';
import 'package:vet_app_mobile/features/medical_records/domain/record_category.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/reminders/application/reminder_completion_service.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/features/reminders/domain/reminder_category.dart';
import 'package:vet_app_mobile/features/reminders/presentation/widgets/reminder_completion_sheet.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

final _now = DateTime(2026, 10, 21, 12);

ReminderEntry _reminder(String id, {String pet = 'Moka', ReminderCategory? category}) => ReminderEntry(
      id: id,
      petName: pet,
      title: 'Richiamo vaccinale',
      kind: EventKind.spot,
      dueAt: DateTime(2026, 10, 20, 9),
      category: category,
    );

PetProfile _fish() => const PetProfile(
      id: 'fish-1',
      name: 'Nemo',
      species: 'Pesce',
      breed: '',
      birthDateLabel: '',
      sex: '',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'N',
      accentColor: Colors.white,
      identityColor: Colors.blue,
    );

Future<bool?> _open(WidgetTester tester, ReminderEntry reminder) async {
  bool? handled;
  await tester.pumpWidget(
    MaterialApp(
      scaffoldMessengerKey: AppRouter.scaffoldMessengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('it'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => handled = await askToCompleteReminder(
                context,
                reminder,
                service: ReminderCompletionService(now: () => _now),
              ),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
  return handled;
}

List<MedicalRecordEntry> _recordsOf(String id) =>
    MedicalRecordsRepository.previewRecords.where((r) => r.id.startsWith('reminder-$id-')).toList();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('"Sì, registra" writes the entry with the reminder\'s category and says so',
      (tester) async {
    final reminder = _reminder('sheet-yes', category: ReminderCategory.vaccine);
    await RemindersRepository().saveReminder(reminder);
    await _open(tester, reminder);

    expect(find.text('Fatto?'), findsOneWidget);
    expect(find.text('Registralo nello storico di Moka.'), findsOneWidget);
    expect(find.text('Sì, registra'), findsOneWidget);
    expect(find.text('Rimanda'), findsOneWidget);
    expect(find.text('Non fatto'), findsOneWidget);
    // The real date is proposed (the due day) and the title comes from the reminder.
    expect(find.text('20/10/2026'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Richiamo vaccinale'), findsOneWidget);

    await tester.tap(find.text('Sì, registra'));
    await tester.pumpAndSettle();

    final record = _recordsOf('sheet-yes').single;
    expect(record.category, RecordCategory.vaccine);
    expect(record.title, 'Richiamo vaccinale');
    expect(record.eventDate, DateTime(2026, 10, 20));
    expect(find.text('Registrato nello storico di Moka.'), findsOneWidget);
  });

  testWidgets('the owner can change the category and the type before saving', (tester) async {
    final reminder = _reminder('sheet-edit', category: ReminderCategory.vaccine);
    await RemindersRepository().saveReminder(reminder);
    await _open(tester, reminder);

    Future<void> tapVisible(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tapVisible(find.widgetWithText(ChoiceChip, 'Esame'));
    await tapVisible(find.widgetWithText(ChoiceChip, 'Analisi del sangue'));
    await tapVisible(find.text('Sì, registra'));

    final record = _recordsOf('sheet-edit').single;
    expect(record.category, RecordCategory.exam);
    expect(record.subtype, 'blood');
  });

  testWidgets('"Non fatto" creates no entry', (tester) async {
    final reminder = _reminder('sheet-no', category: ReminderCategory.vaccine);
    await RemindersRepository().saveReminder(reminder);
    await _open(tester, reminder);

    await tester.tap(find.text('Non fatto'));
    await tester.pumpAndSettle();

    expect(_recordsOf('sheet-no'), isEmpty);
    expect(find.text('Segnato come non fatto.'), findsOneWidget);
  });

  testWidgets('"Rimanda" creates no entry and leaves the reminder open', (tester) async {
    final reminder = _reminder('sheet-later', category: ReminderCategory.vaccine);
    await RemindersRepository().saveReminder(reminder);
    await _open(tester, reminder);

    await tester.tap(find.text('Rimanda'));
    await tester.pumpAndSettle();

    expect(_recordsOf('sheet-later'), isEmpty);
    expect(find.text('Te lo richiedo domani.'), findsOneWidget);
    final stored = (await RemindersRepository().loadReminders()).firstWhere((r) => r.id == 'sheet-later');
    expect(stored.isDone, isFalse);
  });

  testWidgets('a non-clinical reminder only asks to tick it, no record fields', (tester) async {
    final reminder = _reminder('sheet-groom', category: ReminderCategory.grooming);
    await RemindersRepository().saveReminder(reminder);
    await _open(tester, reminder);

    expect(find.text('Lo segno come fatto?'), findsOneWidget);
    expect(find.text('Sì, fatto'), findsOneWidget);
    expect(find.text('Quando è successo'), findsNothing);

    await tester.tap(find.text('Sì, fatto'));
    await tester.pumpAndSettle();

    expect(_recordsOf('sheet-groom'), isEmpty);
    expect(find.text('Segnato come fatto.'), findsOneWidget);
  });

  testWidgets('no vaccine is offered for a fish, even if the reminder says vaccine', (tester) async {
    await PetDemoStore.instance.upsert(_fish());
    final reminder = _reminder('sheet-fish', pet: 'Nemo', category: ReminderCategory.vaccine);
    await _open(tester, reminder);

    expect(find.widgetWithText(ChoiceChip, 'Vaccino'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Visita'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Toelettatura'), findsOneWidget);
    // Starts from a category that makes sense for the animal.
    final visit = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Visita'));
    expect(visit.selected, isTrue);
  });
}
