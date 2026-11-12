import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/marketplace/domain/animal_policy.dart';

/// The same cases the backend runs (tests/unit/test_animal_policy.py): the app
/// and the backend must give the same answer.
void main() {
  final fixture = File('../../tests/fixtures/marketplace_animal_policy_cases.json');
  final cases = jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
  List<List<String?>> read(String key) => [
        for (final item in cases[key] as List<dynamic>)
          [(item as List<dynamic>)[0] as String?, item[1] as String?],
      ];

  final blocked = read('blocked');
  final allowed = read('allowed');

  test('the shared corpus is big enough to mean something', () {
    expect(blocked.length, greaterThanOrEqualTo(60));
    expect(allowed.length, greaterThanOrEqualTo(70));
  });

  group('an offer of an animal is blocked', () {
    for (final entry in blocked) {
      test('${entry[0]} | ${entry[1]}', () {
        expect(offersAnimals(entry[0], entry[1]), isTrue);
      });
    }
  });

  group('an accessory is never mistaken for an animal', () {
    for (final entry in allowed) {
      test('${entry[0]} | ${entry[1]}', () {
        expect(offersAnimals(entry[0], entry[1]), isFalse);
      });
    }
  });

  test('whole words only, accents and case do not matter', () {
    for (final text in ['Catalogo accessori', 'Dogma', 'Pugilato guanti', 'Caneva decorativa']) {
      expect(offersAnimals(text), isFalse, reason: text);
    }
    expect(normalizeAnimalPolicyText('Chiots À VENDRE !!'), 'chiots a vendre');
    expect(offersAnimals('CHIOTS À VENDRE'), isTrue);
    expect(offersAnimals('Guinzaglio-per-CANE'), isFalse);
  });

  test('empty and missing texts are fine; the two fields never pair up', () {
    expect(offersAnimals(null, null), isFalse);
    expect(offersAnimals('', ''), isFalse);
    expect(offersAnimals('Vendo', 'cane'), isFalse);
    expect(offersAnimals('Cuccia per cani', 'vendo anche cuccioli'), isTrue);
  });
}
