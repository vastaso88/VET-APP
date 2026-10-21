import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/monitoring/data/weight_measurements_repository.dart';
import 'package:vet_app_mobile/features/monitoring/domain/body_condition.dart';
import 'package:vet_app_mobile/features/monitoring/domain/weight_measurement.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';

Future<PetProfile> _newPet({double? weightKg, String species = 'Cane'}) =>
    PetDemoStore.instance.create(
      name: 'Prova',
      species: species,
      breed: null,
      birthDate: DateTime(2020, 5, 1),
      sex: 'Sconosciuto',
      weightKg: weightKg,
      identityColor: const Color(0xFF163A35),
    );

void main() {
  late WeightMeasurementsRepository repository;

  setUp(() {
    WeightMeasurementsRepository.resetForTest();
    repository = WeightMeasurementsRepository(ownerIdResolver: () => 'owner-1');
  });

  test('add, edit and delete a weighing', () async {
    final pet = await _newPet();
    final first = repository.create(
      petId: pet.id,
      measuredOn: DateTime(2026, 10, 1, 17, 30),
      weightKg: 12.0,
      bodyCondition: BodyCondition.normal,
      note: '  dopo la passeggiata ',
    );

    expect(await repository.add(first), isTrue);
    var list = await repository.load(pet.id);
    expect(list, hasLength(1));
    expect(list.single.measuredOn, DateTime(2026, 10, 1));
    expect(list.single.ownerId, 'owner-1');
    expect(list.single.note, 'dopo la passeggiata');

    expect(
        await repository
            .update(first.copyWith(weightKg: 12.4, clearBodyCondition: true)),
        isTrue);
    list = await repository.load(pet.id);
    expect(list.single.weightKg, 12.4);
    expect(list.single.bodyCondition, isNull);

    expect(await repository.delete(first), isTrue);
    expect(await repository.load(pet.id), isEmpty);
  });

  test('every change ticks the notifier so open pages reload', () async {
    final pet = await _newPet();
    final before = WeightMeasurementsRepository.changes.value;

    await repository.add(
      repository.create(
          petId: pet.id, measuredOn: DateTime(2026, 10, 1), weightKg: 5),
    );

    expect(WeightMeasurementsRepository.changes.value, before + 1);
  });

  test('the weighings of one pet are not mixed with another pet', () async {
    await repository.add(
      repository.create(
          petId: 'pet-a', measuredOn: DateTime(2026, 10, 1), weightKg: 5),
    );

    expect(await repository.load('pet-a'), hasLength(1));
    expect(await repository.load('pet-b'), isEmpty);
  });

  test('the latest weighing becomes the weight of the pet profile', () async {
    final pet = await _newPet(weightKg: 10);
    final older = repository.create(
        petId: pet.id, measuredOn: DateTime(2026, 9, 1), weightKg: 11);
    final newer = repository.create(
        petId: pet.id, measuredOn: DateTime(2026, 10, 1), weightKg: 12.34);

    await repository.add(older);
    expect(PetDemoStore.instance.byId(pet.id)!.weightLabel, '11 kg');

    await repository.add(newer);
    expect(PetDemoStore.instance.byId(pet.id)!.weightLabel, '12,34 kg');

    // Taking the newest away goes back to the one before; none left, no weight.
    await repository.delete(newer);
    expect(PetDemoStore.instance.byId(pet.id)!.weightLabel, '11 kg');
    await repository.delete(older);
    expect(PetDemoStore.instance.byId(pet.id)!.weightLabel, '');
  });

  test('a tiny pet weight is written in grams on the profile', () async {
    final pet = await _newPet(species: 'Uccello');
    await repository.add(
      repository.create(
          petId: pet.id, measuredOn: DateTime(2026, 10, 1), weightKg: 0.032),
    );

    expect(PetDemoStore.instance.byId(pet.id)!.weightLabel, '32 g');
  });

  test('rows come back to the same weighing', () {
    final measurement = WeightMeasurement(
      id: 'wm-1',
      petId: 'p',
      ownerId: 'o',
      measuredOn: DateTime(2026, 10, 14),
      weightKg: 23.5,
      bodyCondition: BodyCondition.slightlyOverweight,
      note: 'ok',
    );

    final row = measurement.toRow();
    expect(row['measured_at'], '2026-10-14');
    expect(row['body_condition'], 4);

    final back = WeightMeasurement.fromRow(
        {...row, 'weight_kg': '23.5', 'created_at': '2026-10-14T10:00:00Z'})!;
    expect(back.weightKg, 23.5);
    expect(back.measuredOn, DateTime(2026, 10, 14));
    expect(back.bodyCondition, BodyCondition.slightlyOverweight);
    expect(back.note, 'ok');
  });

  test('a row that cannot be read is skipped, not a crash', () {
    expect(
        WeightMeasurement.fromRow({'id': 'x', 'pet_id': 'p', 'weight_kg': 3}),
        isNull);
    expect(
      WeightMeasurement.fromRow({
        'id': 'x',
        'pet_id': 'p',
        'measured_at': '2026-10-01',
        'weight_kg': 0
      }),
      isNull,
    );
    expect(
      WeightMeasurement.fromRow({
        'id': 'x',
        'pet_id': 'p',
        'measured_at': '2026-10-01',
        'weight_kg': 3,
        'body_condition': 9,
      })!
          .bodyCondition,
      isNull,
    );
  });

  test('fish have no weight monitoring, every other species has', () async {
    expect(
        supportsWeightMonitoring(
            samplePets.firstWhere((p) => p.species == 'Pesce')),
        isFalse);
    expect(
        supportsWeightMonitoring(
            samplePets.firstWhere((p) => p.species == 'Cane')),
        isTrue);
    expect(
        supportsWeightMonitoring(
            samplePets.firstWhere((p) => p.species == 'Uccello')),
        isTrue);
    expect(
        supportsWeightMonitoring(
            samplePets.firstWhere((p) => p.species == 'Rettili e anfibi')),
        isTrue);
  });
}
