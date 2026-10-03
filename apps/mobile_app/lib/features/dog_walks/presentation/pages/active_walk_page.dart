import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/pet_loader.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/auth/current_owner.dart';
import '../../../pets/domain/pet_models.dart';
import '../../data/active_walk_controller.dart';
import '../../domain/gps_fix.dart';
import '../../domain/walk_route_markers.dart';
import '../../domain/walk_route_segments.dart';
import '../../domain/walk_session.dart';
import '../../../location/data/device_location_service.dart';
import '../../../location/domain/coordinates.dart';
import '../walk_completion_flow.dart';
import '../walk_labels.dart';
import '../widgets/walk_map_style.dart';
import '../widgets/walk_route_markers_layer.dart';

/// Live start/stop/pause tracking for one pet's walk. The tracking itself
/// lives in ActiveWalkController.instance, an app-lifetime singleton - not
/// in this page's State - so navigating away no longer stops it (owner
/// report, 2026-09-29). This page is just that singleton's UI: a map, the
/// live stats, and the start/pause/stop controls.
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
  /// real continuous `Geolocator.getPositionStream()`.
  final Stream<GpsFix> Function()? positionStreamProvider;

  /// Starts tracking as soon as this page opens instead of waiting for the
  /// "Avvia passeggiata" tap - set when launched by tapping a pet on the
  /// "Passeggiate" home-screen widget (see walk_home_widget.dart), which is
  /// meant to jump straight into a walk for that pet.
  final bool autoStart;

  @override
  State<ActiveWalkPage> createState() => _ActiveWalkPageState();
}

class _ActiveWalkPageState extends State<ActiveWalkPage> {
  final ActiveWalkController _controller = ActiveWalkController.instance;
  final MapController _mapController = MapController();

  bool _starting = false;
  String? _locationError;
  Timer? _elapsedTimer;
  Coordinates? _initialMapCenter;
  bool _loadingInitialPosition = false;

  @override
  void initState() {
    super.initState();
    final resuming = _controller.isActive && _controller.walk?.petId == widget.pet.id;
    if (resuming) {
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (widget.autoStart && !_controller.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    } else if (_controller.walk == null || _controller.walk!.route.isEmpty) {
      // No route to center on yet (a fresh page, or a just-started walk
      // still waiting for an accurate first fix) - get the device's real
      // position so the map doesn't default to piazza Duomo (owner report,
      // 2026-09-29). Runs even if a different pet's walk is active, purely
      // to center the idle map - _start() below is what actually blocks
      // starting a second walk.
      _loadInitialPosition();
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    // ActiveWalkController.instance outlives this page on purpose - it is
    // NOT disposed here, unlike a page-owned controller would be.
    super.dispose();
  }

  Future<void> _loadInitialPosition() async {
    setState(() => _loadingInitialPosition = true);
    final result = await widget.locationSampler.requestCurrentPosition();
    if (!mounted) return;
    setState(() {
      _initialMapCenter = result.coordinates;
      _loadingInitialPosition = false;
    });
  }

  Coordinates? get _currentPosition {
    final route = _controller.walk?.route;
    if (route == null || route.isEmpty) return _initialMapCenter;
    return route.last.coordinates;
  }

  void _centerOnMe() {
    final position = _currentPosition;
    if (position == null) return;
    _mapController.move(latlong.LatLng(position.latitude, position.longitude), 16);
  }

  Future<void> _start() async {
    if (_controller.isActive && _controller.walk?.petId != widget.pet.id) {
      setState(() {
        _locationError =
            'C\'è già una passeggiata in corso con un altro pet: terminala prima di iniziarne una nuova.';
      });
      return;
    }

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

    await _controller.start(
      ownerId: resolveCurrentOwnerId(),
      petId: widget.pet.id,
      positionStream: widget.positionStreamProvider?.call(),
    );
    if (!mounted) return;
    setState(() => _starting = false);
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _togglePause() async {
    final walk = _controller.walk;
    if (walk == null) return;
    if (walk.isPaused) {
      await _controller.resume();
    } else {
      await _controller.pause();
    }
  }

  Future<void> _stop() async {
    _elapsedTimer?.cancel();
    await finishActiveWalk(context, widget.pet);
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
            final activeSeconds = walk != null ? walkActiveDurationSeconds(walk) : null;
            final showSpinner = _loadingInitialPosition && (walk == null || walk.route.isEmpty);
            return Column(
              children: [
                Expanded(
                  child: showSpinner
                      ? const Center(child: PetLoader())
                      : Stack(
                          children: [
                            _WalkMap(
                              walk: walk,
                              mapController: _mapController,
                              fallbackCenter: _initialMapCenter,
                            ),
                            if (_controller.headingDegrees != null)
                              Positioned(
                                top: AppSpacing.md,
                                right: AppSpacing.md,
                                child: _HeadingIndicator(headingDegrees: _controller.headingDegrees!),
                              ),
                            if (_controller.isAwaitingAccurateFix)
                              const Positioned(
                                top: AppSpacing.md,
                                left: AppSpacing.md,
                                child: _InfoPill(text: 'In attesa di un segnale GPS preciso…'),
                              )
                            else if (walk?.isPaused ?? false)
                              const Positioned(
                                top: AppSpacing.md,
                                left: AppSpacing.md,
                                child: _InfoPill(text: 'Passeggiata in pausa'),
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
                            _StatColumn(label: 'Durata', value: walkElapsedLabel(activeSeconds!)),
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
                      if (_controller.isActive)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _togglePause,
                                icon: Icon(
                                  walk!.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                ),
                                label: Text(walk.isPaused ? 'Riavvia' : 'Pausa'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _stop,
                                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                                icon: const Icon(Icons.stop_rounded),
                                label: const Text('Termina'),
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _starting ? null : _start,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(_starting ? 'Avvio...' : 'Avvia passeggiata'),
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
      ),
      child: Text(text, style: AppTextStyles.caption),
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
  const _WalkMap({required this.walk, required this.mapController, this.fallbackCenter});

  final WalkSession? walk;
  final MapController mapController;

  /// The device's real position, used only while there's no route yet -
  /// null falls back to [_defaultFallbackCenter] (permission denied, or
  /// still loading).
  final Coordinates? fallbackCenter;

  static const latlong.LatLng _defaultFallbackCenter = latlong.LatLng(45.4642, 9.1900);

  @override
  Widget build(BuildContext context) {
    final route = walk?.route ?? const [];
    final latlong.LatLng center;
    if (route.isNotEmpty) {
      center = latlong.LatLng(route.last.coordinates.latitude, route.last.coordinates.longitude);
    } else if (fallbackCenter != null) {
      center = latlong.LatLng(fallbackCenter!.latitude, fallbackCenter!.longitude);
    } else {
      center = _defaultFallbackCenter;
    }

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(initialCenter: center, initialZoom: 16),
      children: [
        buildWalkTileLayer(),
        PolylineLayer(
          // Split at Pausa/Riavvia boundaries (walk_route_segments.dart) so
          // resuming after a pause never draws a line across whatever
          // ground was covered while paused.
          polylines: [
            for (final segment in splitRouteIntoSegments(route))
              if (segment.length >= 2)
                Polyline(
                  points: segment
                      .map((point) => latlong.LatLng(point.coordinates.latitude, point.coordinates.longitude))
                      .toList(),
                  color: AppColors.primary,
                  strokeWidth: 4,
                ),
          ],
        ),
        // isFinished: false - a walk still in progress has no finish marker
        // yet, only start + wherever it's been paused so far.
        buildWalkRouteMarkersLayer(computeWalkRouteMarkers(route, isFinished: false)),
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
