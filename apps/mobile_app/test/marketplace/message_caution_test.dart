import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/marketplace/domain/message_caution.dart';

/// The same cases the backend runs (tests/unit/test_marketplace_message_text.py):
/// the app and the backend must give the same answer.
void main() {
  final fixture = File('../../tests/fixtures/marketplace_message_caution_cases.json');
  final cases = jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
  List<String> read(String key) => (cases[key] as List<dynamic>).cast<String>();

  test('the shared cases are there', () {
    expect(read('caution').length, greaterThanOrEqualTo(30));
    expect(read('fine').length, greaterThanOrEqualTo(25));
  });

  for (final text in read('caution')) {
    test('a contact or a code: $text', () => expect(messageNeedsCaution(text), isTrue));
  }
  for (final text in read('fine')) {
    test('an ordinary message: $text', () => expect(messageNeedsCaution(text), isFalse));
  }
}
