import 'dart:math' as math;

import '../../settings/domain/unit_system.dart';
import 'weight_measurement.dart';
import 'weight_units.dart';

/// Days in an average month: the unit of the age axis of the growth curve.
const _daysPerMonth = 30.4375;

/// Under this age (in months) the chart is a growth curve (weight against age).
const growthCurveMonths = 12;

/// Whole calendar days from [from] to [to] (both dates): a daylight-saving
/// change never makes a day 23 or 25 hours long here.
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

/// Age in (fractional) months of a pet born on [birth], on day [date].
double ageInMonths(DateTime birth, DateTime date) =>
    daysBetween(birth, date) / _daysPerMonth;

/// True when the pet is under a year old today (by the calendar: the day it
/// turns one it is no longer a growth curve): its chart plots the weight
/// against its age. An unknown birth date (or one in the future) is not.
bool isGrowthCurvePet(DateTime? birthDate, DateTime now) {
  if (birthDate == null || birthDate.isAfter(now)) return false;
  var months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
  if (now.day < birthDate.day) months -= 1;
  return months < growthCurveMonths;
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
  });

  final WeightChartMode mode;
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
/// old and its birth date is known: then the x axis is the age. No reference
/// curve is drawn, only the pet's own weighings. Null when there is nothing
/// to draw.
WeightChartData? buildWeightChart({
  required List<WeightMeasurement> measurements,
  required DateTime? birthDate,
  required DateTime now,
  required UnitSystem system,
}) {
  var sorted = sortedByDate(measurements);
  final byAge = isGrowthCurvePet(birthDate, now);
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
      : daysBetween(first, m.measuredOn).toDouble();

  final points = [
    for (final m in sorted)
      WeightChartPoint(x: xOf(m), y: unit.fromKg(m.weightKg), measurement: m),
  ];

  final xs = points.map((p) => p.x);
  final ys = points.map((p) => p.y);
  final lowY = ys.reduce(math.min);
  final highY = ys.reduce(math.max);
  final pad = math.max((highY - lowY) * 0.25, highY * 0.08);
  final yInterval = niceInterval((highY - lowY + 2 * pad) / 4);
  final minY = math.max(0.0, ((lowY - pad) / yInterval).floor() * yInterval);
  final maxY = ((highY + pad) / yInterval).ceil() * yInterval;

  final lowX = xs.reduce(math.min);
  final highX = xs.reduce(math.max);
  final double minX;
  final double maxX;
  final double xInterval;
  if (byAge) {
    minX = math.max(0, lowX.floorToDouble() - 1);
    maxX = math.max(highX.ceilToDouble() + 1, minX + 3);
    xInterval = math.max(1, niceInterval((maxX - minX) / 4).roundToDouble());
  } else {
    // A little air on both sides; a single point gets two weeks of span.
    final span = math.max(highX - lowX, 14);
    final margin = (span * 0.08).ceilToDouble();
    minX = lowX - margin;
    maxX = math.max(highX, lowX + 14) + margin;
    xInterval = math.max(1, niceInterval((maxX - minX) / 4).roundToDouble());
  }

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
