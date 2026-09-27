import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_retention.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';

WalkSession _walk(
  String id, {
  required int daysAgo,
  double distanceMeters = 500,
  bool isFavorite = false,
}) {
  return WalkSession(
    id: id,
    ownerId: 'user-1',
    petId: 'pet-1',
    status: WalkStatus.completed,
    startedAt: DateTime(2026, 1, 20).subtract(Duration(days: daysAgo)),
    distanceMeters: distanceMeters,
    isFavorite: isFavorite,
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

    test('is empty for no walks', () {
      expect(retainedRouteWalkIds(const []), isEmpty);
    });
  });

  group('buildWalkHistoryView', () {
    test('shows each walk once, in its highest-priority section', () {
      final walks = [
        _walk('recent-1', daysAgo: 0, distanceMeters: 90000), // also the record
        _walk('recent-2', daysAgo: 1, isFavorite: true), // also a favorite
        _walk('recent-3', daysAgo: 2),
        _walk('old-favorite', daysAgo: 20, isFavorite: true),
      ];

      final view = buildWalkHistoryView(walks);

      expect(view.record!.id, 'recent-1');
      expect(view.favorites.map((w) => w.id), ['recent-2', 'old-favorite']);
      // recent-1 and recent-2 are already shown above, so "recent" only
      // needs to fill in what's left of the last-3 window.
      expect(view.recent.map((w) => w.id), ['recent-3']);
    });

    test('is empty for no walks', () {
      final view = buildWalkHistoryView(const []);

      expect(view.record, isNull);
      expect(view.favorites, isEmpty);
      expect(view.recent, isEmpty);
    });
  });
}
