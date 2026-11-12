import '../../dog_walks/domain/walk_session.dart';
import '../../settings/domain/unit_system.dart';

const _metersPerMile = 1609.344;

/// A distance in the unit of the activity chart: kilometres, or miles for
/// the UK and USA systems.
double distanceInChartUnit(double meters, UnitSystem system) =>
    system.usesMiles ? meters / _metersPerMile : meters / 1000;

String distanceChartUnitLabel(UnitSystem system) =>
    system.usesMiles ? 'mi' : 'km';

/// How many weeks the activity chart covers: the current one and the twelve
/// before it, about three months.
const activityWeeks = 13;

class WeeklyActivity {
  const WeeklyActivity({
    required this.weekStart,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.walkCount = 0,
  });

  /// The Monday of the week, at midnight.
  final DateTime weekStart;
  final double distanceMeters;
  final int durationSeconds;
  final int walkCount;

  double get durationMinutes => durationSeconds / 60;

  WeeklyActivity plus(WalkSession walk) => WeeklyActivity(
        weekStart: weekStart,
        distanceMeters: distanceMeters + walk.distanceMeters,
        durationSeconds: durationSeconds + _walkSeconds(walk),
        walkCount: walkCount + 1,
      );
}

int _walkSeconds(WalkSession walk) =>
    walk.durationSeconds ?? walkActiveDurationSeconds(walk);

/// The Monday (midnight) of the week [date] falls in.
DateTime weekStartOf(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));

/// The finished walks of the last [weeks] weeks added up week by week, oldest
/// week first; a week without walks is kept (with zeros) so the chart has no
/// gaps. Walks outside the window, unfinished or discarded ones and walks with no
/// distance (the app deletes those) are ignored.
List<WeeklyActivity> aggregateWeeklyActivity(
  Iterable<WalkSession> walks, {
  required DateTime now,
  int weeks = activityWeeks,
}) {
  final currentWeek = weekStartOf(now);
  // Calendar arithmetic (not Duration) so a daylight-saving change never
  // moves a week start off midnight.
  final starts = [
    for (var i = weeks - 1; i >= 0; i--)
      DateTime(currentWeek.year, currentWeek.month, currentWeek.day - 7 * i),
  ];
  final byWeek = {
    for (final start in starts) start: WeeklyActivity(weekStart: start)
  };

  for (final walk in walks) {
    final finished = walk.status == WalkStatus.completed;
    if (!finished || walk.distanceMeters <= 0) continue;
    final bucket = byWeek[weekStartOf(walk.startedAt)];
    if (bucket == null) continue;
    byWeek[bucket.weekStart] = bucket.plus(walk);
  }
  return [for (final start in starts) byWeek[start]!];
}

/// True when no week of [activity] has a walk.
bool hasNoActivity(List<WeeklyActivity> activity) =>
    activity.every((week) => week.walkCount == 0);
