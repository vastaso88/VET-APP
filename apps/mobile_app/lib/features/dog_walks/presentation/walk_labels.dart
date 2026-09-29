import 'package:intl/intl.dart';

final _dateFormat = DateFormat('d MMM y', 'it_IT');

String walkDateLabel(DateTime startedAt) => _dateFormat.format(startedAt);

String walkDistanceLabel(double distanceMeters) {
  if (distanceMeters < 1000) {
    return '${distanceMeters.round()} m';
  }
  return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}

String walkDurationLabel(int? durationSeconds) {
  if (durationSeconds == null) return '';
  final minutes = durationSeconds ~/ 60;
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '${hours}h ${remainingMinutes}min';
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
/// Italian label. The caller already scopes badges to one pet, so the
/// trailing pet id is never shown.
String badgeLabel(String badgeId) {
  if (badgeId.startsWith('first_walk_pet_')) {
    return 'Prima passeggiata 🐾';
  }
  final distanceMatch = RegExp(r'^distance_(\d+)km_pet_').firstMatch(badgeId);
  if (distanceMatch != null) {
    return '${distanceMatch.group(1)} km percorsi 🏃';
  }
  final walksMatch = RegExp(r'^walks_(\d+)_pet_').firstMatch(badgeId);
  if (walksMatch != null) {
    return '${walksMatch.group(1)} uscite 🎖️';
  }
  if (badgeId.startsWith('duration_30min_pet_')) {
    return '30 minuti in una passeggiata ⏱️';
  }
  if (badgeId.startsWith('duration_1h_pet_')) {
    return '1 ora in una passeggiata ⏱️';
  }
  if (badgeId.startsWith('streak_7days_pet_')) {
    return '7 giorni di fila 🔥';
  }
  if (badgeId.startsWith('dawn_walk_pet_')) {
    return 'Passeggiata all\'alba 🌅';
  }
  if (badgeId.startsWith('night_walk_pet_')) {
    return 'Passeggiata notturna 🌙';
  }
  return badgeId;
}
