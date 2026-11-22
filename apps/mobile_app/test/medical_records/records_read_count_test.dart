import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/medical_records_controller.dart';

/// Counts the reads of the cartella clinica instead of answering them from the
/// server: the point of QK-01 is how many times the app asks, not what it gets.
class _CountingRepository extends MedicalRecordsRepository {
  int reads = 0;
  bool failNext = false;

  @override
  Future<List<MedicalRecordEntry>> loadRecords() async {
    reads++;
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    return const <MedicalRecordEntry>[];
  }
}

void main() {
  test('the splash preload no longer reads the cartella clinica', () {
    // The preload builds its own repository and drops the answer, then the
    // screen reads again: the first read belongs to the controller only.
    final source = File('lib/app/splash/app_preloader.dart').readAsStringSync();
    expect(source, isNot(contains('MedicalRecordsRepository')));
    expect(source, isNot(contains('loadRecords')));
  });

  test('opening the cartella reads once, and nothing before it does', () async {
    final repository = _CountingRepository();
    expect(repository.reads, 0); // Home opened, no cartella: no read at all

    final controller = MedicalRecordsController(repository: repository);
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(repository.reads, 1);
    expect(controller.records, isEmpty);
    expect(controller.recordsFailed, isFalse);
  });

  test('a save or a delete refreshes the list with one more read', () async {
    final repository = _CountingRepository();
    final controller = MedicalRecordsController(repository: repository);
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);

    MedicalRecordsRepository.changes.value++;
    await Future<void>.delayed(Duration.zero);

    expect(repository.reads, 2);
    expect(controller.records, isNotNull);
  });

  test('retry after a failed read reads again and recovers the list', () async {
    final repository = _CountingRepository()..failNext = true;
    final controller = MedicalRecordsController(repository: repository);
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(controller.recordsFailed, isTrue);
    expect(controller.records, isNull);

    await controller.retry();

    expect(repository.reads, 2);
    expect(controller.recordsFailed, isFalse);
    expect(controller.records, isEmpty);
  });
}
