import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/badges.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';

WalkSession _completedWalk(String petId, {double distanceMeters = 500}) {
  return WalkSession(
    id: 'walk-${DateTime.now().microsecondsSinceEpoch}-${distanceMeters.toStringAsFixed(0)}',
    ownerId: 'user-1',
    petId: petId,
    status: WalkStatus.completed,
    startedAt: DateTime.now(),
    distanceMeters: distanceMeters,
  );
}

void main() {
  test('no completed walks yields no badges', () {
    final inProgress = WalkSession(
      id: 'walk-1',
      ownerId: 'user-1',
      petId: 'pet-1',
      status: WalkStatus.inProgress,
      startedAt: DateTime.now(),
    );

    expect(evaluateBadges([inProgress]), isEmpty);
  });

  test('first completed walk unlocks the first-walk badge for that pet', () {
    final badges = evaluateBadges([_completedWalk('pet-1')]);

    expect(badges, ['first_walk_pet_pet-1']);
  });

  test('badges are tracked separately per pet', () {
    final badges = evaluateBadges([_completedWalk('pet-1'), _completedWalk('pet-2')]);

    expect(badges, containsAll(['first_walk_pet_pet-1', 'first_walk_pet_pet-2']));
  });

  test('crossing a distance threshold unlocks that badge but not a higher one', () {
    final walks = List.generate(2, (_) => _completedWalk('pet-1', distanceMeters: 6000));

    final badges = evaluateBadges(walks);

    expect(badges, contains('distance_10km_pet_pet-1'));
    expect(badges, isNot(contains('distance_50km_pet_pet-1')));
  });

  test('crossing a higher distance threshold keeps the lower ones too', () {
    final walks = [_completedWalk('pet-1', distanceMeters: 60000)];

    final badges = evaluateBadges(walks);

    expect(badges, containsAll(['distance_10km_pet_pet-1', 'distance_50km_pet_pet-1']));
    expect(badges, isNot(contains('distance_100km_pet_pet-1')));
  });

  test('crossing a walk-count threshold unlocks that badge', () {
    final walks = List.generate(10, (_) => _completedWalk('pet-1', distanceMeters: 100));

    final badges = evaluateBadges(walks);

    expect(badges, contains('walks_10_pet_pet-1'));
    expect(badges, isNot(contains('walks_30_pet_pet-1')));
  });

  test('in-progress and discarded walks do not count toward badges', () {
    final walks = [
      _completedWalk('pet-1', distanceMeters: 100),
      WalkSession(
        id: 'walk-in-progress',
        ownerId: 'user-1',
        petId: 'pet-1',
        status: WalkStatus.inProgress,
        startedAt: DateTime.now(),
        distanceMeters: 50000,
      ),
      WalkSession(
        id: 'walk-discarded',
        ownerId: 'user-1',
        petId: 'pet-1',
        status: WalkStatus.discarded,
        startedAt: DateTime.now(),
        distanceMeters: 50000,
      ),
    ];

    final badges = evaluateBadges(walks);

    expect(badges, ['first_walk_pet_pet-1']);
    expect(badges, isNot(contains('distance_10km_pet_pet-1')));
  });
}
