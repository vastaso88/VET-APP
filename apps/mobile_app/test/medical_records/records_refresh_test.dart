import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';
import 'package:vet_app_mobile/features/medical_records/data/pet_conditions_repository.dart';
import 'package:vet_app_mobile/features/medical_records/domain/pet_condition.dart';
import 'package:vet_app_mobile/features/medical_records/domain/record_category.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/medical_records_controller.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/pages/record_category_page.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/pet_medical_records_tab.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

MedicalRecordEntry _record(String id, String title, RecordCategory category) =>
    MedicalRecordEntry(
      id: id,
      petName: 'Moka',
      title: title,
      subtitle: '',
      meta: '',
      badge: '',
      detailSource: '',
      createdAt: '',
      category: category,
      eventDate: DateTime(2026, 10, 1),
      timeline: const [],
    );

/// A repository whose reads are answered by hand, so a test can make an older
/// read finish after a newer one.
class _ManualRepository extends MedicalRecordsRepository {
  final reads = <Completer<List<MedicalRecordEntry>>>[];

  @override
  Future<List<MedicalRecordEntry>> loadRecords() {
    final completer = Completer<List<MedicalRecordEntry>>();
    reads.add(completer);
    return completer.future;
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final moka = samplePets.firstWhere((pet) => pet.name == 'Moka');
  final addedRecordIds = <String>[];
  final addedConditionIds = <String>[];

  tearDown(() async {
    for (final id in addedRecordIds) {
      await MedicalRecordsRepository().deleteRecord(id);
    }
    for (final id in addedConditionIds) {
      await PetConditionsRepository().delete(id);
    }
    addedRecordIds.clear();
    addedConditionIds.clear();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pumpTab(WidgetTester tester) => pump(
    tester,
    Scaffold(
      body: PetMedicalRecordsTab(pet: moka, repository: MedicalRecordsRepository()),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a vaccine added from the tab raises its counter at once', (tester) async {
    await pumpTab(tester);
    expect(find.text('1 registrato'), findsNWidgets(3));

    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaccino'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Rabbia 2026');
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    // Back on the tab, without leaving the pet and reopening it.
    expect(find.text('Rabbia 2026'), findsNothing);
    expect(find.text('2 registrati'), findsOneWidget);
    addedRecordIds.addAll(
      (await MedicalRecordsRepository().loadRecords())
          .where((record) => record.title == 'Rabbia 2026')
          .map((record) => record.id),
    );
  });

  testWidgets('a record saved elsewhere shows in the open category list and the tab', (
    tester,
  ) async {
    await pumpTab(tester);
    await tester.tap(find.text('Vaccini'));
    await tester.pumpAndSettle();
    expect(find.text('Richiamo vaccinale di Moka'), findsOneWidget);
    expect(find.text('Rabbia 2026'), findsNothing);

    final added = _record('refresh-test-1', 'Rabbia 2026', RecordCategory.vaccine);
    addedRecordIds.add(added.id);
    await MedicalRecordsRepository().saveRecord(added);
    await settle(tester);
    expect(find.text('Rabbia 2026'), findsOneWidget);

    // The tab behind the list is already up to date too.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('2 registrati'), findsOneWidget);
  });

  testWidgets('editing and deleting an entry updates list and counters', (tester) async {
    final added = _record('refresh-test-2', 'Controllo di prova', RecordCategory.visit);
    addedRecordIds.add(added.id);
    await MedicalRecordsRepository().saveRecord(added);
    await pumpTab(tester);
    expect(find.text('2 registrati'), findsOneWidget); // visits: 1 + the new one

    // Moved to the exams: the visit counter drops, the exam one rises.
    await MedicalRecordsRepository().updateRecordDetails(
      added.copyWith(category: RecordCategory.exam),
    );
    await settle(tester);
    expect(find.text('2 registrati'), findsOneWidget); // exams: 1 + the moved one
    expect(find.text('1 registrato'), findsNWidgets(2)); // vaccines, visits

    await MedicalRecordsRepository().deleteRecord(added.id);
    await settle(tester);
    expect(find.text('2 registrati'), findsNothing);
    expect(find.text('1 registrato'), findsNWidgets(3));
  });

  testWidgets('adding and removing an illness updates its counter at once', (tester) async {
    await pumpTab(tester);
    expect(find.text('0 registrati'), findsNWidgets(3));

    const condition = PetConditionEntry(id: 'refresh-test-cond', petId: 'pet-moka', name: 'Otite');
    addedConditionIds.add(condition.id);
    await PetConditionsRepository().save(condition);
    await settle(tester);
    expect(find.text('0 registrati'), findsNWidgets(2));
    expect(find.text('1 registrato'), findsNWidgets(4));

    await PetConditionsRepository().delete(condition.id);
    await settle(tester);
    expect(find.text('0 registrati'), findsNWidgets(3));
  });

  testWidgets('the category list keeps its entries on screen while it reloads', (tester) async {
    await pump(
      tester,
      RecordCategoryPage(
        pet: moka,
        category: RecordCategory.exam,
        repository: MedicalRecordsRepository(),
      ),
    );
    expect(find.text('Esame ematico di Moka'), findsOneWidget);

    final added = _record('refresh-test-3', 'Emocromo', RecordCategory.exam);
    addedRecordIds.add(added.id);
    final saving = MedicalRecordsRepository().saveRecord(added);
    await tester.pump();
    // No full-page loader in between: the old list stays until the new one is in.
    expect(find.text('Esame ematico di Moka'), findsOneWidget);
    await saving;
    await settle(tester);
    expect(find.text('Emocromo'), findsOneWidget);
  });

  test('an older, slower read never replaces a newer one', () async {
    final repository = _ManualRepository();
    final controller = MedicalRecordsController(repository: repository);
    addTearDown(controller.dispose);
    expect(repository.reads, hasLength(1)); // the first read, on creation

    MedicalRecordsRepository.changes.value++; // something was saved
    expect(repository.reads, hasLength(2));

    final newest = [_record('n', 'dopo il salvataggio', RecordCategory.vaccine)];
    final stale = [_record('o', 'prima del salvataggio', RecordCategory.vaccine)];
    repository.reads[1].complete(newest);
    await Future<void>.delayed(Duration.zero);
    repository.reads[0].complete(stale);
    await Future<void>.delayed(Duration.zero);

    expect(controller.records!.single.id, 'n');
  });

  test('a failed read is reported, not shown as an empty list', () async {
    final repository = _ManualRepository();
    final controller = MedicalRecordsController(repository: repository);
    addTearDown(controller.dispose);

    repository.reads.single.completeError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.recordsFailed, isTrue);
    expect(controller.records, isNull);
  });

  test('no screen hands setState a callback that returns a Future', () {
    // `setState(() => _future = load())` returns the Future: in debug builds
    // Flutter then throws before it schedules the rebuild, so the list is
    // never redrawn after a change (and the exception is swallowed by the
    // notifier that triggered it). The assignment goes in a block body.
    final offenders = <String>[];
    final patterns = [
      RegExp(r'setState\(\s*\(\)\s*=>\s*\w*[Ff]uture\w*\s*='),
      RegExp(r'setState\(\s*\(\)\s*=>\s*\w+\s*=\s*[\w.]*_?(load|fetch)\w*\(', caseSensitive: false),
    ];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final pattern in patterns) {
        for (final match in pattern.allMatches(text)) {
          final line = text.substring(0, match.start).split('\n').length;
          offenders.add('${entity.path}:$line');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
