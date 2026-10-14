import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/monitoring/domain/weekly_activity.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_system.dart';

// Wednesday 14 October 2026: its week starts on Monday 12 October.
final _now = DateTime(2026, 10, 14, 18);

WalkSession _walk(
  String id,
  DateTime startedAt, {
  double meters = 2000,
  int? seconds = 1800,
  WalkStatus status = WalkStatus.completed,
  DateTime? endedAt,
}) =>
    WalkSession(
      id: id,
      ownerId: 'o',
      petId: 'p',
      status: status,
      startedAt: startedAt,
      endedAt: endedAt,
      distanceMeters: meters,
      durationSeconds: seconds,
    );

void main() {
  test('thirteen weeks, oldest first, the last one is the current week', () {
    final weeks = aggregateWeeklyActivity(const [], now: _now);

    expect(weeks, hasLength(13));
    expect(weeks.last.weekStart, DateTime(2026, 10, 12));
    expect(weeks.first.weekStart, DateTime(2026, 7, 20));
    for (var i = 1; i < weeks.length; i++) {
      expect(weeks[i].weekStart.difference(weeks[i - 1].weekStart).inDays, 7);
    }
    expect(hasNoActivity(weeks), isTrue);
  });

  test('walks of one week are added up', () {
    final weeks = aggregateWeeklyActivity([
      _walk('a', DateTime(2026, 10, 12, 8), meters: 2500, seconds: 1800),
      _walk('b', DateTime(2026, 10, 13, 19), meters: 1500, seconds: 1200),
      _walk('c', DateTime(2026, 10, 5, 9), meters: 4000, seconds: 3600),
    ], now: _now);

    expect(weeks.last.walkCount, 2);
    expect(weeks.last.distanceMeters, 4000);
    expect(weeks.last.durationSeconds, 3000);
    expect(weeks.last.durationMinutes, 50);
    expect(weeks[11].walkCount, 1);
    expect(weeks[11].distanceMeters, 4000);
    expect(hasNoActivity(weeks), isFalse);
  });

  test('weeks run Monday to Sunday', () {
    final weeks = aggregateWeeklyActivity([
      _walk('sunday', DateTime(2026, 10, 11, 23, 30)),
      _walk('monday', DateTime(2026, 10, 12, 0, 5)),
    ], now: _now);

    expect(weeks[11].walkCount, 1); // Sunday 11 closes the week of 5 October
    expect(weeks[12].walkCount, 1);
  });

  test('older walks, unfinished or discarded ones and empty ones are ignored',
      () {
    final weeks = aggregateWeeklyActivity([
      _walk(
          'old', DateTime(2026, 7, 19, 12)), // the Sunday before the first week
      _walk('running', DateTime(2026, 10, 13), status: WalkStatus.inProgress),
      _walk('dropped', DateTime(2026, 10, 13), status: WalkStatus.discarded),
      _walk('still', DateTime(2026, 10, 13), meters: 0),
    ], now: _now);

    expect(hasNoActivity(weeks), isTrue);
  });

  test('a walk with no stored duration is timed from its start and end', () {
    final weeks = aggregateWeeklyActivity([
      _walk(
        'a',
        DateTime(2026, 10, 13, 8),
        seconds: null,
        endedAt: DateTime(2026, 10, 13, 8, 40),
      ),
    ], now: _now);

    expect(weeks.last.durationMinutes, 40);
  });

  test(
      'every week starts at midnight even across the end of daylight saving time',
      () {
    final weeks = aggregateWeeklyActivity(const [], now: DateTime(2026, 11, 4));

    for (final week in weeks) {
      expect(week.weekStart.hour, 0);
      expect(week.weekStart.weekday, DateTime.monday);
    }
    expect(weeks.last.weekStart, DateTime(2026, 11, 2));
  });

  test('distance in kilometres or miles', () {
    expect(distanceInChartUnit(5000, UnitSystem.metric), 5);
    expect(distanceInChartUnit(1609.344, UnitSystem.us), closeTo(1, 1e-12));
    expect(distanceInChartUnit(8046.72, UnitSystem.uk), closeTo(5, 1e-9));
    expect(distanceChartUnitLabel(UnitSystem.metric), 'km');
    expect(distanceChartUnitLabel(UnitSystem.us), 'mi');
  });
}
