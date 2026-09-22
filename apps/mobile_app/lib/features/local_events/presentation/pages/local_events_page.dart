import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../../local_activities/data/local_activities_repository.dart';
import '../../../local_activities/domain/local_activity.dart';
import '../../../local_activities/presentation/local_activity_labels.dart';
import '../../../local_activities/presentation/pages/local_activity_detail_page.dart';
import '../../../location/data/location_preference_store.dart';
import '../../../location/domain/coordinates.dart';
import '../../../location/domain/geo_math.dart';
import '../../../location/presentation/distance_label.dart';

/// "Attività attorno a te" / "Eventi nei dintorni": browses
/// packages/core/domain/local_activity (via LocalActivitiesRepository),
/// filtered by a user-chosen radius around their Località preference (or
/// the same Milano fallback used elsewhere while none is set).
class LocalEventsPage extends StatefulWidget {
  const LocalEventsPage({super.key});

  @override
  State<LocalEventsPage> createState() => _LocalEventsPageState();
}

class _LocalEventsPageState extends State<LocalEventsPage> {
  static const _fallbackLocation = Coordinates(latitude: 45.4642, longitude: 9.1900);
  static const _radiusOptionsKm = [5.0, 10.0, 25.0, 50.0];

  double _radiusKm = 25.0;
  late Future<_LocalEventsViewData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_LocalEventsViewData> _loadData() async {
    await LocationPreferenceStore.instance.ensureLoaded();
    final preference = LocationPreferenceStore.instance.preference;
    final referenceLocation = preference.current ?? preference.home ?? _fallbackLocation;

    final activities = await LocalActivitiesRepository().loadActiveActivities();
    return _LocalEventsViewData(referenceLocation: referenceLocation, activities: activities);
  }

  Future<void> _reload() async {
    setState(() => _dataFuture = _loadData());
    await _dataFuture;
  }

  Future<void> _openDetail(LocalActivity activity, double distanceMeters) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocalActivityDetailPage(activity: activity, distanceMeters: distanceMeters),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Eventi nei dintorni', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: FutureBuilder<_LocalEventsViewData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            final withDistance = data.activities
                .map(
                  (activity) => (
                    activity: activity,
                    distanceMeters: haversineMeters(data.referenceLocation, activity.location),
                  ),
                )
                .where((entry) => entry.distanceMeters <= _radiusKm * 1000)
                .toList()
              ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

            final upcoming = withDistance.where((entry) => entry.activity.startsAt != null).toList()
              ..sort((a, b) => a.activity.startsAt!.compareTo(b.activity.startsAt!));
            final standingServices =
                withDistance.where((entry) => entry.activity.startsAt == null).toList();

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xxxl,
                ),
                children: [
                  Text(
                    'Fiere, raduni, vaccinazioni e servizi vicino a te, in base alla tua zona.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RadiusSelector(
                    options: _radiusOptionsKm,
                    selected: _radiusKm,
                    onSelected: (value) => setState(() => _radiusKm = value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ActivitiesMapPreview(
                    center: data.referenceLocation,
                    activities: withDistance.map((entry) => entry.activity).toList(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  const DashboardSectionHeader(
                    title: 'In programma',
                    subtitle: 'Eventi e iniziative nei prossimi giorni e mesi.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (upcoming.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Text(
                        'Nessun evento in programma in questo raggio per ora.',
                        style: AppTextStyles.bodySmall,
                      ),
                    )
                  else
                    ...upcoming.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ActivityRow(entry: entry, onTap: _openDetail),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                  const DashboardSectionHeader(
                    title: 'Servizi nella zona',
                    subtitle: 'Ambulatori e punti di riferimento senza una data fissa.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (standingServices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Text(
                        'Nessun servizio censito in questo raggio per ora.',
                        style: AppTextStyles.bodySmall,
                      ),
                    )
                  else
                    ...standingServices.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ActivityRow(entry: entry, onTap: _openDetail),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

typedef _ActivityWithDistance = ({LocalActivity activity, double distanceMeters});

class _LocalEventsViewData {
  const _LocalEventsViewData({required this.referenceLocation, required this.activities});

  final Coordinates referenceLocation;
  final List<LocalActivity> activities;
}

class _RadiusSelector extends StatelessWidget {
  const _RadiusSelector({required this.options, required this.selected, required this.onSelected});

  final List<double> options;
  final double selected;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: options
          .map(
            (option) => ChoiceChip(
              label: Text('${option.round()} km'),
              selected: selected == option,
              onSelected: (_) => onSelected(option),
            ),
          )
          .toList(),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry, required this.onTap});

  final _ActivityWithDistance entry;
  final void Function(LocalActivity activity, double distanceMeters) onTap;

  @override
  Widget build(BuildContext context) {
    final activity = entry.activity;
    final dateLabel = localActivityDateRangeLabel(activity);
    final subtitleParts = [
      if (dateLabel != null) dateLabel,
      if (activity.addressLabel != null) activity.addressLabel!,
      formatDistance(entry.distanceMeters),
    ];

    return DashboardListRow(
      title: activity.title,
      subtitle: subtitleParts.join(' · '),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        child: Icon(
          activity.kind == LocalActivityKind.event ? Icons.event_outlined : Icons.medical_services_outlined,
          color: AppColors.info,
          size: 20,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
      onTap: () => onTap(activity, entry.distanceMeters),
    );
  }
}

class _ActivitiesMapPreview extends StatelessWidget {
  const _ActivitiesMapPreview({required this.center, required this.activities});

  final Coordinates center;
  final List<LocalActivity> activities;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: latlong.LatLng(center.latitude, center.longitude),
            initialZoom: 11,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.vetapp.mobile_app',
            ),
            MarkerLayer(
              markers: activities
                  .map(
                    (activity) => Marker(
                      point: latlong.LatLng(activity.location.latitude, activity.location.longitude),
                      width: 32,
                      height: 32,
                      child: Icon(
                        activity.kind == LocalActivityKind.event
                            ? Icons.event
                            : Icons.medical_services,
                        color: AppColors.info,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),
      ),
    );
  }
}
