import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../../settings/data/unit_settings_store.dart';
import '../../settings/domain/unit_conversion.dart';

String walkDateLabel(DateTime startedAt) => formatAppDate(startedAt, 'd MMM y');

String walkDistanceLabel(double distanceMeters) =>
    formatDistanceIn(distanceMeters, UnitSettingsStore.instance.system);

String walkDurationLabel(int? durationSeconds) {
  if (durationSeconds == null) return '';
  final minutes = durationSeconds ~/ 60;
  if (minutes < 60) return appL10n.walksDurationMinutes(minutes);
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return appL10n.walksDurationHoursMinutes(hours, remainingMinutes);
}

/// Ticking mm:ss (or h:mm:ss past an hour) for the live walk in progress.
/// Distinct from [walkDurationLabel]: that one rounds to whole minutes,
/// which is fine for a finished walk's summary but froze the on-screen
/// timer at "0 min" for the whole first minute of every walk (owner report,
/// 2026-09-29) since it never surfaced the seconds the per-second Timer in
/// active_walk_page.dart was already ticking.
String walkElapsedLabel(int elapsedSeconds) {
  final seconds = elapsedSeconds % 60;
  final totalMinutes = elapsedSeconds ~/ 60;
  final minutes = totalMinutes % 60;
  final secondsLabel = seconds.toString().padLeft(2, '0');
  if (totalMinutes < 60) {
    return '$minutes:$secondsLabel';
  }
  final hours = totalMinutes ~/ 60;
  final minutesLabel = minutes.toString().padLeft(2, '0');
  return '$hours:$minutesLabel:$secondsLabel';
}

/// Turns a raw badge id (e.g. "distance_50km_pet_<id>") into a short
/// label. The caller already scopes badges to one pet, so the
/// trailing pet id is never shown.
String badgeLabel(String badgeId) {
  final l10n = appL10n;
  if (badgeId.startsWith('first_walk_pet_')) {
    return l10n.walksBadgeLabelFirstWalk;
  }
  final distanceMatch = RegExp(r'^distance_(\d+)km_pet_').firstMatch(badgeId);
  if (distanceMatch != null) {
    return l10n.walksBadgeLabelDistance(distanceMatch.group(1)!);
  }
  final walksMatch = RegExp(r'^walks_(\d+)_pet_').firstMatch(badgeId);
  if (walksMatch != null) {
    return l10n.walksBadgeLabelWalkCount(walksMatch.group(1)!);
  }
  if (badgeId.startsWith('duration_30min_pet_')) {
    return l10n.walksBadgeLabel30Min;
  }
  if (badgeId.startsWith('duration_1h_pet_')) {
    return l10n.walksBadgeLabel1Hour;
  }
  if (badgeId.startsWith('streak_7days_pet_')) {
    return l10n.walksBadgeLabelStreak;
  }
  if (badgeId.startsWith('dawn_walk_pet_')) {
    return l10n.walksBadgeLabelDawn;
  }
  if (badgeId.startsWith('night_walk_pet_')) {
    return l10n.walksBadgeLabelNight;
  }
  return badgeId;
}
