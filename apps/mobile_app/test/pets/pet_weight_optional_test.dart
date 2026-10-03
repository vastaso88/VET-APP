import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';

void main() {
  test('a pet created without a weight stores an empty weight label, not a fabricated one', () async {
    final pet = await PetDemoStore.instance.create(
      name: 'Senza peso',
      species: 'Cane',
      breed: null,
      birthDate: DateTime(2020, 5, 1),
      sex: 'Sconosciuto',
      weightKg: null,
      identityColor: const Color(0xFF163A35),
    );

    expect(pet.weightLabel, '');
  });

  test('a pet created with a weight keeps its formatted label', () async {
    final pet = await PetDemoStore.instance.create(
      name: 'Con peso',
      species: 'Cane',
      breed: null,
      birthDate: DateTime(2020, 5, 1),
      sex: 'Sconosciuto',
      weightKg: 18.4,
      identityColor: const Color(0xFF163A35),
    );

    expect(pet.weightLabel, '18,4 kg');
  });
}
