import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/badges.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/home/presentation/pages/home_dashboard_page.dart';
import 'package:vet_app_mobile/features/settings/data/layout_settings_store.dart';
import 'package:vet_app_mobile/shared/date/calendar_days.dart';

// The clocks change on 29/03/2026 (23-hour day) and 25/10/2026 (25-hour day).
// These tests hold in any time zone: with no summer time they simply pass.
void _expectConsecutiveDays(List<DateTime> days) {
  for (var i = 1; i < days.length; i++) {
    expect(days[i].hour, 0, reason: 'day $i is at midnight');
    expect(
      DateTime.utc(days[i].year, days[i].month, days[i].day)
          .difference(DateTime.utc(days[i - 1].year, days[i - 1].month, days[i - 1].day))
          .inDays,
      1,
      reason: '${days[i - 1]} -> ${days[i]}',
    );
  }
}

void main() {
  group('homeCalendarDays', () {
    test('around 25/10 no date is repeated or skipped (Monday first)', () {
      final days = homeCalendarDays(DateTime(2026, 10, 21), 3, WeekStartDay.monday);

      expect(days, hasLength(21));
      expect(days.first, DateTime(2026, 10, 19));
      expect(days.last, DateTime(2026, 11, 8));
      expect(days.map((d) => d.day).where((d) => d == 25), hasLength(1));
      _expectConsecutiveDays(days);
    });

    test('around 25/10 no date is repeated or skipped (Sunday first)', () {
      final days = homeCalendarDays(DateTime(2026, 10, 21), 3, WeekStartDay.sunday);

      expect(days.first, DateTime(2026, 10, 18));
      expect(days.map((d) => d.day).where((d) => d == 25), hasLength(1));
      _expectConsecutiveDays(days);
    });

    test('a week starting on the 29/03 change keeps its Monday', () {
      // Monday 30/03 minus one day used to land on Saturday 23:00.
      final days = homeCalendarDays(DateTime(2026, 3, 30), 2, WeekStartDay.sunday);

      expect(days.first, DateTime(2026, 3, 29));
      expect(days[1], DateTime(2026, 3, 30));
      _expectConsecutiveDays(days);
    });

    test('a week across the 29/03 change has seven distinct midnights', () {
      final days = homeCalendarDays(DateTime(2026, 3, 25), 2, WeekStartDay.monday);

      expect(days.first, DateTime(2026, 3, 23));
      expect(days.last, DateTime(2026, 4, 5));
      _expectConsecutiveDays(days);
    });
  });

  group('calendarDaysBetween', () {
    test('is 1 for two consecutive midnights across both clock changes', () {
      expect(calendarDaysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 29)), 1);
      expect(calendarDaysBetween(DateTime(2026, 3, 29), DateTime(2026, 3, 30)), 1);
      expect(calendarDaysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 25)), 1);
      expect(calendarDaysBetween(DateTime(2026, 10, 25), DateTime(2026, 10, 26)), 1);
      expect(calendarDaysBetween(DateTime(2026, 10, 26), DateTime(2026, 10, 25)), -1);
    });
  });

  group('walk streak', () {
    List<WalkSession> walksOn(List<DateTime> days) => [
          for (final day in days)
            WalkSession(
              id: 'w-${day.toIso8601String()}',
              ownerId: 'u',
              petId: 'p',
              status: WalkStatus.completed,
              startedAt: DateTime(day.year, day.month, day.day, 10),
            ),
        ];

    test('seven days across 29/03 still count as consecutive', () {
      final days = [for (var i = 0; i < 7; i++) addCalendarDays(DateTime(2026, 3, 26), i)];
      expect(evaluateBadges(walksOn(days)), contains('streak_7days_pet_p'));
    });

    test('seven days across 25/10 still count as consecutive', () {
      final days = [for (var i = 0; i < 7; i++) addCalendarDays(DateTime(2026, 10, 22), i)];
      expect(evaluateBadges(walksOn(days)), contains('streak_7days_pet_p'));
    });
  });
}
