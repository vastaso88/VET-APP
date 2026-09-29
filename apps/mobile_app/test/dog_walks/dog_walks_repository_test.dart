import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/data/dog_walks_repository.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';

void main() {
  test('deleteWalk removes the walk from the local fallback list', () async {
    final repository = DogWalksRepository();
    final walk = WalkSession(
      id: 'walk-to-delete-${DateTime.now().microsecondsSinceEpoch}',
      ownerId: 'user-delete-test',
      petId: 'pet-1',
      status: WalkStatus.completed,
      startedAt: DateTime.now(),
      distanceMeters: 500,
    );
    await repository.saveWalk(walk);
    expect(
      (await repository.loadWalks('user-delete-test')).map((w) => w.id),
      contains(walk.id),
    );

    await repository.deleteWalk('user-delete-test', walk.id);

    expect(
      (await repository.loadWalks('user-delete-test')).map((w) => w.id),
      isNot(contains(walk.id)),
    );
  });

  test('deleteWalk only removes the walk for the matching owner', () async {
    final repository = DogWalksRepository();
    final walk = WalkSession(
      id: 'walk-owner-guard-${DateTime.now().microsecondsSinceEpoch}',
      ownerId: 'owner-a',
      petId: 'pet-1',
      status: WalkStatus.completed,
      startedAt: DateTime.now(),
      distanceMeters: 500,
    );
    await repository.saveWalk(walk);

    await repository.deleteWalk('owner-b', walk.id);

    expect(
      (await repository.loadWalks('owner-a')).map((w) => w.id),
      contains(walk.id),
    );
  });
}
