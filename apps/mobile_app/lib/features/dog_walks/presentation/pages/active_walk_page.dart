import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/pet_loader.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/auth/current_owner.dart';
import '../../../pets/data/pet_media_capture.dart';
import '../../../pets/data/pet_photo_repository.dart';
import '../../../pets/domain/pet_models.dart';
import '../../../pets/domain/pet_video_rules.dart';
import '../../../pets/presentation/pages/pet_gallery_page.dart' show PetPhotoViewerPage;
import '../../data/active_walk_controller.dart';
import '../../domain/gps_fix.dart';
import '../../domain/photo_walk_match.dart';
import '../../domain/walk_photo_pins.dart';
import '../../domain/walk_route_markers.dart';
import '../../domain/walk_route_segments.dart';
import '../../domain/walk_session.dart';
import '../../../location/data/device_location_service.dart';
import '../../../location/domain/coordinates.dart';
import '../walk_completion_flow.dart';
import 'walk_detail_page.dart' show WalkPhotoPinMarker;
import '../walk_labels.dart';
import '../walk_notification_permission.dart';
import '../widgets/walk_map_style.dart';
import '../widgets/walk_route_markers_layer.dart';

/// Live start/stop/pause tracking for one pet's walk. The tracking itself
/// lives in ActiveWalkController.instance, an app-lifetime singleton - not
/// in this page's State - so navigating away no longer stops it (owner
/// report, 2026-09-29). This page is just that singleton's UI: a map, the
/// live stats, and the start/pause/stop controls.
/// What the camera button of a walk in progress records.
enum WalkCaptureKind { photo, video }

class ActiveWalkPage extends StatefulWidget {
  const ActiveWalkPage({
    super.key,
    required this.pet,
    this.locationSampler = const GeolocatorLocationSampler(),
    this.positionStreamProvider,
    this.autoStart = false,
    this.autoCapture,
    this.capture,
    this.photosLoader,
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

  /// Opens the system camera as soon as the page is up - set by the walk
  /// control sheet ("Scatta foto" / "Registra video" on the banner).
  final WalkCaptureKind? autoCapture;

  /// Injectable so tests need no camera; defaults to the real flow.
  final PetMediaCapture? capture;

  /// Injectable so tests need no backend; defaults to the pet photo rows.
  final Future<List<PetPhotoEntry>> Function(String petId)? photosLoader;

  @override
  State<ActiveWalkPage> createState() => _ActiveWalkPageState();
}

class _ActiveWalkPageState extends State<ActiveWalkPage> {
  final ActiveWalkController _controller = ActiveWalkController.instance;
  final MapController _mapController = MapController();

  bool _starting = false;

  /// A pause/resume or the end-of-walk save is still running: the buttons
  /// show it and refuse a second tap instead of looking dead for seconds.
  bool _togglingPause = false;
  bool _stopping = false;
  String? _locationError;
  Timer? _elapsedTimer;
  Coordinates? _initialMapCenter;
  bool _loadingInitialPosition = false;

  /// Photo and video taken without leaving the walk (owner request,
  /// 2026-10-12). The walk itself is untouched while the system camera is in
  /// front: tracking lives in ActiveWalkController.instance and the walk
  /// foreground service, not in this page.
  late final PetMediaCapture _capture = widget.capture ?? PetMediaCapture();

  /// This pet photo rows (no bytes), for the pins of the shots taken on this walk.
  List<PetPhotoEntry> _photos = const [];

  @override
  void initState() {
    super.initState();
    _capture.addListener(_onCaptureChanged);
    PetPhotoRepository.changes.addListener(_loadPhotos);
    _loadPhotos();
    final autoCapture = widget.autoCapture;
    if (autoCapture != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _capturePhotoOrVideo(autoCapture));
    }
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
    PetPhotoRepository.changes.removeListener(_loadPhotos);
    _capture
      ..removeListener(_onCaptureChanged)
      ..dispose();
    _elapsedTimer?.cancel();
    // ActiveWalkController.instance outlives this page on purpose - it is
    // NOT disposed here, unlike a page-owned controller would be.
    super.dispose();
  }

  void _onCaptureChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await (widget.photosLoader ?? PetPhotoRepository().list)(widget.pet.id);
      if (!mounted) return;
      setState(() => _photos = [for (final photo in photos) if (!photo.isVideo) photo]);
    } catch (_) {
      // Pins are an extra: the walk looks the same without them.
    }
  }

  /// Where the photos taken during this walk were taken, from the route so far.
  List<WalkPhotoPin> get _pins {
    final walk = _controller.walk;
    if (walk == null || walk.petId != widget.pet.id) return const [];
    return walkPhotoPins(
      walk,
      [for (final photo in _photos) (id: photo.id, takenAt: photo.takenAt)],
    );
  }

  void _openPhoto(WalkPhotoPin pin) {
    final photo = _photos.where((item) => item.id == pin.photoId).firstOrNull;
    if (photo == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PetPhotoViewerPage(
          storagePath: photo.storagePath,
          caption: _controller.walk == null ? null : walkPhotoLabel(_controller.walk!),
        ),
      ),
    );
  }

  Future<void> _showCaptureSheet() async {
    final kind = await showModalBottomSheet<WalkCaptureKind>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.l10n.walksCaptureTakePhoto),
              onTap: () => Navigator.of(sheetContext).pop(WalkCaptureKind.photo),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(context.l10n.walksCaptureRecordVideo),
              subtitle: Text(context.l10n.walksCaptureVideoLimit(petVideoMaxSeconds)),
              onTap: () => Navigator.of(sheetContext).pop(WalkCaptureKind.video),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    await _capturePhotoOrVideo(kind);
  }

  /// Opens the system camera, uploads the result to this pet gallery and says
  /// so. The walk goes on meanwhile; the new photo shows on the map right away.
  Future<void> _capturePhotoOrVideo(WalkCaptureKind kind) async {
    if (_capture.busy || !mounted) return;
    final petId = widget.pet.id;
    final result = await (kind == WalkCaptureKind.photo
        ? _capture.takePhoto(petId)
        : _capture.recordVideo(petId));
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.confirmation(widget.pet.name))),
    );
    unawaited(_loadPhotos());
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
        _locationError = context.l10n.walksErrorOtherPetActive;
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
        _locationError = context.l10n.walksErrorLocationUnavailable;
      });
      return;
    }

    // First walk only: explain the walk notification and ask to show it.
    if (!mounted) return;
    await maybeAskWalkNotificationPermission(context);
    if (!mounted) return;

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
    if (walk == null || _togglingPause || _stopping) return;
    setState(() => _togglingPause = true);
    try {
      if (walk.isPaused) {
        await _controller.resume();
      } else {
        await _controller.pause();
      }
    } finally {
      if (mounted) setState(() => _togglingPause = false);
    }
  }

  Future<void> _stop() async {
    if (_stopping || _togglingPause) return;
    setState(() => _stopping = true);
    _elapsedTimer?.cancel();
    try {
      await finishActiveWalk(context, widget.pet);
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
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
        title: Text(context.l10n.walksPageTitle(widget.pet.name), style: AppTextStyles.title),
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
                              pins: _pins,
                              photoPaths: {
                                for (final photo in _photos) photo.id: photo.storagePath,
                              },
                              onOpenPhoto: _openPhoto,
                            ),
                            if (_controller.headingDegrees != null)
                              Positioned(
                                top: AppSpacing.md,
                                right: AppSpacing.md,
                                child: _HeadingIndicator(headingDegrees: _controller.headingDegrees!),
                              ),
                            if (_controller.isAwaitingAccurateFix)
                              Positioned(
                                top: AppSpacing.md,
                                left: AppSpacing.md,
                                child: _InfoPill(text: context.l10n.walksWaitingForGps),
                              )
                            else if (walk?.isPaused ?? false)
                              Positioned(
                                top: AppSpacing.md,
                                left: AppSpacing.md,
                                child: _InfoPill(text: context.l10n.walksStatusPaused),
                              ),
                            if (_controller.isActive && !_stopping)
                              Positioned(
                                bottom: AppSpacing.md + 48,
                                right: AppSpacing.md,
                                child: FloatingActionButton.small(
                                  heroTag: 'walk-camera',
                                  tooltip: context.l10n.walksCameraTooltip,
                                  onPressed: _capture.busy ? null : _showCaptureSheet,
                                  backgroundColor: AppColors.surface,
                                  foregroundColor: AppColors.primary,
                                  child: const Icon(Icons.photo_camera_rounded),
                                ),
                              ),
                            if (_capture.busy)
                              Positioned.fill(
                                child: _CaptureOverlay(capture: _capture),
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
                            _StatColumn(
                              label: context.l10n.walksStatDistance,
                              value: walkDistanceLabel(walk.distanceMeters),
                            ),
                            _StatColumn(
                              label: context.l10n.walksStatDuration,
                              value: walkElapsedLabel(activeSeconds!),
                            ),
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
                                onPressed: _togglingPause || _stopping ? null : _togglePause,
                                icon: _togglingPause
                                    ? const PetLoader.small()
                                    : Icon(
                                        walk!.isPaused
                                            ? Icons.play_arrow_rounded
                                            : Icons.pause_rounded,
                                      ),
                                label: Text(
                                  walk!.isPaused
                                      ? context.l10n.walksActionResume
                                      : context.l10n.walksActionPause,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _stopping || _togglingPause ? null : _stop,
                                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                                icon: _stopping
                                    ? const PetLoader.small()
                                    : const Icon(Icons.stop_rounded),
                                label: Text(
                                  _stopping
                                      ? context.l10n.walksActionSaving
                                      : context.l10n.walksActionFinish,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _starting ? null : _start,
                            icon: _starting
                                ? const PetLoader.small()
                                : const Icon(Icons.play_arrow_rounded),
                            label: Text(
                              _starting
                                  ? context.l10n.walksActionStarting
                                  : context.l10n.walksActionStart,
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

/// Dims the map while a photo or video is being prepared and uploaded, with
/// the same progress and Annulla as the gallery.
class _CaptureOverlay extends StatelessWidget {
  const _CaptureOverlay({required this.capture});

  final PetMediaCapture capture;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PetLoader(label: capture.progress, color: Colors.white),
            if (capture.compressFraction case final fraction?) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: fraction,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
            ],
            if (capture.canCancel) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: capture.cancelling ? null : capture.cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                child: Text(context.l10n.commonCancel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WalkMap extends StatelessWidget {
  const _WalkMap({
    required this.walk,
    required this.mapController,
    this.fallbackCenter,
    this.pins = const [],
    this.photoPaths = const {},
    this.onOpenPhoto,
  });

  final WalkSession? walk;
  final MapController mapController;

  /// Where the photos of this walk were taken, with their storage paths by
  /// photo id (for the thumbnails); tapping a pin calls [onOpenPhoto].
  final List<WalkPhotoPin> pins;
  final Map<String, String> photoPaths;
  final void Function(WalkPhotoPin pin)? onOpenPhoto;

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
        if (pins.isNotEmpty)
          MarkerLayer(
            markers: [
              for (final pin in pins)
                Marker(
                  point: latlong.LatLng(pin.at.latitude, pin.at.longitude),
                  width: 50,
                  height: 50,
                  child: WalkPhotoPinMarker(
                    key: ValueKey('walk-photo-pin-${pin.photoId}'),
                    storagePath: photoPaths[pin.photoId],
                    onTap: () => onOpenPhoto?.call(pin),
                  ),
                ),
            ],
          ),
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
