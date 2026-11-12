import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/monitoring/data/weight_measurements_repository.dart';
import 'package:vet_app_mobile/features/monitoring/domain/body_condition.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_details.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_value_labels.dart';

void main() {
  test('profile code and weighing level are the same scale and round-trip', () {
    expect(BodyCondition.codes, [
      'very_thin',
      'thin',
      'normal',
      'slightly_overweight',
      'overweight',
    ]);
    for (final condition in BodyCondition.values) {
      expect(BodyCondition.fromCode(condition.code), condition);
      expect(BodyCondition.fromScore(condition.score), condition);
      expect(BodyCondition.fromScore(condition.score)!.code, condition.code);
    }
    expect(BodyCondition.fromScore(1), BodyCondition.veryThin);
    expect(BodyCondition.fromScore(5), BodyCondition.overweight);
    expect(BodyCondition.fromScore(0), isNull);
    expect(BodyCondition.fromScore(6), isNull);
    expect(BodyCondition.fromCode('chubby'), isNull);
    expect(BodyCondition.fromCode(null), isNull);
  });

  test('the profile uses the shared codes and the shared labels', () {
    expect(petBodyConditions, BodyCondition.codes);
    for (final condition in BodyCondition.values) {
      expect(localizedBodyConditionLabel(condition.code), condition.label);
    }
    expect(localizedBodyConditionLabel('leggermente così'), 'leggermente così');
    expect(BodyCondition.slightlyOverweight.label, 'Leggermente sovrappeso');
  });

  test('a weighing with a condition becomes the profile corporatura', () async {
    WeightMeasurementsRepository.resetForTest();
    final repository =
        WeightMeasurementsRepository(ownerIdResolver: () => 'owner-1');
    final pet = await PetDemoStore.instance.create(
      name: 'Prova',
      species: 'Cane',
      breed: null,
      birthDate: DateTime(2020, 5, 1),
      sex: 'Sconosciuto',
      identityColor: const Color(0xFF163A35),
    );
    await PetDemoStore.instance.upsert(pet.copyWith(bodyCondition: 'thin'));

    // A weighing without a condition leaves the owner's estimate alone.
    await repository.add(repository.create(
      petId: pet.id,
      measuredOn: DateTime(2026, 9, 1),
      weightKg: 10,
    ));
    expect(PetDemoStore.instance.byId(pet.id)!.bodyCondition, 'thin');

    await repository.add(repository.create(
      petId: pet.id,
      measuredOn: DateTime(2026, 10, 1),
      weightKg: 11,
      bodyCondition: BodyCondition.slightlyOverweight,
    ));
    expect(PetDemoStore.instance.byId(pet.id)!.bodyCondition,
        'slightly_overweight');

    // A later weighing without one does not erase it.
    await repository.add(repository.create(
      petId: pet.id,
      measuredOn: DateTime(2026, 10, 10),
      weightKg: 11.2,
    ));
    expect(PetDemoStore.instance.byId(pet.id)!.bodyCondition,
        'slightly_overweight');
    expect(
      (await repository.latestWithCondition(pet.id))!.bodyCondition,
      BodyCondition.slightlyOverweight,
    );
  });

  group('profile edit form', () {
    late WeightMeasurementsRepository repository;

    setUp(() {
      WeightMeasurementsRepository.resetForTest();
      repository =
          WeightMeasurementsRepository(ownerIdResolver: () => 'owner-1');
    });

    Future<PetProfile> newPet({String species = 'Cane', double? weightKg}) =>
        PetDemoStore.instance.create(
          name: 'Prova',
          species: species,
          breed: null,
          birthDate: DateTime(2020, 5, 1),
          sex: 'Sconosciuto',
          weightKg: weightKg,
          identityColor: const Color(0xFF163A35),
        );

    test(
        'changing only the corporatura records one weighing with the profile weight',
        () async {
      final before = await newPet(weightKg: 12);
      final after = await PetDemoStore.instance
          .upsert(before.copyWith(bodyCondition: 'overweight'));

      final recorded =
          await repository.recordProfileEdit(before: before, after: after);

      final list = await repository.load(before.id);
      expect(recorded, isTrue);
      expect(list, hasLength(1));
      expect(list.single.weightKg, 12);
      expect(list.single.bodyCondition, BodyCondition.overweight);
    });

    test(
        'changing weight and corporatura together records ONE weighing with both',
        () async {
      final before = await newPet(weightKg: 12);
      final after = await PetDemoStore.instance.upsert(
        before.copyWith(weightLabel: '13 kg', bodyCondition: 'thin'),
      );

      await repository.recordProfileEdit(
          before: before, after: after, newWeightKg: 13);

      final list = await repository.load(before.id);
      expect(list, hasLength(1));
      expect(list.single.weightKg, 13);
      expect(list.single.bodyCondition, BodyCondition.thin);
    });

    test('changing only the weight records a weighing without corporatura',
        () async {
      final before = await newPet(weightKg: 12);
      final after = await PetDemoStore.instance
          .upsert(before.copyWith(weightLabel: '13 kg', bodyCondition: null));

      await repository.recordProfileEdit(
          before: before, after: after, newWeightKg: 13);

      final list = await repository.load(before.id);
      expect(list.single.bodyCondition, isNull);
    });

    test('nothing changed, no weight to use, or a fish: no weighing', () async {
      final same = await newPet(weightKg: 12);
      expect(
          await repository.recordProfileEdit(
              before: same, after: same, newWeightKg: 12),
          isFalse);

      final noWeight = await newPet();
      final noWeightAfter = await PetDemoStore.instance
          .upsert(noWeight.copyWith(bodyCondition: 'thin'));
      expect(
          await repository.recordProfileEdit(
              before: noWeight, after: noWeightAfter),
          isFalse);
      expect(PetDemoStore.instance.byId(noWeight.id)!.bodyCondition, 'thin');

      final fish = await newPet(species: 'Pesce', weightKg: 1);
      final fishAfter = await PetDemoStore.instance
          .upsert(fish.copyWith(bodyCondition: 'thin'));
      expect(await repository.recordProfileEdit(before: fish, after: fishAfter),
          isFalse);
      expect(await repository.load(fish.id), isEmpty);
    });
  });
}
