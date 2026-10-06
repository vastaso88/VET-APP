import 'walk_session.dart';

/// Owner-set cap on starred walks per pet (see pickFavoriteToEvict).
const int maxFavoriteWalks = 5;

/// How many of the latest walks "Recenti" lists - and whose routes the
/// retention policy below therefore always keeps.
const int recentWalkCount = 3;

/// Space-saving retention policy: only the GPS `route` of a handful of
/// walks is worth keeping (it's the heavy part - everything else is a few
/// scalars). A walk outside this set still counts toward lifetime badges
/// (see badges.dart, which only reads distance/status/petId), it just loses
/// its route/map once it's no longer one of these.
Set<String> retainedRouteWalkIds(List<WalkSession> completedWalksByDateDesc) {
  if (completedWalksByDateDesc.isEmpty) return const {};
  final ids = <String>{
    for (final walk in completedWalksByDateDesc.take(recentWalkCount)) walk.id,
    for (final walk in completedWalksByDateDesc)
      if (walk.isFavorite) walk.id,
    _longestDistanceOf(completedWalksByDateDesc).id,
    _longestDurationOf(completedWalksByDateDesc).id,
  };
  return ids;
}

/// What the "Passeggiate" tab actually renders: the two records pinned on
/// their own (owner request, 2026-09-30: distance and duration are tracked
/// as separate records - "Più lunga" and "Più duratura" can be different
/// walks), then favorites (not repeating a record), then the latest walks.
///
/// "Recenti" always lists the last [recentWalkCount] walks by date, even when
/// they also appear as a record or a favorite (owner report, 2026-10-06: the
/// section vanished because the newest walk happened to be a record). A walk
/// shown twice carries [highlightLabelFor] so the repeat is explained.
class WalkHistoryView {
  const WalkHistoryView({
    this.longestDistance,
    this.longestDuration,
    this.favorites = const [],
    this.recent = const [],
  });

  final WalkSession? longestDistance;
  final WalkSession? longestDuration;
  final List<WalkSession> favorites;
  final List<WalkSession> recent;

  /// "Più lunga", "Più duratura", "Preferita" (joined with " · ") for a walk
  /// that is a record or a favorite, null for an ordinary one - shown on its
  /// card in "Recenti" since it also appears higher up.
  String? highlightLabelFor(WalkSession walk) {
    final parts = [
      if (longestDistance?.id == walk.id) 'Più lunga',
      if (longestDuration?.id == walk.id) 'Più duratura',
      if (walk.isFavorite) 'Preferita',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

WalkHistoryView buildWalkHistoryView(
    List<WalkSession> completedWalksByDateDesc) {
  if (completedWalksByDateDesc.isEmpty) {
    return const WalkHistoryView();
  }

  final longestDistance = _longestDistanceOf(completedWalksByDateDesc);
  final longestDuration = _longestDurationOf(completedWalksByDateDesc);
  final shown = <String>{longestDistance.id, longestDuration.id};

  final favorites = <WalkSession>[];
  for (final walk in completedWalksByDateDesc) {
    if (walk.isFavorite && shown.add(walk.id)) {
      favorites.add(walk);
    }
  }

  final recent = completedWalksByDateDesc.take(recentWalkCount).toList();

  return WalkHistoryView(
    longestDistance: longestDistance,
    longestDuration: longestDuration,
    favorites: favorites,
    recent: recent,
  );
}

WalkSession _longestDistanceOf(List<WalkSession> walks) {
  return walks.reduce((a, b) => a.distanceMeters >= b.distanceMeters ? a : b);
}

WalkSession _longestDurationOf(List<WalkSession> walks) {
  return walks.reduce(
    (a, b) => (a.durationSeconds ?? 0) >= (b.durationSeconds ?? 0) ? a : b,
  );
}
