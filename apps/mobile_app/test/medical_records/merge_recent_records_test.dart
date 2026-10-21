import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';
import 'package:vet_app_mobile/features/medical_records/domain/record_category.dart';

MedicalRecordEntry _record(String id, String title) => MedicalRecordEntry(
      id: id,
      petName: 'Moka',
      title: title,
      subtitle: '',
      meta: '',
      badge: '',
      detailSource: '',
      createdAt: '',
      timeline: const [],
    );

void main() {
  test('a record saved this session is never shown twice', () {
    final saved = _record('upload-1', 'nuovo.pdf');
    final server = [_record('a', 'vecchio.pdf'), _record('upload-1', 'nuovo.pdf')];

    final merged = mergeRecentRecords(server, [saved]);

    expect(merged.map((r) => r.id), ['a', 'upload-1']);
  });

  test('when the server has not caught up yet, the saved record still appears', () {
    final saved = _record('upload-2', 'appena caricato.pdf');

    final merged = mergeRecentRecords(const [], [saved]);

    expect(merged.single.title, 'appena caricato.pdf');
  });

  test('the copy saved this session wins over the server row of the same id', () {
    // An older schema stores no category: the server row comes back as a
    // document, but the owner filed it as a vaccine.
    final saved = const MedicalRecordEntry(
      id: 'upload-3',
      petName: 'Moka',
      title: 'Rabbia',
      subtitle: '',
      meta: '',
      badge: '',
      detailSource: '',
      createdAt: '',
      category: RecordCategory.vaccine,
      timeline: const [],
    );
    final server = [_record('upload-3', 'Rabbia'), _record('a', 'vecchio.pdf')];

    final merged = mergeRecentRecords(server, [saved]);

    expect(merged.map((r) => r.id), ['upload-3', 'a']);
    expect(merged.first.category, RecordCategory.vaccine);
    expect(merged.last.category, RecordCategory.document);
  });

  group('a server row as an entry', () {
    Map<String, dynamic> row({Object? category, Object? eventType}) => {
      'id': 'x',
      'pet_name': 'Moka',
      'title': 'Rabbia',
      'event_date': '2026-03-12',
      if (category != null) 'category': category,
      if (eventType != null) 'event_type': eventType,
    };

    test('takes the category column', () {
      expect(medicalRecordFromRow(row(category: 'exam', eventType: 'document')).category,
          RecordCategory.exam);
    });

    test('falls back to event_type when the category columns do not exist yet', () {
      expect(medicalRecordFromRow(row(eventType: 'vaccine')).category, RecordCategory.vaccine);
    });

    test('anything unknown is a document, and the event date is the calendar day', () {
      final entry = medicalRecordFromRow(row(eventType: 'lab_result'));
      expect(entry.category, RecordCategory.document);
      expect(entry.eventDate, DateTime(2026, 3, 12));
    });
  });
}
