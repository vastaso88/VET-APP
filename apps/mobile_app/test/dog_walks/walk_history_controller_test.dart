import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/data/dog_walks_repository.dart';
import 'package:vet_app_mobile/features/dog_walks/data/walk_history_controller.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';

const _petId = 'history-pet';

/// A repository whose "remote" can be held back and made to refuse: the local
/// side of every write runs for real (and announces its change) first, then
/// the call waits for [hold] and reports [accept] - exactly the window in
/// which the owner is looking at the screen.
class _SlowRepository extends DogWalksRepository {
  Completer<void>? hold;
  bool accept = true;

  /// While set, [loadWalks] returns its (stale) snapshot only once this
  /// completes.
  Completer<void>? loadHold;
  List<WalkSession>? staleSnapshot;

  @override
  Future<List<WalkSession>> loadWalks(String ownerId) async {
    final gate = loadHold;
    final snapshot = staleSnapshot;
    if (gate != null && snapshot != null) {
      await gate.future;
      return snapshot;
    }
    return super.loadWalks(ownerId);
  }

  @override
  Future<bool> saveWalk(WalkSession walk, {bool notifyFailure = true}) async {
    await super.saveWalk(walk, notifyFailure: notifyFailure);
    await hold?.future;
    return accept;
  }

  @override
  Future<bool> deleteWalk(String ownerId, String walkId, {bool notifyFailure = true}) async {
    await super.deleteWalk(ownerId, walkId, notifyFailure: notifyFailure);
    await hold?.future;
    return accept;
  }
}

WalkSession _walk(
  String id,
  String ownerId, {
  bool isFavorite = false,
  double distanceMeters = 500,
  int day = 1,
}) {
  return WalkSession(
    id: id,
    ownerId: ownerId,
    petId: _petId,
    status: WalkStatus.completed,
    startedAt: DateTime(2026, 1, day),
    distanceMeters: distanceMeters,
    isFavorite: isFavorite,
  );
}

void main() {
  late _SlowRepository repository;
  late List<String> messages;
  late WalkHistoryController history;
  late String ownerId;
  var counter = 0;

  Future<void> seed(List<WalkSession> walks) async {
    for (final walk in walks) {
      await repository.saveWalk(walk);
    }
    await history.refresh();
  }

  setUp(() {
    counter++;
    ownerId = 'history-owner-$counter';
    repository = _SlowRepository();
    messages = [];
    history = WalkHistoryController(
      petId: _petId,
      repository: repository,
      ownerIdResolver: () => ownerId,
      onMessage: messages.add,
    );
  });

  tearDown(() => history.dispose());

  test('loads the completed walks of the pet, newest first, without zero-distance ones', () async {
    await seed([
      _walk('a', ownerId, day: 1),
      _walk('b', ownerId, day: 3),
      _walk('empty', ownerId, distanceMeters: 0, day: 2),
    ]);

    expect(history.walks!.map((walk) => walk.id), ['b', 'a']);
  });

  test('starring a walk shows at once, before the remote write has finished', () async {
    await seed([_walk('a', ownerId)]);
    repository.hold = Completer<void>();

    final pending = history.setFavorite(history.walks!.single, true);

    expect(history.walks!.single.isFavorite, isTrue, reason: 'visible while the write is in flight');
    repository.hold!.complete();
    await pending;
    await history.settled;

    expect(history.walks!.single.isFavorite, isTrue);
    expect(messages, isEmpty);
  });

  test('a refused star is undone with a message, locally and on screen', () async {
    await seed([_walk('a', ownerId)]);
    repository.accept = false;

    await history.setFavorite(history.walks!.single, true);
    await history.settled;

    expect(history.walks!.single.isFavorite, isFalse);
    expect(messages, hasLength(1));
    final reloaded = await repository.loadWalks(ownerId);
    expect(reloaded.single.isFavorite, isFalse, reason: 'the repository must not keep the refused edit');
  });

  test('a refused un-star brings the star back', () async {
    await seed([_walk('a', ownerId, isFavorite: true)]);
    repository.accept = false;

    await history.setFavorite(history.walks!.single, false);
    await history.settled;

    expect(history.walks!.single.isFavorite, isTrue);
    expect(messages.single, contains('togliere'));
  });

  test('deleting a walk removes it at once, before the remote delete has finished', () async {
    await seed([_walk('a', ownerId), _walk('b', ownerId, day: 2)]);
    repository.hold = Completer<void>();

    final pending = history.delete(history.walks!.firstWhere((walk) => walk.id == 'a'));

    expect(history.walks!.map((walk) => walk.id), ['b']);
    repository.hold!.complete();
    await pending;
    await history.settled;

    expect(history.walks!.map((walk) => walk.id), ['b']);
    expect(messages, isEmpty);
  });

  test('a refused delete puts the walk back with a message', () async {
    await seed([_walk('a', ownerId), _walk('b', ownerId, day: 2)]);
    repository.accept = false;

    await history.delete(history.walks!.firstWhere((walk) => walk.id == 'a'));
    await history.settled;

    expect(history.walks!.map((walk) => walk.id), ['b', 'a']);
    expect(messages.single, contains('eliminare'));
    final reloaded = await repository.loadWalks(ownerId);
    expect(reloaded.map((walk) => walk.id), containsAll(['a', 'b']));
  });

  test('a reload keeps the walks on screen until the new ones arrive', () async {
    await seed([_walk('a', ownerId)]);
    repository
      ..staleSnapshot = [_walk('a', ownerId), _walk('b', ownerId, day: 2)]
      ..loadHold = Completer<void>();

    final reloading = history.refresh();

    expect(history.walks, isNotNull);
    expect(history.walks!.map((walk) => walk.id), ['a'], reason: 'never blanked while waiting');
    repository.loadHold!.complete();
    await reloading;

    expect(history.walks!.map((walk) => walk.id), ['b', 'a']);
  });

  test('a slow reload that started before an edit cannot undo it', () async {
    await seed([_walk('a', ownerId)]);
    final before = history.walks!.single;
    repository
      ..staleSnapshot = [before]
      ..loadHold = Completer<void>();

    final staleReload = history.refresh();
    await history.setFavorite(before, true);
    repository.loadHold!.complete();
    await staleReload;

    expect(history.walks!.single.isFavorite, isTrue);
  });

  test('restoreWalk lifts the delete tombstone so the walk can be saved again', () async {
    final walk = _walk('tombstoned', ownerId);
    await repository.saveWalk(walk);
    await repository.deleteWalk(ownerId, walk.id);
    expect(await repository.loadWalks(ownerId), isEmpty);

    repository.restoreWalk(walk);

    expect((await repository.loadWalks(ownerId)).single.id, walk.id);
    await repository.saveWalk(walk.copyWith(isFavorite: true));
    expect((await repository.loadWalks(ownerId)).single.isFavorite, isTrue);
  });
}
