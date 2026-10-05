import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';

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
}
