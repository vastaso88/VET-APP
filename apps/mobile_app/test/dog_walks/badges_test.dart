import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/badges.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';

// Fixed at a mid-afternoon hour, not DateTime.now() - these tests don't
// care about time-of-day, but the dawn/night badges do (badges.dart), so a
// real "now" made this suite flaky depending on when it happened to run
// (2026-10-01: failed overnight because DateTime.now() fell in the night
// badge's hour range).
final _fixedMiddayMoment = DateTime(2026, 1, 1, 13);
var _walkCounter = 0;

WalkSession _completedWalk(String petId, {double distanceMeters = 500}) {
  return WalkSession(
    id: 'walk-${_walkCounter++}',
    ownerId: 'user-1',
    petId: petId,
    status: WalkStatus.completed,
    startedAt: _fixedMiddayMoment,
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
    final badges =
        evaluateBadges([_completedWalk('pet-1'), _completedWalk('pet-2')]);

    expect(
        badges, containsAll(['first_walk_pet_pet-1', 'first_walk_pet_pet-2']));
  });

  test('crossing a distance threshold unlocks that badge but not a higher one',
      () {
    final walks =
        List.generate(2, (_) => _completedWalk('pet-1', distanceMeters: 6000));

    final badges = evaluateBadges(walks);

    expect(badges, contains('distance_10km_pet_pet-1'));
    expect(badges, isNot(contains('distance_50km_pet_pet-1')));
  });

  test('crossing a higher distance threshold keeps the lower ones too', () {
    final walks = [_completedWalk('pet-1', distanceMeters: 60000)];

    final badges = evaluateBadges(walks);

    expect(badges,
        containsAll(['distance_10km_pet_pet-1', 'distance_50km_pet_pet-1']));
    expect(badges, isNot(contains('distance_100km_pet_pet-1')));
  });

  test('crossing a walk-count threshold unlocks that badge', () {
    final walks =
        List.generate(10, (_) => _completedWalk('pet-1', distanceMeters: 100));

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

  test('a single walk of at least 30 minutes unlocks the 30-minute badge', () {
    final walk = WalkSession(
      id: 'walk-30min',
      ownerId: 'user-1',
      petId: 'pet-1',
      status: WalkStatus.completed,
      startedAt: DateTime(2026, 1, 1, 10),
      durationSeconds: 30 * 60,
    );

    final badges = evaluateBadges([walk]);

    expect(badges, contains('duration_30min_pet_pet-1'));
    expect(badges, isNot(contains('duration_1h_pet_pet-1')));
  });

  test('a single walk of at least an hour unlocks both duration badges', () {
    final walk = WalkSession(
      id: 'walk-1h',
      ownerId: 'user-1',
      petId: 'pet-1',
      status: WalkStatus.completed,
      startedAt: DateTime(2026, 1, 1, 10),
      durationSeconds: 60 * 60,
    );

    final badges = evaluateBadges([walk]);

    expect(badges,
        containsAll(['duration_30min_pet_pet-1', 'duration_1h_pet_pet-1']));
  });

  test('a walk starting at dawn unlocks the dawn badge, not the night one', () {
    final walk = WalkSession(
      id: 'walk-dawn',
      ownerId: 'user-1',
      petId: 'pet-1',
      status: WalkStatus.completed,
      startedAt: DateTime(2026, 1, 1, 6, 30),
    );

    final badges = evaluateBadges([walk]);

    expect(badges, contains('dawn_walk_pet_pet-1'));
    expect(badges, isNot(contains('night_walk_pet_pet-1')));
  });

  test('a walk starting late at night unlocks the night badge', () {
    final walk = WalkSession(
      id: 'walk-night',
      ownerId: 'user-1',
      petId: 'pet-1',
      status: WalkStatus.completed,
      startedAt: DateTime(2026, 1, 1, 22),
    );

    final badges = evaluateBadges([walk]);

    expect(badges, contains('night_walk_pet_pet-1'));
    expect(badges, isNot(contains('dawn_walk_pet_pet-1')));
  });

  test('a walk just after midnight also counts as a night walk', () {
    final walk = WalkSession(
      id: 'walk-after-midnight',
      ownerId: 'user-1',
      petId: 'pet-1',
      status: WalkStatus.completed,
      startedAt: DateTime(2026, 1, 1, 2),
    );

    final badges = evaluateBadges([walk]);

    expect(badges, contains('night_walk_pet_pet-1'));
  });

  test('a walk in the middle of the day unlocks neither time-of-day badge', () {
    final walk = WalkSession(
      id: 'walk-midday',
      ownerId: 'user-1',
      petId: 'pet-1',
      status: WalkStatus.completed,
      startedAt: DateTime(2026, 1, 1, 13),
    );

    final badges = evaluateBadges([walk]);

    expect(badges, isNot(contains('dawn_walk_pet_pet-1')));
    expect(badges, isNot(contains('night_walk_pet_pet-1')));
  });

  test('seven walks on seven consecutive days unlock the streak badge', () {
    final walks = List.generate(
      7,
      (index) => WalkSession(
        id: 'walk-streak-$index',
        ownerId: 'user-1',
        petId: 'pet-1',
        status: WalkStatus.completed,
        startedAt: DateTime(2026, 1, 1 + index, 8),
      ),
    );

    final badges = evaluateBadges(walks);

    expect(badges, contains('streak_7days_pet_pet-1'));
  });

  test('a gap in the days breaks the streak', () {
    final walks = [
      for (var day = 1; day <= 6; day++)
        WalkSession(
          id: 'walk-streak-$day',
          ownerId: 'user-1',
          petId: 'pet-1',
          status: WalkStatus.completed,
          startedAt: DateTime(2026, 1, day, 8),
        ),
      WalkSession(
        id: 'walk-after-gap',
        ownerId: 'user-1',
        petId: 'pet-1',
        status: WalkStatus.completed,
        startedAt: DateTime(2026, 1, 8, 8),
      ),
    ];

    final badges = evaluateBadges(walks);

    expect(badges, isNot(contains('streak_7days_pet_pet-1')));
  });

  test('two walks on the same day only count once toward the streak', () {
    final walks = [
      for (var day = 1; day <= 6; day++)
        WalkSession(
          id: 'walk-streak-$day',
          ownerId: 'user-1',
          petId: 'pet-1',
          status: WalkStatus.completed,
          startedAt: DateTime(2026, 1, day, 8),
        ),
      WalkSession(
        id: 'walk-day-6-again',
        ownerId: 'user-1',
        petId: 'pet-1',
        status: WalkStatus.completed,
        startedAt: DateTime(2026, 1, 6, 18),
      ),
    ];

    final badges = evaluateBadges(walks);

    expect(badges, isNot(contains('streak_7days_pet_pet-1')));
  });
}
