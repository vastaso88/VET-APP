import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/errors/app_network_error.dart';
import '../../../../shared/types/result.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../../local_activities/data/local_activities_repository.dart';
import '../../../local_activities/domain/local_activity.dart';
import '../../../local_activities/presentation/pages/local_activity_detail_page.dart';
import '../../../location/data/device_location_service.dart';
import '../../../location/data/location_preference_store.dart';
import '../../../location/domain/coordinates.dart';
import '../../../location/domain/geo_math.dart';
import '../../../location/presentation/distance_label.dart';
import '../../../nearby_places/data/radar_places_repository.dart';
import '../../../nearby_places/domain/radar_place.dart';
import '../../../nearby_places/presentation/pages/radar_map_page.dart';
import '../../../nearby_places/presentation/pages/report_missing_place_page.dart';
import '../../../nearby_places/presentation/radar_category.dart';
import '../../../nearby_places/presentation/radar_contributions.dart';
import '../../../nearby_places/presentation/radar_place_sheet.dart';
import '../../../nearby_places/presentation/widgets/radar_chip.dart';
import '../../../nearby_places/presentation/widgets/radar_map.dart';
import '../../../settings/presentation/pages/settings_page.dart';

/// "Vicino a me": the pet-related places around the user's Località in
/// one page. Clinics, shops, dog parks and the other businesses come from
/// open datasets (OpenStreetMap, Overture) through the backend
/// (features/nearby_places); standing services users submitted come from
/// LocalActivitiesRepository. Dated events are not shown here: they have
/// their own section of the app. One radius and one set of category chips
/// drive the map and both lists.
///
/// The page is always centered on the Località chosen in Impostazioni
/// (current position or home). There is no default city: until a position
/// is known the page shows a loader, and without one it asks for it.
class LocalEventsPage extends StatefulWidget {
  const LocalEventsPage({
    super.key,
    this.radarPlacesRepository,
    this.locationSampler = const GeolocatorLocationSampler(),
    this.contributions,
  });

  /// Injectable for tests; defaults to the real HTTP repository.
  final RadarPlacesRepository? radarPlacesRepository;

  /// Injectable for tests; defaults to the device GPS.
  final LocationSampler locationSampler;

  /// Injectable for tests; defaults to the real "Segnala!" backend. Its
  /// `onChanged` is replaced: the page reloads itself after a contribution.
  final RadarContributions? contributions;

  @override
  State<LocalEventsPage> createState() => _LocalEventsPageState();
}

class _LocalEventsPageState extends State<LocalEventsPage> {
  static const _radiusOptionsKm = [5.0, 10.0, 25.0, 50.0];
  static const _collapsedRows = 6;
  static const _collapsedRowsPerCategory = 3;

  /// Pauses before asking again when the backend is still importing the
  /// area: the import usually succeeds on a later attempt.
  static const _preparingRetryDelays = [Duration(seconds: 8), Duration(seconds: 15)];

  /// Categories offered as one-tap chips above the map, most used first.
  static const _quickCategories = [
    RadarCategory.veterinary,
    RadarCategory.shop,
    RadarCategory.dogPark,
    RadarCategory.grooming,
    RadarCategory.hotel,
  ];

  double _radiusKm = 10;

  /// Categories shown; empty means all of them.
  Set<RadarCategory> _categories = const {};

  bool _showsCategory(RadarCategory category) =>
      _categories.isEmpty || _categories.contains(category);

  /// Service categories whose list is expanded past the first rows.
  final Set<RadarCategory> _expandedCategories = {};
  bool _showAllClinics = false;
  late Future<_LocalEventsViewData?> _dataFuture;

  /// False until the first radar answer (success or failure) arrived:
  /// while false the whole page is a loader instead of an empty map.
  bool _firstRadarAnswerReady = false;

  /// Contact for "this should not be listed", from the last radar answer.
  String? _supportContactEmail;

  /// The explanation before the system location prompt is shown at most
  /// once per visit to the page.
  bool _locationConsentAsked = false;

  /// One backend request per radius, kept for the page's lifetime so going
  /// back to a radius already seen is instant. The category chips never
  /// trigger a request: they only re-filter what is loaded.
  final Map<double, Future<Result<RadarPlacesResult>>> _radarFutures = {};

  /// Last answer per radius, shown while the same radius is loaded
  /// again after a contribution: the lists stay instead of emptying.
  final Map<double, Result<RadarPlacesResult>> _lastRadarResults = {};

  /// Reports, votes and ratings, reloading the radar when one goes through
  /// (a new pending place, a changed count) without the full-page loader.
  late final RadarContributions _contributions =
      (widget.contributions ?? RadarContributions(onChanged: () {})).reloading(_reloadRadar);

  void _reloadRadar() {
    if (mounted) {
      setState(_radarFutures.clear);
    }
  }

  void _openReportMissing(Coordinates center) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportMissingPlacePage(
          contributions: _contributions,
          initialPosition: center,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  /// Null when no position is available (see [_resolveLocation]).
  Future<_LocalEventsViewData?> _loadData() async {
    final referenceLocation = await _resolveLocation();
    if (referenceLocation == null) {
      return null;
    }
    // Standing services only: dated events belong to their own section.
    final activities = (await LocalActivitiesRepository().loadActiveActivities())
        .where((activity) => activity.startsAt == null)
        .toList();
    return _LocalEventsViewData(referenceLocation: referenceLocation, activities: activities);
  }

  /// The Località the user chose in Impostazioni. "Posizione attuale"
  /// takes a fresh GPS reading (asking for the permission only now, when
  /// it is needed) and falls back to the last saved one; "Residenza" uses
  /// the saved home. Null when neither exists - never a default city.
  Future<Coordinates?> _resolveLocation() async {
    final store = LocationPreferenceStore.instance;
    await store.ensureLoaded();
    final preference = store.preference;
    if (preference.mode == LocationMode.homeResidence && preference.home != null) {
      return preference.home;
    }

    // No position was ever known: explain why before the system prompt
    // appears (just-in-time, foreground only - see
    // docs/compliance/05_permessi_dispositivo_os.md). A user who already
    // has a saved position has been through this and is not asked again.
    final hasKnownPosition = preference.current != null || preference.home != null;
    if (!hasKnownPosition) {
      if (_locationConsentAsked) {
        return null;
      }
      _locationConsentAsked = true;
      final choice = await _askLocationConsent();
      if (choice == _LocationChoice.address) {
        // Opens Impostazioni; on return the page reloads with the address.
        WidgetsBinding.instance.addPostFrameCallback((_) => _openSettings());
        return null;
      }
      if (choice != _LocationChoice.allow) {
        return null;
      }
    }

    final reading = await widget.locationSampler.requestCurrentPosition();
    final coordinates = reading.coordinates;
    if (coordinates != null) {
      await store.update(
        preference.copyWith(
          mode: LocationMode.currentPosition,
          current: coordinates,
          currentSource: LocationSource.deviceGps,
          currentCapturedAt: DateTime.now(),
        ),
      );
      return coordinates;
    }
    return preference.current ?? preference.home;
  }

  Future<_LocationChoice?> _askLocationConsent() async {
    // The first load starts in initState, before there is a frame to
    // attach a dialog to.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return null;
    }
    return showDialog<_LocationChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Usare la tua posizione?'),
        content: const Text(
          'Per mostrarti cosa c’è vicino a te VetApp usa la posizione del telefono '
          'solo mentre usi l’app. In alternativa puoi indicare un indirizzo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_LocationChoice.address),
            child: const Text('Scegli un indirizzo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(_LocationChoice.allow),
            child: const Text('Consenti'),
          ),
        ],
      ),
    );
  }

  Future<Result<RadarPlacesResult>> _radarFor(double radiusKm) {
    return _radarFutures.putIfAbsent(radiusKm, () => _loadRadar(radiusKm));
  }

  Future<Result<RadarPlacesResult>> _loadRadar(double radiusKm) async {
    final data = await _dataFuture;
    if (data == null) {
      return Result.failure(const AppNetworkError(code: 'radar_places_no_location'));
    }
    final repository = widget.radarPlacesRepository ?? RadarPlacesRepository();
    var result = await repository.loadNearby(center: data.referenceLocation, radiusKm: radiusKm);
    for (final delay in _preparingRetryDelays) {
      final stillPreparing = result.fold(
        onSuccess: (_) => false,
        onFailure: (error) => error.code == RadarPlacesRepository.preparingErrorCode,
      );
      if (!stillPreparing || !mounted) {
        break;
      }
      await Future<void>.delayed(delay);
      result = await repository.loadNearby(center: data.referenceLocation, radiusKm: radiusKm);
    }
    _firstRadarAnswerReady = true;
    _lastRadarResults[radiusKm] = result;
    _supportContactEmail = result.fold(
      onSuccess: (value) => value.supportContactEmail ?? _supportContactEmail,
      onFailure: (_) => _supportContactEmail,
    );
    return result;
  }

  Future<void> _reload() async {
    setState(() {
      // An explicit "Riprova" may ask for the position again.
      _locationConsentAsked = false;
      _dataFuture = _loadData();
      _radarFutures.clear();
      _lastRadarResults.clear();
    });
    await _dataFuture;
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
    if (mounted) {
      setState(() {
        _firstRadarAnswerReady = false;
        _locationConsentAsked = true;
        _dataFuture = _loadData();
        _radarFutures.clear();
        _lastRadarResults.clear();
      });
    }
  }

  void _retryRadarPlaces() {
    setState(() {
      _radarFutures.remove(_radiusKm);
      _lastRadarResults.remove(_radiusKm);
    });
  }

  void _setFilters({double? radiusKm, Set<RadarCategory>? categories}) {
    setState(() {
      _radiusKm = radiusKm ?? _radiusKm;
      _categories = categories ?? _categories;
      _expandedCategories.clear();
      _showAllClinics = false;
    });
  }

  void _toggleQuickCategory(RadarCategory category) {
    final categories = {..._categories};
    categories.contains(category) ? categories.remove(category) : categories.add(category);
    _setFilters(categories: categories);
  }

  Future<void> _openActivity(LocalActivity activity, double distanceMeters) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocalActivityDetailPage(activity: activity, distanceMeters: distanceMeters),
      ),
    );
  }

  void _openMap(Coordinates center, List<RadarMapItem> items) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RadarMapPage(center: center, radiusKm: _radiusKm, items: items),
      ),
    );
  }

  void _openEntry(_RadarEntry entry) {
    final place = entry.place;
    if (place != null) {
      showRadarPlaceSheet(
        context,
        place,
        contributions: _contributions,
        supportContactEmail: _supportContactEmail,
      );
    } else {
      _openActivity(entry.activity!, entry.distanceMeters);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Vicino a me', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: FutureBuilder<_LocalEventsViewData?>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _PageLoader(label: 'Cerco la tua posizione…');
            }
            final data = snapshot.data;
            if (data == null) {
              return _NoLocationState(onOpenSettings: _openSettings, onRetry: _reload);
            }
            return FutureBuilder<Result<RadarPlacesResult>>(
              future: _radarFor(_radiusKm),
              builder: (context, radarSnapshot) {
                // While a newly selected radius loads, FutureBuilder still
                // holds the previous radius' data: do not show it as if it
                // were the answer for the new one.
                final radarResult = radarSnapshot.connectionState == ConnectionState.done
                    ? radarSnapshot.data
                    : _lastRadarResults[_radiusKm];
                if (radarResult == null && !_firstRadarAnswerReady) {
                  return const _PageLoader(
                    label: 'Cerco cosa c’è attorno a te. La prima volta in una zona '
                        'può richiedere fino a un minuto.',
                  );
                }
                return _buildContent(data, radarResult);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(_LocalEventsViewData data, Result<RadarPlacesResult>? radarResult) {
    final radiusMeters = _radiusKm * 1000;
    final radar = radarResult is Success<RadarPlacesResult> ? radarResult.value : null;

    final activities = data.activities
        .map(
          (activity) => (
            activity: activity,
            distanceMeters: haversineMeters(data.referenceLocation, activity.location),
          ),
        )
        .toList();

    final entries = <_RadarEntry>[
      ...activities
          .where((entry) => entry.distanceMeters <= radiusMeters)
          .map((entry) => _RadarEntry.activity(entry.activity, entry.distanceMeters)),
      ...(radar?.places ?? const <RadarPlace>[])
          .where((place) => place.distanceMeters <= radiusMeters)
          .map(_RadarEntry.place),
    ].where((entry) => _showsCategory(entry.category)).toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    final clinics = entries.where((entry) => entry.category == RadarCategory.veterinary).toList();
    final services = entries.where((entry) => entry.category != RadarCategory.veterinary).toList();

    final mapItems = <RadarMapItem>[
      ...entries.map(
        (entry) => RadarMapItem(
          category: entry.category,
          location: entry.location,
          label: entry.title,
          onTap: () => _openEntry(entry),
          pending: entry.place?.isPendingReport ?? false,
        ),
      ),
    ];

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
          _RadiusSelector(
            options: _radiusOptionsKm,
            selected: _radiusKm,
            onSelected: (value) => _setFilters(radiusKm: value),
          ),
          const SizedBox(height: AppSpacing.sm),
          _QuickCategoryBar(
            categories: _quickCategories,
            selected: _categories,
            onToggle: _toggleQuickCategory,
            onClear: () => _setFilters(categories: const {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          _MapPreview(
            center: data.referenceLocation,
            radiusKm: _radiusKm,
            items: mapItems,
            onExpand: () => _openMap(data.referenceLocation, mapItems),
          ),
          const SizedBox(height: AppSpacing.sm),
          RadarLegend(categories: mapItems.map((item) => item.category).toSet()),
          const SizedBox(height: AppSpacing.md),
          _RadarStatus(result: radarResult, radiusKm: _radiusKm, onRetry: _retryRadarPlaces),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _openReportMissing(data.referenceLocation),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Segnala! Manca un luogo'),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const DashboardSectionHeader(title: 'Servizi nella zona'),
          const SizedBox(height: AppSpacing.lg),
          _ServicesByCategory(
            entries: services,
            expanded: _expandedCategories,
            collapsedRows: _collapsedRowsPerCategory,
            onToggleExpanded: (category) => setState(
              () => _expandedCategories.contains(category)
                  ? _expandedCategories.remove(category)
                  : _expandedCategories.add(category),
            ),
            onOpen: _openEntry,
          ),
          const SizedBox(height: AppSpacing.xxl),
          const DashboardSectionHeader(
            title: 'Cliniche e ambulatori',
            subtitle: 'I veterinari più vicini, con telefono e indicazioni.',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'In caso di urgenza telefona prima di partire: orari e recapiti arrivano da '
            'archivi aperti e non sono verificati da VetApp.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          _EntryList(
            entries: clinics,
            expanded: _showAllClinics,
            collapsedRows: _collapsedRows,
            emptyLabel: 'Nessuna clinica trovata con questi filtri.',
            onToggleExpanded: () => setState(() => _showAllClinics = !_showAllClinics),
            rowBuilder: (entry) => _ClinicRow(entry: entry, onTap: () => _openEntry(entry)),
          ),
        ],
      ),
    );
  }
}

enum _LocationChoice { allow, address }

class _LocalEventsViewData {
  const _LocalEventsViewData({required this.referenceLocation, required this.activities});

  final Coordinates referenceLocation;
  final List<LocalActivity> activities;
}

/// A standing (undated) thing near the user: either an OpenStreetMap place
/// or a user-submitted service. Lets the two sources share lists, markers
/// and filters.
class _RadarEntry {
  _RadarEntry.place(RadarPlace this.place)
      : activity = null,
        category = radarCategoryForPlace(place.type),
        title = place.name,
        location = place.location,
        distanceMeters = place.distanceMeters,
        addressLabel = place.addressLabel ?? place.city,
        typeLabel = radarPlaceTypeLabel(place.type);

  _RadarEntry.activity(LocalActivity this.activity, this.distanceMeters)
      : place = null,
        category = radarCategoryForActivity(activity),
        title = activity.title,
        location = activity.location,
        addressLabel = activity.addressLabel,
        typeLabel = activity.category;

  final RadarPlace? place;
  final LocalActivity? activity;
  final RadarCategory category;
  final String title;
  final Coordinates location;
  final double distanceMeters;
  final String? addressLabel;
  final String? typeLabel;
}

class _RadiusSelector extends StatelessWidget {
  const _RadiusSelector({required this.options, required this.selected, required this.onSelected});

  final List<double> options;
  final double selected;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    // Wrap, not a horizontal scroller: the radius is the page's main
    // control and every option must be visible at once on narrow phones.
    return Wrap(
      spacing: AppSpacing.sm,
      children: options
          .map(
            (option) => RadarChip(
              label: '${option.round()} km',
              selected: selected == option,
              onTap: () => onSelected(option),
            ),
          )
          .toList(),
    );
  }
}

class _QuickCategoryBar extends StatelessWidget {
  const _QuickCategoryBar({
    required this.categories,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  final List<RadarCategory> categories;
  final Set<RadarCategory> selected;
  final ValueChanged<RadarCategory> onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: RadarChip(label: 'Tutti', selected: selected.isEmpty, onTap: onClear),
          ),
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: RadarChip(
                label: category.label,
                icon: category.icon,
                iconColor: category.color,
                selected: selected.contains(category),
                onTap: () => onToggle(category),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.center,
    required this.radiusKm,
    required this.items,
    required this.onExpand,
  });

  final Coordinates center;
  final double radiusKm;
  final List<RadarMapItem> items;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          children: [
            RadarMap(center: center, radiusKm: radiusKm, items: items),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Material(
                color: AppColors.surface,
                shape: const CircleBorder(),
                elevation: 2,
                child: IconButton(
                  tooltip: 'Apri la mappa a tutto schermo',
                  icon: const Icon(Icons.fullscreen),
                  onPressed: onExpand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageLoader extends StatelessWidget {
  const _PageLoader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: PetLoader(label: label),
      ),
    );
  }
}

/// Shown instead of a map on some default city when the app has no
/// position to center on: GPS unavailable or denied, and no home saved.
class _NoLocationState extends StatelessWidget {
  const _NoLocationState({required this.onOpenSettings, required this.onRetry});

  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined, size: 48, color: AppColors.mutedText),
            const SizedBox(height: AppSpacing.lg),
            Text('Imposta una località', style: AppTextStyles.title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Per mostrarti cosa c’è attorno a te serve la tua posizione. Consenti '
              'l’accesso alla posizione oppure indica la tua residenza in Impostazioni → Località.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Apri Impostazioni'),
            ),
            TextButton(onPressed: onRetry, child: const Text('Riprova')),
          ],
        ),
      ),
    );
  }
}

/// Loading, error and "served from an old import" states of the
/// OpenStreetMap part of the page.
class _RadarStatus extends StatelessWidget {
  const _RadarStatus({required this.result, required this.radiusKm, required this.onRetry});

  /// Null while the request is still running.
  final Result<RadarPlacesResult>? result;
  final double radiusKm;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null) {
      return Row(
        children: [
          const PetLoader.small(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              radiusKm > 10
                  ? 'Cerco i servizi entro ${radiusKm.round()} km. La prima volta in una zona '
                      'può richiedere fino a un minuto.'
                  : 'Cerco i servizi nella tua zona. La prima volta può richiedere qualche secondo.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      );
    }

    return result.fold(
      onFailure: (error) => Row(
        children: [
          Expanded(child: Text(error.message, style: AppTextStyles.bodySmall)),
          TextButton(onPressed: onRetry, child: const Text('Riprova')),
        ],
      ),
      onSuccess: (value) {
        if (!value.isStale && value.searchRadiusKm >= radiusKm) {
          return const SizedBox.shrink();
        }
        return Text(
          value.isStale
              ? 'Non sono riuscito ad aggiornare i servizi di questa zona: vedi gli ultimi '
                  'dati disponibili, che potrebbero non essere recenti.'
              : 'Per ora i servizi sono disponibili entro ${value.searchRadiusKm.round()} km: '
                  'riprova tra poco per il raggio completo.',
          style: AppTextStyles.caption,
        );
      },
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.entries,
    required this.expanded,
    required this.collapsedRows,
    required this.emptyLabel,
    required this.onToggleExpanded,
    required this.rowBuilder,
  });

  final List<_RadarEntry> entries;
  final bool expanded;
  final int collapsedRows;
  final String emptyLabel;
  final VoidCallback onToggleExpanded;
  final Widget Function(_RadarEntry entry) rowBuilder;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text(emptyLabel, style: AppTextStyles.bodySmall);
    }
    final visible = expanded ? entries : entries.take(collapsedRows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visible.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: rowBuilder(entry),
          ),
        ),
        if (entries.length > collapsedRows)
          TextButton(
            onPressed: onToggleExpanded,
            child: Text(expanded ? 'Mostra meno' : 'Mostra tutti (${entries.length})'),
          ),
      ],
    );
  }
}

/// "Servizi nella zona" split by category, each with its count and its
/// nearest few. One list sorted by distance buried the scarce categories
/// (a handful of groomers) under the abundant ones (hundreds of dog
/// parks), to the point of looking like there were none.
class _ServicesByCategory extends StatelessWidget {
  const _ServicesByCategory({
    required this.entries,
    required this.expanded,
    required this.collapsedRows,
    required this.onToggleExpanded,
    required this.onOpen,
  });

  /// Sorted by distance.
  final List<_RadarEntry> entries;
  final Set<RadarCategory> expanded;
  final int collapsedRows;
  final ValueChanged<RadarCategory> onToggleExpanded;
  final ValueChanged<_RadarEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text('Nessun servizio trovato con questi filtri.', style: AppTextStyles.bodySmall);
    }
    final groups = <Widget>[];
    for (final category in RadarCategory.values) {
      final group = entries.where((entry) => entry.category == category).toList();
      if (group.isEmpty) {
        continue;
      }
      final isExpanded = expanded.contains(category);
      groups.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(category.icon, color: category.color, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${category.label} (${group.length})',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ...(isExpanded ? group : group.take(collapsedRows)).map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ServiceRow(entry: entry, onTap: () => onOpen(entry)),
                ),
              ),
              if (group.length > collapsedRows)
                TextButton(
                  onPressed: () => onToggleExpanded(category),
                  child: Text(
                    isExpanded
                        ? 'Mostra meno'
                        : 'Mostra tutti: ${category.label.toLowerCase()} (${group.length})',
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: groups);
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.entry, required this.onTap});

  final _RadarEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final place = entry.place;
    final pending = place?.isPendingReport ?? false;
    return DashboardListRow(
      title: entry.title,
      subtitle: [
        if (pending) pendingPlaceLabel(place!),
        if (!pending && entry.typeLabel != null) entry.typeLabel!,
        if (entry.addressLabel != null) entry.addressLabel!,
        formatDistance(entry.distanceMeters),
      ].join(' · '),
      leading: RadarCategoryBadge(category: entry.category, pending: pending),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
      onTap: onTap,
    );
  }
}

/// Clinic row built for urgency: distance first, hours as stated, and the
/// two actions that matter (call, directions) one tap away.
class _ClinicRow extends StatelessWidget {
  const _ClinicRow({required this.entry, required this.onTap});

  final _RadarEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final place = entry.place;
    final hours = place?.openingHours;
    final pending = place?.isPendingReport ?? false;
    return DashboardListRow(
      title: entry.title,
      subtitle: [
        if (pending) pendingPlaceLabel(place!),
        formatDistance(entry.distanceMeters),
        if (entry.addressLabel != null) entry.addressLabel!,
        if (hours != null) formatOpeningHours(hours),
      ].join(' · '),
      leading: RadarCategoryBadge(category: entry.category, pending: pending),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (place?.phone != null)
            IconButton(
              tooltip: 'Chiama ${entry.title}',
              icon: Icon(Icons.call, color: RadarCategory.veterinary.color),
              onPressed: () => callRadarPlace(place!),
            ),
          IconButton(
            tooltip: 'Indicazioni per ${entry.title}',
            icon: const Icon(Icons.directions_outlined, color: AppColors.primary),
            onPressed: () => openDirections(entry.location),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
