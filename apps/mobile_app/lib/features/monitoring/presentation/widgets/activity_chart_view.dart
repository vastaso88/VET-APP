import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../dog_walks/presentation/walk_labels.dart';
import '../../../settings/domain/unit_conversion.dart';
import '../../../settings/domain/unit_system.dart';
import '../../domain/weekly_activity.dart';
import '../../domain/weight_chart.dart';
import 'weight_chart_view.dart';

enum ActivityMetric { distance, time }

/// What one week adds to the chart, in the unit it is drawn in (km / mi, or
/// minutes).
double activityValue(
        WeeklyActivity week, ActivityMetric metric, UnitSystem system) =>
    switch (metric) {
      ActivityMetric.distance =>
        distanceInChartUnit(week.distanceMeters, system),
      ActivityMetric.time => week.durationMinutes,
    };

/// One bar per week, drawn for the distance (km or miles) or the time spent
/// walking (minutes).
class ActivityChartView extends StatelessWidget {
  const ActivityChartView({
    required this.weeks,
    required this.metric,
    required this.system,
    super.key,
  });

  final List<WeeklyActivity> weeks;
  final ActivityMetric metric;
  final UnitSystem system;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final week in weeks) activityValue(week, metric, system)
    ];
    final highest = values.fold<double>(0, (a, b) => a > b ? a : b);
    final interval = niceInterval(highest <= 0 ? 1 : highest * 1.15 / 4);
    final maxY = ((highest * 1.1) / interval).ceil().clamp(1, 1000) * interval;
    final digits = WeightChartView.axisDigits(interval);
    final labelStyle = AppTextStyles.caption.copyWith(fontSize: 11);
    final unit = metric == ActivityMetric.distance
        ? distanceChartUnitLabel(system)
        : 'min';

    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.only(right: 8, top: 8),
        child: BarChart(
          BarChartData(
            maxY: maxY,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                axisNameSize: 18,
                axisNameWidget: Text(unit, style: labelStyle),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: interval,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(formatDecimal(value, digits: digits),
                        style: labelStyle),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    // Every third week is named, so the labels never touch.
                    if (index < 0 ||
                        index >= weeks.length ||
                        (weeks.length - 1 - index) % 3 != 0) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                          formatAppDate(weeks[index].weekStart, 'd MMM'),
                          style: labelStyle),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => AppColors.primaryStrong,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final week = weeks[groupIndex];
                  final value = metric == ActivityMetric.distance
                      ? formatDistanceIn(week.distanceMeters, system)
                      : walkDurationLabel(week.durationSeconds);
                  return BarTooltipItem(
                    '${context.l10n.monitoringActivityWeekOf(formatAppDate(week.weekStart, 'd MMM'))}\n'
                    '$value · ${context.l10n.monitoringActivityWalkCount(week.walkCount)}',
                    AppTextStyles.caption.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < weeks.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: values[i],
                      width: 14,
                      color: AppColors.primary,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
