import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';

void main() {
  test('a timestamptz from the server becomes a readable local date, not raw ISO', () {
    final stored = DateTime(2026, 3, 25, 9, 32).toUtc().toIso8601String();
    expect(formatStoredRecordDate(stored), '25 mar 2026, 09:32');
  });

  test('an unparseable value is shown as-is rather than hidden', () {
    expect(formatStoredRecordDate('non una data'), 'non una data');
    expect(formatStoredRecordDate(null), '');
  });
}
