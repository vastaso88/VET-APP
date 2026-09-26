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
  return badgeId;
}
