import 'walk_session.dart';

const firstWalkBadgePrefix = 'first_walk_pet_';
// 1/5 km added, 10/50/100 kept from the original catalog so a pet that
// already earned one of those keeps it (badges are recomputed from stored
// walks every time, not stored themselves - see docs/maps/).
const distanceBadgeThresholdsKm = [1, 5, 10, 50, 100];
// 50 added, 10/30/100 kept for the same reason.
const walkCountBadgeThresholds = [10, 30, 50, 100];

const singleWalkDuration30MinBadgePrefix = 'duration_30min_pet_';
const singleWalkDuration1HourBadgePrefix = 'duration_1h_pet_';
const sevenDayStreakBadgePrefix = 'streak_7days_pet_';
const dawnWalkBadgePrefix = 'dawn_walk_pet_';
const nightWalkBadgePrefix = 'night_walk_pet_';

const _dawnStartHour = 5;
const _dawnEndHour = 7; // exclusive
const _nightStartHour = 21;
const _nightEndHour = 5; // exclusive, wraps past midnight

/// Mirrors packages/core/domain/dog_walk/models.py:evaluate_badges - same
/// per-pet (not per-owner) aggregation. The mobile app writes walks
/// straight to Supabase with no backend call in between, so this Dart copy
/// is what actually runs. Every badge here is a pure function of already-
/// persisted WalkSession fields (distance/duration/startedAt) - there is no
/// separate "earned badges" table, so "earned" state persists automatically
/// wherever the walk history itself does (local + Supabase).
List<String> evaluateBadges(List<WalkSession> sessions) {
  final completed =
      sessions.where((session) => session.status == WalkStatus.completed);

  final sessionsByPet = <String, List<WalkSession>>{};
  for (final session in completed) {
    sessionsByPet.putIfAbsent(session.petId, () => []).add(session);
  }

  final badges = <String>[];
  for (final entry in sessionsByPet.entries) {
    final petId = entry.key;
    final petSessions = entry.value;
    badges.add('$firstWalkBadgePrefix$petId');

    final totalDistanceKm = petSessions.fold<double>(
            0, (sum, session) => sum + session.distanceMeters) /
        1000;
    final totalWalks = petSessions.length;

    for (final threshold in distanceBadgeThresholdsKm) {
      if (totalDistanceKm >= threshold) {
        badges.add('distance_${threshold}km_pet_$petId');
      }
    }
    for (final threshold in walkCountBadgeThresholds) {
      if (totalWalks >= threshold) {
        badges.add('walks_${threshold}_pet_$petId');
      }
    }

    if (petSessions
        .any((session) => (session.durationSeconds ?? 0) >= 30 * 60)) {
      badges.add('$singleWalkDuration30MinBadgePrefix$petId');
    }
    if (petSessions
        .any((session) => (session.durationSeconds ?? 0) >= 60 * 60)) {
      badges.add('$singleWalkDuration1HourBadgePrefix$petId');
    }
    if (petSessions.any((session) => _isDawnHour(session.startedAt.hour))) {
      badges.add('$dawnWalkBadgePrefix$petId');
    }
    if (petSessions.any((session) => _isNightHour(session.startedAt.hour))) {
      badges.add('$nightWalkBadgePrefix$petId');
    }
    if (_longestConsecutiveDayStreak(petSessions) >= 7) {
      badges.add('$sevenDayStreakBadgePrefix$petId');
    }
  }

  return badges;
}

bool _isDawnHour(int hour) => hour >= _dawnStartHour && hour < _dawnEndHour;

bool _isNightHour(int hour) => hour >= _nightStartHour || hour < _nightEndHour;

/// Longest run of calendar days (owner's local time, one per DateTime the
/// walk started on) with at least one completed walk each.
int _longestConsecutiveDayStreak(List<WalkSession> sessions) {
  final days = sessions
      .map((session) => DateTime(
            session.startedAt.year,
            session.startedAt.month,
            session.startedAt.day,
          ))
      .toSet()
      .toList()
    ..sort();

  var longest = 0;
  var current = 0;
  DateTime? previousDay;
  for (final day in days) {
    current = (previousDay != null && day.difference(previousDay).inDays == 1)
        ? current + 1
        : 1;
    if (current > longest) longest = current;
    previousDay = day;
  }
  return longest;
}
