import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/application/memorial_service.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_format.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';

/// Moving a pet to Ricordi stays possible without a plan (owner decision
/// 2026-11-16): the database lets through exactly one change on `pet_profiles`,
/// `is_memorial` from false to true with the date of the loss
/// (scripts/setup/plan_access_rules.sql, `plan_access_move_gate`; tests in
/// tests/unit/test_memorial_move_without_plan.py). This checks that what the app
/// writes is what that rule asks for, and that the way back is not the same write.
/// Synthetic data only.
PetProfile _pet(String id, {bool memorial = false}) => PetProfile(
      id: id,
      name: 'Moka',
      species: 'Cane',
      breed: '',
      birthDateLabel: '',
      sex: 'Femmina',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'M',
      accentColor: Colors.white,
      identityColor: Colors.green,
      isMemorial: memorial,
    );

MemorialService _service() => MemorialService(
      store: PetDemoStore.instance,
      stopWalkOf: (_) async {},
      revokeRecordsConsent: (_) async {},
      onMoved: (_) {},
      onRestored: () {},
      planLimit: () => (limit: null, upgradePlan: null),
      memorialLimit: () => null,
    );

void main() {
  setUp(PetDemoStore.instance.reset);
  tearDown(() => PetDemoStore.instance.debugUpsertRow = null);

  test('the move writes is_memorial true with the date of the loss, in one row', () async {
    final store = PetDemoStore.instance;
    final pet = await store.upsert(_pet('a'));
    final rows = <Map<String, dynamic>>[];
    store.debugUpsertRow = (row) async => rows.add(row);

    await _service().moveToMemories(pet, lossDate: DateTime(2026, 11, 3));

    final row = rows.single;
    expect(row['id'], 'a');
    expect(row['is_memorial'], isTrue);
    // The rule refuses a move without the date: the app always sends it.
    final label = row['memorial_date_label'] as String?;
    expect(label, isNotNull);
    expect(label!.trim(), isNotEmpty);
    expect(parsePetBirthDateLabel(label), DateTime(2026, 11, 3));
  });

  test('the way back is a different write: is_memorial false, no date', () async {
    final store = PetDemoStore.instance;
    final memorial = await store.upsert(_pet('m', memorial: true));
    final rows = <Map<String, dynamic>>[];
    store.debugUpsertRow = (row) async => rows.add(row);

    await _service().restore(memorial);

    expect(rows.single['is_memorial'], isFalse, reason: 'refused without a plan, as any write');
    expect(rows.single['memorial_date_label'], isNull);
  });

  test('a pet is never created in Ricordi: a new pet is written as active', () async {
    final store = PetDemoStore.instance;
    final rows = <Map<String, dynamic>>[];
    store.debugUpsertRow = (row) async => rows.add(row);

    await store.upsert(_pet('new'));

    expect(rows.single['is_memorial'], isFalse);
  });
}
