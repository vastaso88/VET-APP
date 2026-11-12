import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/domain/unit_conversion.dart';
import '../../../settings/domain/unit_system.dart';
import '../../domain/weight_chart.dart';
import '../../domain/weight_units.dart';

/// The weight line: against the date, or against the age (growth curve).
/// Dots take the colour of the body condition recorded with that weighing.
class WeightChartView extends StatelessWidget {
  const WeightChartView({required this.data, required this.system, super.key});

  final WeightChartData data;
  final UnitSystem system;

  /// Decimals an axis label needs for steps of [interval] (2,5 needs one).
  static int axisDigits(double interval) {
    final hundredths = (interval * 100).round();
    if (hundredths % 100 == 0) return 0;
    return hundredths % 10 == 0 ? 1 : 2;
  }

  @override
  Widget build(BuildContext context) {
    final byAge = data.mode == WeightChartMode.byAge;
    final digits = axisDigits(data.yInterval);
    final labelStyle = AppTextStyles.caption.copyWith(fontSize: 11);
    final reference = data.reference;

    final pointsBar = LineChartBarData(
      spots: [for (final point in data.points) FlSpot(point.x, point.y)],
      isCurved: data.points.length > 2,
      preventCurveOverShooting: true,
      color: AppColors.primary,
      barWidth: 3,
      belowBarData: BarAreaData(
        show: data.points.length > 1 && reference == null,
        color: AppColors.primary.withValues(alpha: 0.08),
      ),
      dotData: FlDotData(
        getDotPainter: (spot, _, __, index) => FlDotCirclePainter(
          radius: 5,
          color: data.points[index].measurement.bodyCondition?.color ??
              AppColors.primary,
          strokeWidth: 2,
          strokeColor: AppColors.surface,
        ),
      ),
    );

    // Reference bands: invisible percentile lines the two shaded bands are
    // drawn between (3rd-97th lighter, 25th-75th darker) and a dashed median.
    LineChartBarData percentileBar(int percentile, {bool median = false}) =>
        LineChartBarData(
          spots: [
            for (var i = 0; i < reference!.xs.length; i++)
              FlSpot(reference.xs[i], reference.ys[percentile]![i]),
          ],
          isCurved: true,
          preventCurveOverShooting: true,
          color: median
              ? AppColors.primary.withValues(alpha: 0.5)
              : Colors.transparent,
          barWidth: median ? 1.5 : 0,
          dashArray: median ? [5, 4] : null,
          dotData: const FlDotData(show: false),
        );
    final bars = [
      if (reference != null) ...[
        percentileBar(3),
        percentileBar(97),
        percentileBar(25),
        percentileBar(75),
        percentileBar(50, median: true),
      ],
      pointsBar,
    ];

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, top: 8),
        child: LineChart(
          LineChartData(
            minX: data.minX,
            maxX: data.maxX,
            minY: data.minY,
            maxY: data.maxY,
            clipData: const FlClipData.all(),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: data.yInterval,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                axisNameSize: 18,
                axisNameWidget: Text(
                  context.l10n.monitoringAxisWeight(data.unit.label),
                  style: labelStyle,
                ),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: data.yInterval,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(formatDecimal(value, digits: digits),
                        style: labelStyle),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                axisNameSize: byAge ? 18 : 0,
                axisNameWidget: byAge
                    ? Text(context.l10n.monitoringAxisAgeMonths,
                        style: labelStyle)
                    : null,
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: data.xInterval,
                  getTitlesWidget: (value, meta) {
                    if (value > data.maxX || value < data.minX) {
                      return const SizedBox.shrink();
                    }
                    final text = byAge
                        ? value.round().toString()
                        : formatAppDate(data.dateAt(value), 'd MMM');
                    return SideTitleWidget(
                        meta: meta, child: Text(text, style: labelStyle));
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              getTouchedSpotIndicator: (bar, indexes) => [
                for (final _ in indexes)
                  if (identical(bar, pointsBar))
                    TouchedSpotIndicatorData(
                      const FlLine(color: AppColors.primary, strokeWidth: 1),
                      FlDotData(
                        getDotPainter: (_, __, ___, ____) =>
                            FlDotCirclePainter(
                          radius: 6,
                          color: AppColors.primary,
                          strokeWidth: 2,
                          strokeColor: AppColors.surface,
                        ),
                      ),
                    )
                  else
                    const TouchedSpotIndicatorData(
                      FlLine(color: Colors.transparent),
                      FlDotData(show: false),
                    ),
              ],
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => AppColors.primaryStrong,
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    spot.barIndex == bars.length - 1
                        ? _tooltipFor(context, spot)
                        : null,
                ],
              ),
            ),
            betweenBarsData: [
              if (reference != null) ...[
                BetweenBarsData(
                  fromIndex: 0,
                  toIndex: 1,
                  color: AppColors.primary.withValues(alpha: 0.09),
                ),
                BetweenBarsData(
                  fromIndex: 2,
                  toIndex: 3,
                  color: AppColors.primary.withValues(alpha: 0.17),
                ),
              ],
            ],
            lineBarsData: bars,
          ),
        ),
      ),
    );
  }

  LineTooltipItem? _tooltipFor(BuildContext context, LineBarSpot spot) {
    final point = data.points[spot.spotIndex];
    final measurement = point.measurement;
    final when = data.mode == WeightChartMode.byAge
        ? '${formatAppDate(measurement.measuredOn, 'd MMM y')} · '
            '${context.l10n.monitoringTooltipAge(point.x.round())}'
        : formatAppDate(measurement.measuredOn, 'd MMM y');
    return LineTooltipItem(
      '${formatMeasuredWeight(measurement.weightKg, system)}\n$when',
      AppTextStyles.caption
          .copyWith(color: AppColors.onMedia, fontWeight: FontWeight.w700),
    );
  }
}
