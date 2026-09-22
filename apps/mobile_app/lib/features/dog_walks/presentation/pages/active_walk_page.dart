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
import '../../domain/walk_session.dart';
import '../../../location/data/device_location_service.dart';
import '../../../location/domain/coordinates.dart';
import '../walk_labels.dart';
import '../widgets/badge_earned_dialog.dart';

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
  });

  final PetProfile pet;

  /// Injectable so widget tests can substitute a fake initial fix instead
  /// of requiring a real device/browser GPS permission prompt.
  final LocationSampler locationSampler;

  /// Injectable so widget tests can feed a synthetic stream instead of a
  /// real continuous `Geolocator.getPositionStream()`.
  final Stream<Coordinates> Function()? positionStreamProvider;

  @override
  State<ActiveWalkPage> createState() => _ActiveWalkPageState();
}

class _ActiveWalkPageState extends State<ActiveWalkPage> {
  late final ActiveWalkController _controller = ActiveWalkController(
    repository: DogWalksRepository(),
  );

  bool _starting = false;
  String? _locationError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Stream<Coordinates> _defaultPositionStream() {
    return geolocator.Geolocator.getPositionStream(
      locationSettings: const geolocator.LocationSettings(
        accuracy: geolocator.LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).map((position) => Coordinates(latitude: position.latitude, longitude: position.longitude));
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _locationError = null;
    });

    final result = await widget.locationSampler.requestCurrentPosition();
    if (!result.isSuccess) {
      setState(() {
        _starting = false;
        _locationError =
            'Non riesco a rilevare la tua posizione: serve per tracciare il percorso. Controlla i permessi di localizzazione e riprova.';
      });
      return;
    }

    final stream = (widget.positionStreamProvider ?? _defaultPositionStream)();
    await _controller.start(
      ownerId: resolveCurrentOwnerId(),
      petId: widget.pet.id,
      positionStream: stream,
    );
    if (!mounted) return;
    setState(() => _starting = false);
  }

  Future<void> _stop() async {
    final repository = DogWalksRepository();
    final ownerId = resolveCurrentOwnerId();
    final beforeWalks = (await repository.loadWalks(ownerId))
        .where((walk) => walk.petId == widget.pet.id)
        .toList();
    final beforeBadges = evaluateBadges(beforeWalks).toSet();

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
            return Column(
              children: [
                Expanded(child: _WalkMap(walk: walk)),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      if (walk != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatColumn(label: 'Distanza', value: walkDistanceLabel(walk.distanceMeters)),
                            _StatColumn(
                              label: 'Punti GPS',
                              value: '${walk.route.length}',
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

class _WalkMap extends StatelessWidget {
  const _WalkMap({required this.walk});

  final WalkSession? walk;

  static const latlong.LatLng _fallbackCenter = latlong.LatLng(45.4642, 9.1900);

  @override
  Widget build(BuildContext context) {
    final route = walk?.route ?? const [];
    final center = route.isEmpty
        ? _fallbackCenter
        : latlong.LatLng(route.last.coordinates.latitude, route.last.coordinates.longitude);

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 16),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.vetapp.mobile_app',
        ),
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
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}
