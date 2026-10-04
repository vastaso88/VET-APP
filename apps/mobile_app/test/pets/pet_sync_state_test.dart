import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';

void main() {
  test('in local-only mode a created pet is saved, not flagged as unsynced', () async {
    final pet = await PetDemoStore.instance.create(
      name: 'Locale',
      species: 'Cane',
      breed: null,
      birthDate: DateTime(2021, 1, 1),
      sex: 'Maschio',
      identityColor: const Color(0xFF163A35),
    );

    expect(PetDemoStore.instance.isUnsynced(pet.id), isFalse);
    expect(await PetDemoStore.instance.retrySync(pet.id), isTrue);
  });

  test('deleting a pet in local-only mode removes it from the list', () async {
    final pet = await PetDemoStore.instance.create(
      name: 'Da cancellare',
      species: 'Gatto',
      breed: null,
      birthDate: DateTime(2022, 1, 1),
      sex: 'Femmina',
      identityColor: const Color(0xFF163A35),
    );

    await PetDemoStore.instance.delete(pet.id);

    expect(PetDemoStore.instance.list().any((p) => p.id == pet.id), isFalse);
  });
}
