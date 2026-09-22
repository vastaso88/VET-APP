import 'walk_session.dart';

const firstWalkBadgePrefix = 'first_walk_pet_';
const distanceBadgeThresholdsKm = [10, 50, 100];
const walkCountBadgeThresholds = [10, 30, 100];

/// Mirrors packages/core/domain/dog_walk/models.py:evaluate_badges - same
/// thresholds, same per-pet (not per-owner) aggregation, decided together
/// with the user rather than pre-designed (see docs/maps/). The mobile app
/// writes walks straight to Supabase with no backend call in between, so
/// this Dart copy is what actually runs.
List<String> evaluateBadges(List<WalkSession> sessions) {
  final completed = sessions.where((session) => session.status == WalkStatus.completed);

  final sessionsByPet = <String, List<WalkSession>>{};
  for (final session in completed) {
    sessionsByPet.putIfAbsent(session.petId, () => []).add(session);
  }

  final badges = <String>[];
  for (final entry in sessionsByPet.entries) {
    final petId = entry.key;
    final petSessions = entry.value;
    badges.add('$firstWalkBadgePrefix$petId');

    final totalDistanceKm =
        petSessions.fold<double>(0, (sum, session) => sum + session.distanceMeters) / 1000;
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
  }

  return badges;
}
