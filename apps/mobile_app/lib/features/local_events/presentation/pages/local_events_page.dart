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
import '../../../location/presentation/reference_location.dart';
import '../../../nearby_places/data/radar_places_repository.dart';
import '../../../nearby_places/domain/radar_place.dart';
import '../../../nearby_places/presentation/radar_place_sheet.dart';
import '../../../../shared/types/result.dart';

/// "Attività attorno a te" / "Eventi nei dintorni": browses
/// packages/core/domain/local_activity (via LocalActivitiesRepository),
/// filtered by a user-chosen radius around their Località preference (or
/// the same Milano fallback used elsewhere while none is set). The
/// "Servizi per animali" section adds businesses from OpenStreetMap served
/// by the backend radar (features/nearby_places).
class LocalEventsPage extends StatefulWidget {
  const LocalEventsPage({super.key, this.radarPlacesRepository});

  /// Injectable for tests; defaults to the real HTTP repository.
  final RadarPlacesRepository? radarPlacesRepository;

  @override
  State<LocalEventsPage> createState() => _LocalEventsPageState();
}

class _LocalEventsPageState extends State<LocalEventsPage> {
  static const _fallbackLocation = Coordinates(latitude: 45.4642, longitude: 9.1900);
  static const _radiusOptionsKm = [5.0, 10.0, 25.0, 50.0];

  double _radiusKm = 25.0;
  late Future<_LocalEventsViewData> _dataFuture;
  late Future<Result<RadarPlacesResult>> _radarFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    _radarFuture = _loadRadarPlaces();
  }

  /// Loaded on its own future: the first request for an area can take
  /// tens of seconds (backend import), and must not hold back the events.
  /// Always asks for the widest radius option - the backend caps it - so
  /// switching radius chips only re-filters, without another request.
  Future<Result<RadarPlacesResult>> _loadRadarPlaces() async {
    final data = await _dataFuture;
    final repository = widget.radarPlacesRepository ?? RadarPlacesRepository();
    return repository.loadNearby(center: data.referenceLocation, radiusKm: _radiusOptionsKm.last);
  }

  Future<_LocalEventsViewData> _loadData() async {
    await LocationPreferenceStore.instance.ensureLoaded();
    final preference = LocationPreferenceStore.instance.preference;
    final referenceLocation = resolveReferenceLocation(preference, _fallbackLocation);

    final activities = await LocalActivitiesRepository().loadActiveActivities();
    return _LocalEventsViewData(referenceLocation: referenceLocation, activities: activities);
  }

  Future<void> _reload() async {
    setState(() {
      _dataFuture = _loadData();
      _radarFuture = _loadRadarPlaces();
    });
    await _dataFuture;
  }

  void _retryRadarPlaces() {
    setState(() => _radarFuture = _loadRadarPlaces());
  }

  List<RadarPlace> _placesWithinRadius(Result<RadarPlacesResult>? result) {
    if (result is! Success<RadarPlacesResult>) {
      return const [];
    }
    return result.value.places
        .where((place) => place.distanceMeters <= _radiusKm * 1000)
        .toList(growable: false);
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
                  FutureBuilder<Result<RadarPlacesResult>>(
                    future: _radarFuture,
                    builder: (context, radarSnapshot) => _ActivitiesMapPreview(
                      center: data.referenceLocation,
                      activities: withDistance.map((entry) => entry.activity).toList(),
                      places: _placesWithinRadius(radarSnapshot.data),
                      onPlaceTap: (place) => showRadarPlaceSheet(context, place),
                    ),
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
                  const SizedBox(height: AppSpacing.xxl),
                  const DashboardSectionHeader(
                    title: 'Servizi per animali',
                    subtitle: 'Veterinari, toelettature, negozi e pensioni da OpenStreetMap.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FutureBuilder<Result<RadarPlacesResult>>(
                    future: _radarFuture,
                    builder: (context, radarSnapshot) => _RadarPlacesSection(
                      result: radarSnapshot.data,
                      places: _placesWithinRadius(radarSnapshot.data),
                      selectedRadiusKm: _radiusKm,
                      onRetry: _retryRadarPlaces,
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

class _RadarPlacesSection extends StatelessWidget {
  const _RadarPlacesSection({
    required this.result,
    required this.places,
    required this.selectedRadiusKm,
    required this.onRetry,
  });

  /// Null while the request is still running.
  final Result<RadarPlacesResult>? result;
  final List<RadarPlace> places;
  final double selectedRadiusKm;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null) {
      return Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Cerco i servizi nella tua zona. La prima volta puo\' richiedere qualche secondo.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      );
    }

    return result.fold(
      onFailure: (error) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error.message, style: AppTextStyles.bodySmall),
          TextButton(onPressed: onRetry, child: const Text('Riprova')),
        ],
      ),
      onSuccess: (value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (places.isEmpty)
            Text('Nessun servizio trovato in questo raggio per ora.', style: AppTextStyles.bodySmall)
          else
            ...places.map(
              (place) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: DashboardListRow(
                  title: place.name,
                  subtitle: [
                    radarPlaceTypeLabel(place.type),
                    if (place.addressLabel != null) place.addressLabel!,
                    formatDistance(place.distanceMeters),
                  ].join(' · '),
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: Icon(radarPlaceTypeIcon(place.type), color: AppColors.primary, size: 20),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
                  onTap: () => showRadarPlaceSheet(context, place),
                ),
              ),
            ),
          if (selectedRadiusKm > value.searchRadiusKm)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'I servizi per animali sono disponibili entro ${value.searchRadiusKm.round()} km.',
                style: AppTextStyles.caption,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivitiesMapPreview extends StatelessWidget {
  const _ActivitiesMapPreview({
    required this.center,
    required this.activities,
    this.places = const [],
    this.onPlaceTap,
  });

  final Coordinates center;
  final List<LocalActivity> activities;
  final List<RadarPlace> places;
  final ValueChanged<RadarPlace>? onPlaceTap;

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
            MarkerLayer(
              markers: places
                  .map(
                    (place) => Marker(
                      point: latlong.LatLng(place.location.latitude, place.location.longitude),
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        onTap: onPlaceTap == null ? null : () => onPlaceTap!(place),
                        child: const Icon(Icons.pets, color: AppColors.primary, size: 22),
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
