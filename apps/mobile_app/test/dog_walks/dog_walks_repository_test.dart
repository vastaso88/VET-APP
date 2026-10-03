import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/data/dog_walks_repository.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';

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
        deletedIds: {},
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
        deletedIds: {},
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
        deletedIds: {},
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
        deletedIds: {},
      );

      expect(merged.map((w) => w.id), contains('walk-local-only'));
    });

    test('a deleted id is excluded even if a stale copy still shows up in both remote and local', () {
      // Reproduces the 2026-10-01 edge-log finding: a confirmed (204)
      // delete was followed by pruneRoutesOutsideRetention (or anything
      // else holding a pre-delete snapshot) writing the walk straight
      // back. deletedIds must win over both sources unconditionally.
      final staleRemote = _walk('walk-deleted');
      final staleLocal = _walk('walk-deleted');

      final merged = mergeRemoteAndLocalWalks(
        remote: [staleRemote],
        local: [staleLocal],
        localById: {'walk-deleted': staleLocal},
        unsyncedIds: {'walk-deleted'}, // even if it looks "unsynced"
        pendingDeleteIds: {},
        deletedIds: {'walk-deleted'},
      );

      expect(merged, isEmpty);
    });
  });

  test(
    'clearRoute never regresses a field it does not own, even from a snapshot read before a '
    'concurrent toggle (owner report, 2026-10-01: un-favoriting, then a concurrent prune pass, '
    'silently reverted the favorite)',
    () async {
      final repository = DogWalksRepository();
      final walk = WalkSession(
        id: 'walk-stale-prune-${DateTime.now().microsecondsSinceEpoch}',
        ownerId: 'owner-stale-prune-test',
        petId: 'pet-1',
        status: WalkStatus.completed,
        startedAt: DateTime.now(),
        distanceMeters: 500,
        isFavorite: true,
        route: [
          RoutePoint(coordinates: const Coordinates(latitude: 45.46, longitude: 9.19), recordedAt: DateTime.now()),
        ],
      );

      await repository.saveWalk(walk); // is_favorite: true, has a route
      // Stands in for pruneRoutesOutsideRetention having already read this
      // walk before the toggle below happens - `walk` is never re-read.
      final staleSnapshot = walk;

      await repository.saveWalk(walk.copyWith(isFavorite: false)); // the user's toggle

      // The maintenance pass now decides this walk's route should go,
      // using only the pre-toggle snapshot's id/owner - never its stale
      // isFavorite.
      await repository.clearRoute(staleSnapshot.ownerId, staleSnapshot.id);

      final reloaded = await repository.loadWalks('owner-stale-prune-test');
      final current = reloaded.firstWhere((w) => w.id == walk.id);
      expect(current.isFavorite, isFalse, reason: 'clearRoute must not revert a field it does not own');
      expect(current.route, isEmpty);
    },
  );

  group('changes notifier (owner report, 2026-10-03: history only refreshed after leaving '
      'the tab and coming back)', () {
    WalkSession walkFor(String suffix, {WalkStatus status = WalkStatus.completed}) {
      return WalkSession(
        id: 'walk-changes-$suffix-${DateTime.now().microsecondsSinceEpoch}',
        ownerId: 'owner-changes-test',
        petId: 'pet-1',
        status: status,
        startedAt: DateTime.now(),
        distanceMeters: 500,
        route: [
          RoutePoint(coordinates: const Coordinates(latitude: 45.46, longitude: 9.19), recordedAt: DateTime.now()),
        ],
      );
    }

    test('ticks when a finished walk is saved, or its favorite flag toggled', () async {
      final repository = DogWalksRepository();
      final walk = walkFor('save');
      final before = DogWalksRepository.changes.value;

      await repository.saveWalk(walk);
      expect(DogWalksRepository.changes.value, before + 1);

      await repository.saveWalk(walk.copyWith(isFavorite: true));
      expect(DogWalksRepository.changes.value, before + 2);
    });

    test('does not tick for saves of a walk still in progress (one per GPS fix)', () async {
      final repository = DogWalksRepository();
      final before = DogWalksRepository.changes.value;

      await repository.saveWalk(walkFor('live', status: WalkStatus.inProgress));

      expect(DogWalksRepository.changes.value, before);
    });

    test('ticks on delete and on clearRoute', () async {
      final repository = DogWalksRepository();
      final walk = walkFor('mutate');
      await repository.saveWalk(walk);
      final before = DogWalksRepository.changes.value;

      await repository.clearRoute(walk.ownerId, walk.id);
      expect(DogWalksRepository.changes.value, before + 1);

      await repository.deleteWalk(walk.ownerId, walk.id);
      expect(DogWalksRepository.changes.value, before + 2);
    });

    test('does not tick when a save is refused because the walk was deleted', () async {
      final repository = DogWalksRepository();
      final walk = walkFor('refused');
      await repository.saveWalk(walk);
      await repository.deleteWalk(walk.ownerId, walk.id);
      final before = DogWalksRepository.changes.value;

      await repository.saveWalk(walk.copyWith(isFavorite: true));

      expect(DogWalksRepository.changes.value, before);
    });

    test('a listener sees the new state when it reloads inside the callback', () async {
      final repository = DogWalksRepository();
      final walk = walkFor('listener');
      var sawWalkOnTick = false;
      void listener() {
        repository.loadWalks('owner-changes-test').then((walks) {
          sawWalkOnTick = walks.any((w) => w.id == walk.id);
        });
      }

      DogWalksRepository.changes.addListener(listener);
      addTearDown(() => DogWalksRepository.changes.removeListener(listener));

      await repository.saveWalk(walk);
      await Future<void>.delayed(Duration.zero);

      expect(sawWalkOnTick, isTrue, reason: 'local state is updated before the tick fires');
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

  test(
    'exact repro (owner report, 2026-10-01): save, then delete, then a stale write tries to '
    'bring it back - the walk must not reappear, in the list or via a later save',
    () async {
      final repository = DogWalksRepository();
      final walk = WalkSession(
        id: 'walk-resurrection-${DateTime.now().microsecondsSinceEpoch}',
        ownerId: 'owner-resurrection-test',
        petId: 'pet-1',
        status: WalkStatus.completed,
        startedAt: DateTime.now(),
        distanceMeters: 500,
        isFavorite: true,
      );

      await repository.saveWalk(walk);
      await repository.deleteWalk('owner-resurrection-test', walk.id);

      // Stands in for pruneRoutesOutsideRetention (or any other code) that
      // read `walk` before the delete and only now gets around to writing
      // it back, unaware it was deleted in the meantime.
      await repository.saveWalk(walk.copyWith(route: const []));

      final walks = await repository.loadWalks('owner-resurrection-test');
      expect(
        walks.map((w) => w.id),
        isNot(contains(walk.id)),
        reason: 'a deleted walk must not come back from a stale save',
      );
    },
  );

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
