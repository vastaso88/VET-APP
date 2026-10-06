import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';

void main() {
  test('loadReminders hides seed reminders for pets the owner does not have', () async {
    final repository = RemindersRepository();

    final withoutPets = await repository.loadReminders();
    expect(withoutPets.where((r) => r.petName == 'Moka'), isEmpty);

    await PetDemoStore.instance.create(
      name: 'Moka',
      species: 'Cane',
      breed: null,
      birthDate: null,
      sex: 'Femmina',
      identityColor: Colors.teal,
    );

    final withMoka = await repository.loadReminders();
    expect(withMoka.where((r) => r.petName == 'Moka'), isNotEmpty);
    expect(withMoka.where((r) => r.petName == 'Oliver'), isEmpty);
  });
}
