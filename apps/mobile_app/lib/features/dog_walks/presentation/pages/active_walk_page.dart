import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/auth/current_owner.dart';
import '../../../pets/domain/pet_models.dart';
import '../../data/active_walk_controller.dart';
import '../../data/dog_walks_repository.dart';
import '../../domain/badges.dart';
import '../../domain/walk_retention.dart';
import '../../domain/walk_session.dart';
import '../../../location/data/device_location_service.dart';
import '../../../location/domain/coordinates.dart';
import '../walk_labels.dart';
import '../widgets/badge_earned_dialog.dart';
import '../widgets/favorite_eviction_dialog.dart';
import '../widgets/walk_map_style.dart';

/// Live start/stop tracking for one pet's walk. Kept as its own page
/// (rather than inline in pet_detail_page.dart, unlike the simpler tabs)
/// because it owns a live GPS stream and a map, not just a repository
/// FutureBuilder.
class ActiveWalkPage extends StatefulWidget {
  const ActiveWalkPage({
    super.key,
    required this.pet,
    this.locationSampler = const GeolocatorLocationSampler(),
    this.positionStreamProvider,
    this.autoStart = false,
  });

  final PetProfile pet;

  /// Injectable so widget tests can substitute a fake initial fix instead
  /// of requiring a real device/browser GPS permission prompt.
  final LocationSampler locationSampler;

  /// Injectable so widget tests can feed a synthetic stream instead of a
  /// real continuous `Geolocator.getPositionStream()`. Note this bypasses
  /// the heading indicator too (it only reads from the real device stream)
  /// - fine for tests, which don't assert on it.
  final Stream<Coordinates> Function()? positionStreamProvider;

  /// Starts tracking as soon as this page opens instead of waiting for the
  /// "Avvia passeggiata" tap - set when launched by tapping a pet on the
  /// "Passeggiate" home-screen widget (see walk_home_widget.dart), which is
  /// meant to jump straight into a walk for that pet.
  final bool autoStart;

  @override
  State<ActiveWalkPage> createState() => _ActiveWalkPageState();
}

class _ActiveWalkPageState extends State<ActiveWalkPage> {
  late final ActiveWalkController _controller = ActiveWalkController(
    repository: DogWalksRepository(),
  );
  final MapController _mapController = MapController();

  bool _starting = false;
  String? _locationError;
  Timer? _elapsedTimer;
  StreamSubscription<geolocator.Position>? _headingSubscription;
  double? _headingDegrees;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _headingSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// On Android, runs GPS updates as a foreground service with a persistent
  /// notification so tracking survives the owner switching to another app
  /// mid-walk (owner report, 2026-09-29). This only needs the foreground
  /// location permission the app already requests - it's not
  /// ACCESS_BACKGROUND_LOCATION ("Allow all the time"), which
  /// docs/compliance/05_permessi_dispositivo_os.md explicitly defers. Other
  /// platforms keep the plain settings; iOS has no equivalent knob here and
  /// web ignores AndroidSettings.
  geolocator.LocationSettings _positionStreamSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return geolocator.AndroidSettings(
        accuracy: geolocator.LocationAccuracy.high,
        distanceFilter: 5,
        foregroundNotificationConfig: const geolocator.ForegroundNotificationConfig(
          notificationTitle: 'Passeggiata in corso',
          notificationText: 'VetApp sta tracciando il percorso della passeggiata.',
          notificationChannelName: 'Tracciamento passeggiata',
          setOngoing: true,
        ),
      );
    }
    return const geolocator.LocationSettings(
      accuracy: geolocator.LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  Stream<geolocator.Position> _defaultRawPositionStream() {
    return geolocator.Geolocator.getPositionStream(locationSettings: _positionStreamSettings());
  }

  void _onRawPosition(geolocator.Position position) {
    // Course-over-ground, not a magnetometer compass: only meaningful while
    // actually moving, which fits a walk tracker. Not reliably available on
    // every platform (notably web), so the indicator just stays hidden.
    if (position.heading.isNaN || position.heading < 0 || position.heading > 360) {
      return;
    }
    setState(() => _headingDegrees = position.heading);
  }

  Coordinates? get _currentPosition {
    final route = _controller.walk?.route;
    if (route == null || route.isEmpty) return null;
    return route.last.coordinates;
  }

  void _centerOnMe() {
    final position = _currentPosition;
    if (position == null) return;
    _mapController.move(latlong.LatLng(position.latitude, position.longitude), 16);
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _locationError = null;
    });

    final result = await widget.locationSampler.requestCurrentPosition();
    if (!result.isSuccess) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _locationError =
            'Non riesco a rilevare la tua posizione: serve per tracciare il percorso. Controlla i permessi di localizzazione e riprova.';
      });
      return;
    }

    final Stream<Coordinates> stream;
    if (widget.positionStreamProvider != null) {
      stream = widget.positionStreamProvider!();
    } else {
      final raw = _defaultRawPositionStream().asBroadcastStream();
      _headingSubscription = raw.listen(_onRawPosition);
      stream = raw.map(
        (position) => Coordinates(latitude: position.latitude, longitude: position.longitude),
      );
    }

    await _controller.start(
      ownerId: resolveCurrentOwnerId(),
      petId: widget.pet.id,
      positionStream: stream,
    );
    if (!mounted) return;
    setState(() => _starting = false);
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _stop() async {
    final repository = DogWalksRepository();
    final ownerId = resolveCurrentOwnerId();
    final beforeWalks = (await repository.loadWalks(ownerId))
        .where((walk) => walk.petId == widget.pet.id)
        .toList();
    final beforeBadges = evaluateBadges(beforeWalks).toSet();

    _elapsedTimer?.cancel();
    await _controller.stop();
    if (!mounted) return;

    final afterWalks = (await repository.loadWalks(ownerId))
        .where((walk) => walk.petId == widget.pet.id)
        .toList();
    final afterBadges = evaluateBadges(afterWalks);
    final newlyEarned = afterBadges.where((badge) => !beforeBadges.contains(badge)).toList();

    if (!mounted) return;
    if (newlyEarned.isNotEmpty) {
      await showBadgeEarnedDialog(context, newlyEarned);
    }

    final finishedWalk = _controller.walk;
    if (finishedWalk != null) {
      if (!mounted) return;
      await _promptSaveAsFavorite(repository, ownerId, finishedWalk);
    }
    await repository.pruneRoutesOutsideRetention(ownerId, widget.pet.id);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _promptSaveAsFavorite(
    DogWalksRepository repository,
    String ownerId,
    WalkSession walk,
  ) async {
    final wantsFavorite = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salva tra le preferite?'),
        content: Text(
          'Vuoi aggiungere questa passeggiata (${walkDistanceLabel(walk.distanceMeters)}) '
          'alle tue preferite ⭐?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, grazie'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salva ⭐'),
          ),
        ],
      ),
    );
    if (wantsFavorite != true) return;
    if (!mounted) return;

    final existingFavorites = (await repository.loadWalks(ownerId))
        .where((item) => item.petId == widget.pet.id && item.isFavorite)
        .toList();

    if (existingFavorites.length >= maxFavoriteWalks) {
      if (!mounted) return;
      final walkIdToEvict = await pickFavoriteToEvict(context, existingFavorites);
      if (walkIdToEvict == null) return;
      final toEvict = existingFavorites.firstWhere((item) => item.id == walkIdToEvict);
      await repository.saveWalk(toEvict.copyWith(isFavorite: false));
    }

    await repository.saveWalk(walk.copyWith(isFavorite: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Passeggiata di ${widget.pet.name}', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final walk = _controller.walk;
            final elapsedSeconds =
                walk != null ? DateTime.now().difference(walk.startedAt).inSeconds : null;
            return Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      _WalkMap(walk: walk, mapController: _mapController),
                      if (_headingDegrees != null)
                        Positioned(
                          top: AppSpacing.md,
                          right: AppSpacing.md,
                          child: _HeadingIndicator(headingDegrees: _headingDegrees!),
                        ),
                      Positioned(
                        bottom: AppSpacing.md,
                        right: AppSpacing.md,
                        child: FloatingActionButton.small(
                          heroTag: 'center-on-me',
                          onPressed: _currentPosition == null ? null : _centerOnMe,
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.primary,
                          child: const Icon(Icons.my_location_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      if (walk != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatColumn(label: 'Distanza', value: walkDistanceLabel(walk.distanceMeters)),
                            _StatColumn(label: 'Durata', value: walkElapsedLabel(elapsedSeconds!)),
                          ],
                        ),
                      if (_locationError != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _locationError!,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _starting
                              ? null
                              : (_controller.isActive ? _stop : _start),
                          style: FilledButton.styleFrom(
                            backgroundColor: _controller.isActive ? AppColors.danger : AppColors.primary,
                          ),
                          icon: Icon(_controller.isActive ? Icons.stop_rounded : Icons.play_arrow_rounded),
                          label: Text(
                            _starting
                                ? 'Avvio...'
                                : (_controller.isActive ? 'Ferma passeggiata' : 'Avvia passeggiata'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.heading),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

/// North-up map: a fixed compass badge whose arrow rotates to the device's
/// current heading, rather than rotating the whole map (owner's choice,
/// 2026-09-27 - less disorienting when stopping/turning often on a walk).
class _HeadingIndicator extends StatelessWidget {
  const _HeadingIndicator({required this.headingDegrees});

  final double headingDegrees;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
      ),
      child: Transform.rotate(
        angle: headingDegrees * (math.pi / 180),
        child: const Icon(Icons.navigation_rounded, color: AppColors.primary),
      ),
    );
  }
}

class _WalkMap extends StatelessWidget {
  const _WalkMap({required this.walk, required this.mapController});

  final WalkSession? walk;
  final MapController mapController;

  static const latlong.LatLng _fallbackCenter = latlong.LatLng(45.4642, 9.1900);

  @override
  Widget build(BuildContext context) {
    final route = walk?.route ?? const [];
    final center = route.isEmpty
        ? _fallbackCenter
        : latlong.LatLng(route.last.coordinates.latitude, route.last.coordinates.longitude);

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(initialCenter: center, initialZoom: 16),
      children: [
        buildWalkTileLayer(),
        if (route.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route
                    .map((point) => latlong.LatLng(point.coordinates.latitude, point.coordinates.longitude))
                    .toList(),
                color: AppColors.primary,
                strokeWidth: 4,
              ),
            ],
          ),
        if (route.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 28,
                height: 28,
                child: const Icon(Icons.pets, color: AppColors.primaryStrong),
              ),
            ],
          ),
        buildWalkMapAttribution(),
      ],
    );
  }
}
