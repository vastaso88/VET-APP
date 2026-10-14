import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/auth/current_owner.dart';
import '../../../dog_walks/data/dog_walks_repository.dart';
import '../../../dog_walks/domain/walk_eligibility.dart';
import '../../../dog_walks/presentation/walk_labels.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../../pets/domain/pet_format.dart';
import '../../../pets/domain/pet_models.dart';
import '../../../pets/presentation/widgets/pet_avatar.dart';
import '../../../pets/presentation/widgets/pet_sections.dart';
import '../../../pets/presentation/widgets/pets_scaffold.dart';
import '../../../settings/data/unit_settings_store.dart';
import '../../../settings/domain/unit_conversion.dart';
import '../../../settings/domain/unit_system.dart';
import '../../data/weight_measurements_repository.dart';
import '../../domain/weekly_activity.dart';
import '../../domain/weight_chart.dart';
import '../../domain/weight_measurement.dart';
import '../../domain/weight_units.dart';
import '../widgets/activity_chart_view.dart';
import '../widgets/body_condition_bar.dart';
import '../widgets/measurement_sheet.dart';
import '../widgets/weight_chart_view.dart';

/// "Monitoraggio" of one pet: current weight and body condition, the weight
/// chart (a growth curve for a pet under a year), the history of weighings
/// and, for a dog, the weekly activity drawn from its saved walks.
class MonitoringPage extends StatefulWidget {
  const MonitoringPage({
    required this.pet,
    this.repository,
    this.walksRepository,
    this.now,
    super.key,
  });

  final PetProfile pet;
  final WeightMeasurementsRepository? repository;
  final DogWalksRepository? walksRepository;

  /// Today, for tests.
  final DateTime Function()? now;

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  late final WeightMeasurementsRepository _repository =
      widget.repository ?? WeightMeasurementsRepository();
  late final DogWalksRepository _walksRepository =
      widget.walksRepository ?? DogWalksRepository();

  List<WeightMeasurement>? _measurements;
  List<WeeklyActivity>? _activity;
  ActivityMetric _metric = ActivityMetric.distance;
  int _loadToken = 0;

  late final Listenable _reloadTriggers = Listenable.merge([
    WeightMeasurementsRepository.changes,
    DogWalksRepository.changes,
  ]);

  bool get _showsActivity => isDogSpecies(widget.pet.species);
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  /// The pet as it is now (its birth date may have been edited meanwhile).
  PetProfile get _pet =>
      PetDemoStore.instance.byId(widget.pet.id) ?? widget.pet;

  @override
  void initState() {
    super.initState();
    _reloadTriggers.addListener(_load);
    unawaited(_load());
  }

  @override
  void dispose() {
    _reloadTriggers.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    final measurements = await _repository.load(widget.pet.id);
    List<WeeklyActivity>? activity;
    if (_showsActivity) {
      final walks = await _walksRepository.loadWalks(resolveCurrentOwnerId());
      activity = aggregateWeeklyActivity(
        walks.where((walk) => walk.petId == widget.pet.id),
        now: _now,
      );
    }
    if (!mounted || token != _loadToken) return;
    setState(() {
      _measurements = measurements;
      _activity = activity;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addMeasurement() async {
    final draft = await showMeasurementSheet(
      context,
      pet: _pet,
      system: UnitSettingsStore.instance.system,
      now: _now,
    );
    if (draft == null || !mounted) return;
    final saved = await _repository.add(
      _repository.create(
        petId: widget.pet.id,
        measuredOn: draft.measuredOn,
        weightKg: draft.weightKg,
        bodyCondition: draft.bodyCondition,
        note: draft.note,
      ),
    );
    if (!saved && mounted) _showMessage(context.l10n.monitoringSaveFailed);
  }

  Future<void> _editMeasurement(WeightMeasurement measurement) async {
    final draft = await showMeasurementSheet(
      context,
      pet: _pet,
      system: UnitSettingsStore.instance.system,
      initial: measurement,
      now: _now,
    );
    if (draft == null || !mounted) return;
    final saved = await _repository.update(
      measurement.copyWith(
        measuredOn: draft.measuredOn,
        weightKg: draft.weightKg,
        bodyCondition: draft.bodyCondition,
        clearBodyCondition: draft.bodyCondition == null,
        note: draft.note,
      ),
    );
    if (!saved && mounted) _showMessage(context.l10n.monitoringSaveFailed);
  }

  Future<void> _deleteMeasurement(WeightMeasurement measurement) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.large)),
        title: Text(l10n.monitoringDeleteTitle),
        content: Text(
          l10n.monitoringDeleteMessage(
              formatAppDate(measurement.measuredOn, 'd MMM y')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await _repository.delete(measurement);
    if (!deleted && mounted) _showMessage(context.l10n.monitoringDeleteFailed);
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    return PetsScaffold(
      title: context.l10n.monitoringTitle,
      subtitle: pet.name,
      onBack: () => Navigator.of(context).maybePop(),
      badge: PetAvatar(
        label: pet.avatarEmoji,
        backgroundColor: pet.accentColor,
        photoBytes: pet.photoBytes,
        photoPath: pet.photoPath,
        identityColor: pet.identityColor,
        size: 36,
      ),
      body: _measurements == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: UnitSettingsStore.instance,
              builder: (context, _) =>
                  _buildBody(context, pet, UnitSettingsStore.instance.system),
            ),
    );
  }

  Widget _buildBody(BuildContext context, PetProfile pet, UnitSystem system) {
    final measurements = _measurements!;
    final chart = buildWeightChart(
      measurements: measurements,
      birthDate: parsePetBirthDateLabel(pet.birthDateLabel),
      now: _now,
      system: system,
    );
    final byAge = chart?.mode == WeightChartMode.byAge;
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        FilledButton.icon(
          key: const ValueKey('monitoring-add'),
          onPressed: _addMeasurement,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(l10n.monitoringAddMeasurement),
        ),
        const SizedBox(height: AppSpacing.md),
        _CurrentWeightCard(
            pet: pet, measurements: measurements, system: system),
        if (chart != null) ...[
          const SizedBox(height: AppSpacing.md),
          PetSection(
            title: byAge
                ? l10n.monitoringChartTitleGrowth
                : l10n.monitoringChartTitleWeight,
            subtitle: byAge ? l10n.monitoringChartGrowthHint(pet.name) : null,
            children: [
              WeightChartView(
                  key: const ValueKey('weight-chart'),
                  data: chart,
                  system: system),
              if (chart.points.length == 1) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.monitoringChartSinglePoint,
                    style: AppTextStyles.bodySmall),
              ],
            ],
          ),
        ],
        if (_showsActivity) ...[
          const SizedBox(height: AppSpacing.md),
          _ActivityCard(
            pet: pet,
            weeks: _activity,
            metric: _metric,
            system: system,
            onMetric: (metric) => setState(() => _metric = metric),
          ),
        ],
        if (measurements.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          PetSection(
            title: l10n.monitoringHistoryTitle,
            children: [
              for (final measurement in sortedByDate(measurements).reversed)
                _HistoryRow(
                  measurement: measurement,
                  system: system,
                  onEdit: () => _editMeasurement(measurement),
                  onDelete: () => _deleteMeasurement(measurement),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The latest weight with its date, how much it changed, and the body
/// condition bar.
class _CurrentWeightCard extends StatelessWidget {
  const _CurrentWeightCard({
    required this.pet,
    required this.measurements,
    required this.system,
  });

  final PetProfile pet;
  final List<WeightMeasurement> measurements;
  final UnitSystem system;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final latest = latestMeasurement(measurements);
    final withCondition = latestWithBodyCondition(measurements);
    final change = weightChangeKg(measurements);
    final sorted = sortedByDate(measurements);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.border),
      ),
      child: latest == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.monitoringEmptyTitle, style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.monitoringEmptyBody(pet.name),
                    style: AppTextStyles.bodySmall),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.monitoringCurrentWeight,
                    style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatMeasuredWeight(latest.weightKg, system),
                  key: const ValueKey('current-weight'),
                  style: AppTextStyles.display,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.monitoringMeasuredOn(
                      formatAppDate(latest.measuredOn, 'd MMM y')),
                  style: AppTextStyles.bodySmall,
                ),
                if (change != null && change != 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.monitoringChangeSince(
                        formatWeightChange(change, system),
                        formatAppDate(
                            sorted[sorted.length - 2].measuredOn, 'd MMM'),
                      ),
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Flexible(
                      child: Text(l10n.monitoringBcsTitle.toUpperCase(),
                          style: AppTextStyles.caption),
                    ),
                    if (withCondition != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          '${withCondition.bodyCondition!.score}/5 · ${withCondition.bodyCondition!.label}',
                          key: const ValueKey('current-bcs'),
                          textAlign: TextAlign.end,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: withCondition.bodyCondition!.color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                BodyConditionBar(selected: withCondition?.bodyCondition),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  withCondition == null
                      ? l10n.monitoringBcsNone
                      : l10n.monitoringBcsAsOf(
                          formatAppDate(withCondition.measuredOn, 'd MMM y')),
                  style: AppTextStyles.caption
                      .copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.measurement,
    required this.system,
    required this.onEdit,
    required this.onDelete,
  });

  final WeightMeasurement measurement;
  final UnitSystem system;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final condition = measurement.bodyCondition;
    final detail = [
      if (condition != null) '${condition.score}/5 · ${condition.label}',
      if (measurement.note.isNotEmpty) measurement.note,
    ].join('\n');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  formatAppDate(measurement.measuredOn, 'd'),
                  style: AppTextStyles.title.copyWith(fontSize: 18),
                ),
                Text(
                  formatAppDate(measurement.measuredOn, 'MMM').toUpperCase(),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (condition != null)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: AppSpacing.sm),
                        decoration: BoxDecoration(
                            color: condition.color, shape: BoxShape.circle),
                      ),
                    Flexible(
                      child: Text(
                        formatMeasuredWeight(measurement.weightKg, system),
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (detail.isNotEmpty)
                  Text(detail, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          PopupMenuButton<bool>(
            key: ValueKey('history-menu-${measurement.id}'),
            icon: const Icon(Icons.more_vert_rounded,
                size: 20, color: AppColors.mutedText),
            onSelected: (edit) => edit ? onEdit() : onDelete(),
            itemBuilder: (context) => [
              PopupMenuItem(value: true, child: Text(context.l10n.commonEdit)),
              PopupMenuItem(
                  value: false, child: Text(context.l10n.commonDelete)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Weekly walks of the last three months, as distance or as time.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.pet,
    required this.weeks,
    required this.metric,
    required this.system,
    required this.onMetric,
  });

  final PetProfile pet;

  /// Null while the walks are still loading.
  final List<WeeklyActivity>? weeks;
  final ActivityMetric metric;
  final UnitSystem system;
  final ValueChanged<ActivityMetric> onMetric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final weeks = this.weeks;
    return PetSection(
      title: l10n.monitoringActivityTitle,
      subtitle: l10n.monitoringActivitySubtitle(pet.name),
      children: [
        if (weeks == null)
          const Center(child: CircularProgressIndicator())
        else if (hasNoActivity(weeks))
          Text(
            l10n.monitoringActivityEmpty(pet.name),
            key: const ValueKey('activity-empty'),
            style: AppTextStyles.bodySmall,
          )
        else ...[
          _ActivityTotals(weeks: weeks, system: system),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<ActivityMetric>(
            key: const ValueKey('activity-metric'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ActivityMetric.distance,
                label: Text(l10n.monitoringActivityDistance),
              ),
              ButtonSegment(
                  value: ActivityMetric.time,
                  label: Text(l10n.monitoringActivityTime)),
            ],
            selected: {metric},
            onSelectionChanged: (selection) => onMetric(selection.first),
          ),
          const SizedBox(height: AppSpacing.md),
          ActivityChartView(
            key: const ValueKey('activity-chart'),
            weeks: weeks,
            metric: metric,
            system: system,
          ),
        ],
      ],
    );
  }
}

class _ActivityTotals extends StatelessWidget {
  const _ActivityTotals({required this.weeks, required this.system});

  final List<WeeklyActivity> weeks;
  final UnitSystem system;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final walks = weeks.fold<int>(0, (sum, week) => sum + week.walkCount);
    final meters =
        weeks.fold<double>(0, (sum, week) => sum + week.distanceMeters);
    final seconds =
        weeks.fold<int>(0, (sum, week) => sum + week.durationSeconds);

    Widget tile(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );

    return Row(
      key: const ValueKey('activity-totals'),
      children: [
        tile(l10n.monitoringActivityStatWalks, '$walks'),
        tile(l10n.monitoringActivityDistance, formatDistanceIn(meters, system)),
        tile(l10n.monitoringActivityTime, walkDurationLabel(seconds)),
      ],
    );
  }
}
