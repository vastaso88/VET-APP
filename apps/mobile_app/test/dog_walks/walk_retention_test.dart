import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_retention.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';

WalkSession _walk(
  String id, {
  required int daysAgo,
  double distanceMeters = 500,
  bool isFavorite = false,
  int? durationSeconds,
}) {
  return WalkSession(
    id: id,
    ownerId: 'user-1',
    petId: 'pet-1',
    status: WalkStatus.completed,
    startedAt: DateTime(2026, 1, 20).subtract(Duration(days: daysAgo)),
    distanceMeters: distanceMeters,
    isFavorite: isFavorite,
    durationSeconds: durationSeconds,
    route: const [],
  );
}

void main() {
  group('retainedRouteWalkIds', () {
    test('keeps the last 3 by date, favorites, and the longest walk', () {
      final walks = [
        _walk('recent-1', daysAgo: 0),
        _walk('recent-2', daysAgo: 1),
        _walk('recent-3', daysAgo: 2),
        _walk('old-not-favorite', daysAgo: 10),
        _walk('old-favorite', daysAgo: 20, isFavorite: true),
        _walk('old-longest', daysAgo: 30, distanceMeters: 50000),
      ];

      final retained = retainedRouteWalkIds(walks);

      expect(
        retained,
        {'recent-1', 'recent-2', 'recent-3', 'old-favorite', 'old-longest'},
      );
      expect(retained, isNot(contains('old-not-favorite')));
    });

    test('also keeps the longest-duration walk, even if it is a different one', () {
      final walks = [
        _walk('recent-1', daysAgo: 0),
        _walk('old-longest-distance', daysAgo: 10, distanceMeters: 50000),
        _walk('old-longest-duration', daysAgo: 20, durationSeconds: 9000),
      ];

      final retained = retainedRouteWalkIds(walks);

      expect(retained, contains('old-longest-duration'));
    });

    test('is empty for no walks', () {
      expect(retainedRouteWalkIds(const []), isEmpty);
    });
  });

  group('buildWalkHistoryView', () {
    test('records and favorites do not repeat each other, but "recent" repeats them', () {
      final walks = [
        _walk('recent-1', daysAgo: 0, distanceMeters: 90000, durationSeconds: 100), // also both records
        _walk('recent-2', daysAgo: 1, isFavorite: true), // also a favorite
        _walk('recent-3', daysAgo: 2),
        _walk('old-favorite', daysAgo: 20, isFavorite: true),
      ];

      final view = buildWalkHistoryView(walks);

      expect(view.longestDistance!.id, 'recent-1');
      expect(view.longestDuration!.id, 'recent-1');
      expect(view.favorites.map((w) => w.id), ['recent-2', 'old-favorite']);
      // Owner report 2026-10-06: "Recenti" disappeared when the newest walk
      // was also a record. It always lists the last three, repeats included.
      expect(view.recent.map((w) => w.id), ['recent-1', 'recent-2', 'recent-3']);
    });

    test('a single walk that is a record still shows up under "recent"', () {
      final view = buildWalkHistoryView([_walk('only', daysAgo: 0)]);

      expect(view.longestDistance!.id, 'only');
      expect(view.recent.map((w) => w.id), ['only']);
    });

    test('recent is capped at the retention window, newest first', () {
      final walks = [for (var i = 0; i < 6; i++) _walk('w$i', daysAgo: i)];

      final view = buildWalkHistoryView(walks);

      expect(view.recent.map((w) => w.id), ['w0', 'w1', 'w2']);
      expect(view.recent, hasLength(recentWalkCount));
    });

    test('every walk in "recent" keeps its route under the retention policy', () {
      final walks = [for (var i = 0; i < 6; i++) _walk('w$i', daysAgo: i)];

      final view = buildWalkHistoryView(walks);
      final kept = retainedRouteWalkIds(walks);

      expect(view.recent.every((walk) => kept.contains(walk.id)), isTrue);
    });

    test('highlightLabelFor names the records and favorites a repeated walk is', () {
      final walks = [
        _walk('both', daysAgo: 0, distanceMeters: 90000, durationSeconds: 9000, isFavorite: true),
        _walk('plain', daysAgo: 1),
      ];

      final view = buildWalkHistoryView(walks);

      expect(view.highlightLabelFor(walks[0]), 'Più lunga · Più duratura · Preferita');
      expect(view.highlightLabelFor(walks[1]), isNull);
    });

    test('distance and duration records can be different walks', () {
      final walks = [
        _walk('longest-distance', daysAgo: 0, distanceMeters: 90000, durationSeconds: 100),
        _walk('longest-duration', daysAgo: 1, distanceMeters: 100, durationSeconds: 9000),
      ];

      final view = buildWalkHistoryView(walks);

      expect(view.longestDistance!.id, 'longest-distance');
      expect(view.longestDuration!.id, 'longest-duration');
    });

    test('is empty for no walks', () {
      final view = buildWalkHistoryView(const []);

      expect(view.longestDistance, isNull);
      expect(view.longestDuration, isNull);
      expect(view.favorites, isEmpty);
      expect(view.recent, isEmpty);
    });
  });
}
