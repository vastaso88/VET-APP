import 'walk_session.dart';

/// "Passeggiata del 07/10/26" - the caption under a gallery photo taken
/// during [walk] (owner request, 2026-10-07). Dated by the walk's start, so
/// a walk across midnight keeps one date for all its photos.
String walkPhotoLabel(WalkSession walk) {
  final local = walk.startedAt.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return 'Passeggiata del ${two(local.day)}/${two(local.month)}/${two(local.year % 100)}';
}

/// The walk [takenAt] falls inside, among [walksForPet] (already filtered to
/// the photo's pet), or null when the photo wasn't taken during any walk.
///
/// Both ends count (a shot in the very second of "Termina" is still the
/// walk's) and there is no tolerance around them, so a photo taken right
/// after a walk is never captioned with it. [now] closes the window of a
/// walk still in progress. Walks never overlap in practice; if stale data
/// ever makes two match, the most recent one wins.
WalkSession? walkForPhoto(
  DateTime takenAt,
  List<WalkSession> walksForPet, {
  DateTime? now,
}) {
  WalkSession? match;
  for (final walk in walksForPet) {
    if (walk.status == WalkStatus.discarded) continue;
    final end = walk.endedAt ??
        (walk.status == WalkStatus.inProgress ? (now ?? DateTime.now()) : null);
    if (end == null) continue;
    if (takenAt.isBefore(walk.startedAt) || takenAt.isAfter(end)) continue;
    if (match == null || walk.startedAt.isAfter(match.startedAt)) match = walk;
  }
  return match;
}
