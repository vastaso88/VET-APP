import 'dart:math' as math;

import '../../../shared/date/calendar_days.dart';
import '../../settings/domain/unit_system.dart';
import 'growth_reference.dart';
import 'weight_measurement.dart';
import 'weight_units.dart';

/// Days in an average month: the unit of the age axis of the growth curve.
const _daysPerMonth = 30.4375;

/// Under this age (in months) the chart is a growth curve (weight against age).
const growthCurveMonths = 12;

/// Age in (fractional) months of a pet born on [birth], on day [date].
double ageInMonths(DateTime birth, DateTime date) =>
    calendarDaysBetween(birth, date) / _daysPerMonth;

/// True when the pet is under a year old today (by the calendar: the day it
/// turns one it is no longer a growth curve): its chart plots the weight
/// against its age. An unknown birth date (or one in the future) is not.
/// [months] raises the limit for a pet that has reference bands.
bool isGrowthCurvePet(
  DateTime? birthDate,
  DateTime now, {
  int months = growthCurveMonths,
}) {
  if (birthDate == null || birthDate.isAfter(now)) return false;
  var age = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
  if (now.day < birthDate.day) age -= 1;
  return age < months;
}

enum WeightChartMode {
  /// Weight against the calendar date.
  overTime,

  /// Weight against the pet's age in months (the growth curve).
  byAge,
}

class WeightChartPoint {
  const WeightChartPoint(
      {required this.x, required this.y, required this.measurement});

  /// Days since [WeightChartData.firstDate] (over time) or months of age.
  final double x;

  /// The weight in [WeightChartData.unit].
  final double y;
  final WeightMeasurement measurement;
}

/// The reference bands of a growth curve, in the unit of the chart: age in
/// months against the 3rd, 25th, 50th, 75th and 97th percentile weights.
class ChartReference {
  const ChartReference({required this.xs, required this.ys});

  final List<double> xs;
  final Map<int, List<double>> ys;
}

class WeightChartData {
  const WeightChartData({
    required this.mode,
    required this.unit,
    required this.points,
    required this.firstDate,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.xInterval,
    required this.yInterval,
    this.reference,
  });

  final WeightChartMode mode;

  /// Reference bands behind the points; only in [WeightChartMode.byAge].
  final ChartReference? reference;
  final WeightUnit unit;

  /// Oldest first.
  final List<WeightChartPoint> points;

  /// The date of x = 0 in [WeightChartMode.overTime].
  final DateTime firstDate;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double xInterval;
  final double yInterval;

  /// The calendar date of an x value of the over-time chart.
  DateTime dateAt(double x) =>
      DateTime(firstDate.year, firstDate.month, firstDate.day + x.round());
}

/// The points of the weight chart. Over time unless the pet is under a year
/// old and its birth date is known: then the x axis is the age. Reference
/// bands are drawn only when [reference] is given (a dog or kitten with
/// bands, see growth_reference.dart): the chart is then an age chart for as
/// long as the bands go. Null when there is nothing to draw.
WeightChartData? buildWeightChart({
  required List<WeightMeasurement> measurements,
  required DateTime? birthDate,
  required DateTime now,
  required UnitSystem system,
  GrowthReference? reference,
}) {
  var sorted = sortedByDate(measurements);
  final bandMonths = reference == null
      ? growthCurveMonths
      : (reference.isPuppy ? puppyBandsMonths : kittenBandsMonths);
  final byAge = isGrowthCurvePet(
    birthDate,
    now,
    months: bandMonths > growthCurveMonths ? bandMonths : growthCurveMonths,
  );
  if (byAge) {
    // A weighing dated before the birth has no age to sit at.
    sorted = sorted.where((m) => !m.measuredOn.isBefore(birthDate!)).toList();
  }
  if (sorted.isEmpty) return null;

  final unit =
      weightChartUnit(sorted.map((m) => m.weightKg).reduce(math.max), system);
  final first = sorted.first.measuredOn;
  double xOf(WeightMeasurement m) => byAge
      ? ageInMonths(birthDate!, m.measuredOn)
      : calendarDaysBetween(first, m.measuredOn).toDouble();

  final points = [
    for (final m in sorted)
      WeightChartPoint(x: xOf(m), y: unit.fromKg(m.weightKg), measurement: m),
  ];

  final xs = points.map((p) => p.x);
  final ys = points.map((p) => p.y);
  final lowX = xs.reduce(math.min);
  final highX = xs.reduce(math.max);
  final double minX;
  final double maxX;
  final double xInterval;
  ChartReference? chartReference;
  if (byAge) {
    var low = math.max(0, lowX.floorToDouble() - 1);
    var high = math.max(highX.ceilToDouble() + 1, low + 3);
    if (reference != null) {
      // Show the bands from where they start, as far ahead as the pet's age
      // needs (at least a year), never past their end.
      low = math.min(low, reference.curves.months.first.floorToDouble());
      high = math.min(
        reference.maxMonths.floorToDouble(),
        math.max(high, math.max(highX + 6, 12).ceilToDouble()),
      );
      high = math.max(high, low + 3);
      chartReference = ChartReference(
        xs: reference.curves.months,
        ys: {
          for (final p in const [3, 25, 50, 75, 97])
            p: [for (final kg in reference.curves[p]) unit.fromKg(kg)],
        },
      );
    }
    minX = low.toDouble();
    maxX = high.toDouble();
    xInterval = math.max(1, niceInterval((maxX - minX) / 4).roundToDouble());
  } else {
    // A little air on both sides; a single point gets two weeks of span.
    final span = math.max(highX - lowX, 14);
    final margin = (span * 0.08).ceilToDouble();
    minX = lowX - margin;
    maxX = math.max(highX, lowX + 14) + margin;
    xInterval = math.max(1, niceInterval((maxX - minX) / 4).roundToDouble());
  }

  // The y range holds the points and the part of the bands that is on view.
  var lowY = ys.reduce(math.min);
  var highY = ys.reduce(math.max);
  if (chartReference != null) {
    for (var i = 0; i < chartReference.xs.length; i++) {
      final x = chartReference.xs[i];
      if (x < minX || x > maxX) continue;
      lowY = math.min(lowY, chartReference.ys[3]![i]);
      highY = math.max(highY, chartReference.ys[97]![i]);
    }
  }
  final pad = math.max((highY - lowY) * 0.25, highY * 0.08);
  final yInterval = niceInterval((highY - lowY + 2 * pad) / 4);
  final minY = math.max(0.0, ((lowY - pad) / yInterval).floor() * yInterval);
  final maxY = ((highY + pad) / yInterval).ceil() * yInterval;

  return WeightChartData(
    mode: byAge ? WeightChartMode.byAge : WeightChartMode.overTime,
    unit: unit,
    points: points,
    firstDate: first,
    minX: minX,
    maxX: maxX,
    minY: minY,
    maxY: maxY,
    xInterval: xInterval,
    yInterval: yInterval,
    reference: chartReference,
  );
}

/// A round step (1, 2, 2.5, 5 times a power of ten) at least as big as [raw].
double niceInterval(double raw) {
  if (raw <= 0 || !raw.isFinite) return 1;
  final exponent = (math.log(raw) / math.ln10).floor();
  final base = math.pow(10, exponent).toDouble();
  final fraction = raw / base;
  final nice = fraction <= 1
      ? 1
      : fraction <= 2
          ? 2
          : fraction <= 2.5
              ? 2.5
              : fraction <= 5
                  ? 5
                  : 10;
  return nice * base;
}

/// The change from the previous weighing to the latest, in kg. Null with
/// fewer than two weighings.
double? weightChangeKg(List<WeightMeasurement> measurements) {
  final sorted = sortedByDate(measurements);
  if (sorted.length < 2) return null;
  return sorted.last.weightKg - sorted[sorted.length - 2].weightKg;
}
