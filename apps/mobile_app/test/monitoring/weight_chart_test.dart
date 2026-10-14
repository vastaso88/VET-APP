import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/monitoring/domain/body_condition.dart';
import 'package:vet_app_mobile/features/monitoring/domain/weight_chart.dart';
import 'package:vet_app_mobile/features/monitoring/domain/weight_measurement.dart';
import 'package:vet_app_mobile/features/monitoring/domain/weight_units.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_system.dart';

final _now = DateTime(2026, 10, 14);

WeightMeasurement _m(DateTime day, double kg,
        {BodyCondition? bcs, DateTime? createdAt}) =>
    WeightMeasurement(
      id: 'm-${day.toIso8601String()}-$kg',
      petId: 'p',
      ownerId: 'o',
      measuredOn: day,
      weightKg: kg,
      bodyCondition: bcs,
      createdAt: createdAt,
    );

WeightChartData _chart(
  List<WeightMeasurement> measurements, {
  DateTime? birth,
  UnitSystem system = UnitSystem.metric,
}) =>
    buildWeightChart(
        measurements: measurements,
        birthDate: birth,
        now: _now,
        system: system)!;

void main() {
  group('the weight over time', () {
    final measurements = [
      _m(DateTime(2026, 9, 30), 23.4),
      _m(DateTime(2026, 8, 1), 22.0),
      _m(DateTime(2026, 9, 1), 22.6),
    ];

    test('points are sorted by date and x counts days from the first weighing',
        () {
      final chart = _chart(measurements, birth: DateTime(2020, 1, 1));

      expect(chart.mode, WeightChartMode.overTime);
      expect(chart.unit, WeightUnit.kg);
      expect([for (final p in chart.points) p.x], [0, 31, 60]);
      expect([for (final p in chart.points) p.y], [22.0, 22.6, 23.4]);
      expect(chart.firstDate, DateTime(2026, 8, 1));
      expect(chart.dateAt(31), DateTime(2026, 9, 1));
    });

    test('the axes frame every point with round steps', () {
      final chart = _chart(measurements);

      for (final p in chart.points) {
        expect(p.y, inInclusiveRange(chart.minY, chart.maxY));
        expect(p.x, inInclusiveRange(chart.minX, chart.maxX));
      }
      expect(chart.minY, greaterThanOrEqualTo(0));
      expect((chart.minY / chart.yInterval) % 1, closeTo(0, 1e-9));
      expect((chart.maxY / chart.yInterval) % 1, closeTo(0, 1e-9));
      expect(chart.xInterval, greaterThanOrEqualTo(1));
    });

    test('a single weighing still gets a drawable frame', () {
      final chart = _chart([_m(DateTime(2026, 10, 1), 12)]);

      expect(chart.points, hasLength(1));
      expect(chart.maxX, greaterThan(chart.minX));
      expect(chart.maxY, greaterThan(chart.minY));
      expect(chart.points.single.y, inInclusiveRange(chart.minY, chart.maxY));
    });

    test('two weighings on one day both appear, in creation order', () {
      final day = DateTime(2026, 10, 1);
      final chart = _chart([
        _m(day, 12.2, createdAt: DateTime(2026, 10, 1, 18)),
        _m(day, 12.0, createdAt: DateTime(2026, 10, 1, 8)),
      ]);

      expect([for (final p in chart.points) p.y], [12.0, 12.2]);
    });

    test('no weighings: nothing to draw', () {
      expect(
        buildWeightChart(
          measurements: const [],
          birthDate: null,
          now: _now,
          system: UnitSystem.metric,
        ),
        isNull,
      );
    });
  });

  group('units on the chart', () {
    test('pounds for the USA and UK', () {
      final chart =
          _chart([_m(DateTime(2026, 10, 1), 10)], system: UnitSystem.us);

      expect(chart.unit, WeightUnit.lb);
      expect(chart.points.single.y, closeTo(22.046, 1e-3));
    });

    test('grams for a tiny pet', () {
      final chart = _chart(
          [_m(DateTime(2026, 10, 1), 0.032), _m(DateTime(2026, 10, 8), 0.034)]);

      expect(chart.unit, WeightUnit.g);
      expect([for (final p in chart.points) p.y],
          [closeTo(32, 1e-9), closeTo(34, 1e-9)]);
    });
  });

  group('the growth curve', () {
    test('a pet under a year old is plotted against its age in months', () {
      final birth = DateTime(2026, 6, 14); // four months old
      final chart = _chart([
        _m(DateTime(2026, 7, 14), 3.0),
        _m(DateTime(2026, 9, 14), 7.5),
        _m(DateTime(2026, 10, 14), 9.0),
      ], birth: birth);

      expect(chart.mode, WeightChartMode.byAge);
      expect(chart.points[0].x, closeTo(30 / 30.4375, 1e-9));
      expect(chart.points[1].x, closeTo(92 / 30.4375, 1e-9));
      expect(chart.points[2].x, closeTo(122 / 30.4375, 1e-9));
      expect(chart.minX, greaterThanOrEqualTo(0));
      for (final p in chart.points) {
        expect(p.x, inInclusiveRange(chart.minX, chart.maxX));
      }
    });

    test('a weighing dated before the birth has no age and is left out', () {
      final chart = _chart([
        _m(DateTime(2026, 5, 1), 1.0),
        _m(DateTime(2026, 8, 1), 4.0),
      ], birth: DateTime(2026, 6, 14));

      expect(chart.points, hasLength(1));
      expect(chart.points.single.y, 4.0);
    });

    test('the 12 month limit, an unknown or future birth date', () {
      expect(
          isGrowthCurvePet(DateTime(2025, 11, 14), _now), isTrue); // 11 months
      expect(isGrowthCurvePet(DateTime(2025, 10, 20), _now), isTrue);
      expect(isGrowthCurvePet(DateTime(2025, 10, 14), _now),
          isFalse); // a year exactly
      expect(isGrowthCurvePet(DateTime(2024, 9, 1), _now), isFalse);
      expect(isGrowthCurvePet(null, _now), isFalse);
      expect(isGrowthCurvePet(DateTime(2026, 12, 1), _now), isFalse);
    });

    test('an adult pet is not plotted by age', () {
      final chart =
          _chart([_m(DateTime(2026, 10, 1), 12)], birth: DateTime(2020, 1, 1));

      expect(chart.mode, WeightChartMode.overTime);
    });

    test('the age in months', () {
      expect(ageInMonths(DateTime(2026, 1, 1), DateTime(2026, 4, 1)),
          closeTo(2.96, 0.01));
      expect(ageInMonths(DateTime(2026, 1, 1), DateTime(2026, 1, 1)), 0);
    });
  });

  group('helpers', () {
    test('niceInterval picks 1, 2, 2.5, 5 or 10 times a power of ten', () {
      expect(niceInterval(0.37), closeTo(0.5, 1e-12));
      expect(niceInterval(1.3), 2);
      expect(niceInterval(2.2), 2.5);
      expect(niceInterval(4), 5);
      expect(niceInterval(7), 10);
      expect(niceInterval(0.04), closeTo(0.05, 1e-12));
      expect(niceInterval(0), 1);
    });

    test('the latest weighing and the change from the previous one', () {
      final list = [
        _m(DateTime(2026, 9, 1), 22.0),
        _m(DateTime(2026, 10, 1), 22.8),
        _m(DateTime(2026, 8, 1), 21.0, bcs: BodyCondition.thin),
      ];

      expect(latestMeasurement(list)!.weightKg, 22.8);
      expect(latestWithBodyCondition(list)!.bodyCondition, BodyCondition.thin);
      expect(weightChangeKg(list), closeTo(0.8, 1e-9));
      expect(weightChangeKg([list.first]), isNull);
      expect(latestMeasurement(const []), isNull);
    });
  });
}
