import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/data/dog_walks_repository.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';

WalkSession _walk(String id, {bool isFavorite = false, double distanceMeters = 500}) {
  return WalkSession(
    id: id,
    ownerId: 'user-1',
    petId: 'pet-1',
    status: WalkStatus.completed,
    startedAt: DateTime(2026, 1, 1),
    distanceMeters: distanceMeters,
    isFavorite: isFavorite,
  );
}

void main() {
  group('mergeRemoteAndLocalWalks (2026-10-01 bug: a failed remote write silently reverted a '
      'local favorite/delete on the next reload)', () {
    test('a pending-unsynced local write wins over a stale remote copy of the same id', () {
      final remoteStale = _walk('walk-1'); // remote still has isFavorite: false
      final localFresh = _walk('walk-1', isFavorite: true); // the just-applied local edit

      final merged = mergeRemoteAndLocalWalks(
        remote: [remoteStale],
        local: [localFresh],
        localById: {'walk-1': localFresh},
        unsyncedIds: {'walk-1'},
        pendingDeleteIds: {},
      );

      expect(merged, hasLength(1));
      expect(merged.single.isFavorite, isTrue, reason: 'the local edit must not be reverted');
    });

    test('once synced (not in unsyncedIds), remote is trusted again', () {
      final remote = _walk('walk-1', isFavorite: true);
      final local = _walk('walk-1', isFavorite: true);

      final merged = mergeRemoteAndLocalWalks(
        remote: [remote],
        local: [local],
        localById: {'walk-1': local},
        unsyncedIds: {},
        pendingDeleteIds: {},
      );

      expect(merged.single.isFavorite, isTrue);
    });

    test('a pending delete hides the id even though remote still returns it', () {
      final stillOnRemote = _walk('walk-to-delete');

      final merged = mergeRemoteAndLocalWalks(
        remote: [stillOnRemote],
        local: const [],
        localById: const {},
        unsyncedIds: {},
        pendingDeleteIds: {'walk-to-delete'},
      );

      expect(merged, isEmpty, reason: 'a locally-deleted walk must not reappear from a stale remote');
    });

    test('a local-only walk remote has never seen is still included', () {
      final localOnly = _walk('walk-local-only');

      final merged = mergeRemoteAndLocalWalks(
        remote: const [],
        local: [localOnly],
        localById: {'walk-local-only': localOnly},
        unsyncedIds: {},
        pendingDeleteIds: {},
      );

      expect(merged.map((w) => w.id), contains('walk-local-only'));
    });
  });

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
