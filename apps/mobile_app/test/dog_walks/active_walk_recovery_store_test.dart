import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/dog_walks/data/active_walk_recovery_store.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns null when nothing was ever saved', () async {
    expect(await const ActiveWalkRecoveryStore().load(), isNull);
  });

  test('save then load round-trips an in-progress walk', () async {
    const store = ActiveWalkRecoveryStore();
    final walk = WalkSession(
      id: 'walk-1',
      ownerId: 'user-1',
      petId: 'pet-1',
      startedAt: DateTime(2026, 1, 1, 8),
      distanceMeters: 250,
    );

    await store.save(walk);
    final recovered = await store.load();

    expect(recovered, isNotNull);
    expect(recovered!.id, 'walk-1');
    expect(recovered.distanceMeters, 250);
    expect(recovered.status, WalkStatus.inProgress);
  });

  test('load returns null once the saved walk is no longer in progress',
      () async {
    const store = ActiveWalkRecoveryStore();
    final walk = WalkSession(
      id: 'walk-1',
      ownerId: 'user-1',
      petId: 'pet-1',
      status: WalkStatus.completed,
      startedAt: DateTime(2026, 1, 1, 8),
    );

    await store.save(walk);

    expect(await store.load(), isNull);
  });

  test('clear removes the saved snapshot', () async {
    const store = ActiveWalkRecoveryStore();
    await store.save(
      WalkSession(
        id: 'walk-1',
        ownerId: 'user-1',
        petId: 'pet-1',
        startedAt: DateTime(2026, 1, 1, 8),
      ),
    );

    await store.clear();

    expect(await store.load(), isNull);
  });
}
