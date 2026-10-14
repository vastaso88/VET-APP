import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';
import 'package:vet_app_mobile/features/medical_records/data/pet_conditions_repository.dart';
import 'package:vet_app_mobile/features/medical_records/domain/pet_condition.dart';
import 'package:vet_app_mobile/features/medical_records/domain/record_category.dart';

MedicalRecordEntry _record(String id, {DateTime? eventDate, DateTime? createdOn}) =>
    MedicalRecordEntry(
      id: id,
      petName: 'Moka',
      title: id,
      subtitle: '',
      meta: '',
      badge: '',
      detailSource: '',
      createdAt: '',
      timeline: const [],
      eventDate: eventDate,
      createdOn: createdOn,
    );

void main() {
  group('RecordCategory', () {
    test('a missing or unknown stored value is a document', () {
      expect(RecordCategory.fromKey(null), RecordCategory.document);
      expect(RecordCategory.fromKey('something-new'), RecordCategory.document);
      expect(RecordCategory.fromKey('exam'), RecordCategory.exam);
    });

    test('the stored keys are the ones the backend reads', () {
      expect(RecordCategory.values.map((c) => c.key), [
        'visit',
        'exam',
        'vaccine',
        'therapy',
        'document',
      ]);
    });

    test('only visits, exams and therapies have a finer type', () {
      expect(RecordCategory.visit.subtypes, contains('specialist'));
      expect(RecordCategory.exam.subtypes, containsAll(['blood', 'urine', 'xray', 'ultrasound']));
      expect(RecordCategory.therapy.subtypes, contains('antiparasitic'));
      expect(RecordCategory.vaccine.subtypes, isEmpty);
      expect(RecordCategory.document.subtypes, isEmpty);
    });
  });

  group('suggestCategoryFromTitle', () {
    test('proposes a category when the title says it', () {
      expect(suggestCategoryFromTitle('Richiamo vaccinale Moka'), RecordCategory.vaccine);
      expect(suggestCategoryFromTitle('emocromo_2026.pdf'), RecordCategory.exam);
      expect(suggestCategoryFromTitle('Ecografia addome'), RecordCategory.exam);
      expect(suggestCategoryFromTitle('Visita di controllo'), RecordCategory.visit);
      expect(suggestCategoryFromTitle('Terapia antibiotica'), RecordCategory.therapy);
    });

    test('a vaccine wins over a visit mentioned in the same title', () {
      expect(suggestCategoryFromTitle('Visita e vaccino'), RecordCategory.vaccine);
    });

    test('says nothing when the title says nothing', () {
      expect(suggestCategoryFromTitle('IMG_2041.jpg'), isNull);
      expect(suggestCategoryFromTitle(''), isNull);
    });
  });

  group('MedicalRecordEntry', () {
    test('a record is a document until the owner files it elsewhere', () {
      expect(_record('a').category, RecordCategory.document);
    });

    test('lists are ordered by the day of the event, not the upload day', () {
      final visit = _record(
        'visit',
        eventDate: DateTime(2026, 1, 10),
        createdOn: DateTime(2026, 10, 1),
      );
      final uploadedLater = _record('later', createdOn: DateTime(2026, 5, 1));

      final sorted = [visit, uploadedLater]..sort((a, b) => b.sortDate.compareTo(a.sortDate));

      expect(sorted.map((r) => r.id), ['later', 'visit']);
      expect(visit.sortDate, DateTime(2026, 1, 10));
    });

    test('copyWith changes the details and keeps the file', () {
      final original = MedicalRecordEntry(
        id: 'a',
        petName: 'Moka',
        title: 'scan.pdf',
        subtitle: 'PDF',
        meta: '',
        badge: '',
        detailSource: '',
        createdAt: '',
        timeline: const [],
        attachmentId: 'file-1',
      );

      final filed = original.copyWith(category: RecordCategory.exam, subtype: 'blood');

      expect(filed.category, RecordCategory.exam);
      expect(filed.subtype, 'blood');
      expect(filed.attachmentId, 'file-1');
      expect(filed.copyWith(clearSubtype: true).subtype, isNull);
    });
  });

  group('conditions', () {
    PetConditionEntry condition(String name, {DateTime? since, bool ongoing = true}) =>
        PetConditionEntry(
          id: name,
          petId: 'pet-1',
          name: name,
          startedOn: since,
          ongoing: ongoing,
        );

    test('ongoing first, then the most recently started', () {
      final sorted = sortConditions([
        condition('old', since: DateTime(2020, 1, 1)),
        condition('resolved', since: DateTime(2026, 1, 1), ongoing: false),
        condition('recent', since: DateTime(2026, 6, 1)),
        condition('undated'),
      ]);

      expect(sorted.map((c) => c.name), ['recent', 'old', 'undated', 'resolved']);
    });

    test('without Supabase they are kept per pet for the session', () async {
      final repository = PetConditionsRepository();
      await repository.save(condition('Otite', since: DateTime(2026, 2, 1)));
      await repository.save(
        PetConditionEntry(id: 'other', petId: 'pet-2', name: 'Dermatite'),
      );

      final mine = await repository.loadForPet('pet-1');
      expect(mine.map((c) => c.name), ['Otite']);

      await repository.save(condition('Otite', since: DateTime(2026, 2, 1), ongoing: false));
      expect((await repository.loadForPet('pet-1')).single.ongoing, isFalse);

      await repository.delete('Otite');
      expect(await repository.loadForPet('pet-1'), isEmpty);
      await repository.delete('other');
    });
  });
}
