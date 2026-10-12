import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../pets/data/pet_photo_repository.dart';
import '../../../pets/presentation/pages/pet_gallery_page.dart';
import '../../domain/photo_walk_match.dart';
import '../../domain/walk_photo_pins.dart';
import '../../domain/walk_route_markers.dart';
import '../../domain/walk_route_segments.dart';
import '../../domain/walk_session.dart';
import '../walk_labels.dart';
import '../widgets/walk_map_style.dart';
import '../widgets/walk_route_markers_layer.dart';

/// The pet's photo rows, for the pins on the map.
typedef WalkPhotosLoader = Future<List<PetPhotoEntry>> Function(String petId);

Future<List<PetPhotoEntry>> _loadPetPhotos(String petId) => PetPhotoRepository().list(petId);

/// Full-screen view of one completed walk from the history (owner request,
/// 2026-09-30: tapping a history card's map thumbnail used to do nothing).
/// Pause count is derived from the route's segment breaks
/// (walk_route_segments.dart) rather than a separately-stored counter -
/// every pause produces exactly one break, so segments.length - 1 is always
/// consistent with the route that's actually drawn.
///
/// Photos taken during the walk appear on the map where the walker was at that
/// moment (owner request, 2026-10-12): a photo's own GPS is stripped for
/// privacy, so the place comes from the route at the shooting time. Tapping a
/// pin opens the photo.
class WalkDetailPage extends StatefulWidget {
  const WalkDetailPage({
    super.key,
    required this.walk,
    required this.petName,
    this.photosLoader = _loadPetPhotos,
  });

  final WalkSession walk;
  final String petName;
  final WalkPhotosLoader photosLoader;

  @override
  State<WalkDetailPage> createState() => _WalkDetailPageState();
}

class _WalkDetailPageState extends State<WalkDetailPage> {
  Map<String, PetPhotoEntry> _photosById = const {};
  List<WalkPhotoPin> _pins = const [];

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  Future<void> _loadPins() async {
    try {
      final photos = [
        for (final photo in await widget.photosLoader(widget.walk.petId))
          if (!photo.isVideo) photo,
      ];
      if (!mounted) return;
      setState(() {
        _photosById = {for (final photo in photos) photo.id: photo};
        _pins = walkPhotoPins(
          widget.walk,
          [for (final photo in photos) (id: photo.id, takenAt: photo.takenAt)],
        );
      });
    } catch (_) {
      // Pins are an extra: the walk looks the same without them.
    }
  }

  void _openPhoto(WalkPhotoPin pin) {
    final photo = _photosById[pin.photoId];
    if (photo == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PetPhotoViewerPage(
          storagePath: photo.storagePath,
          caption: walkPhotoLabel(widget.walk),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walk = widget.walk;
    final segments = splitRouteIntoSegments(walk.route);
    final pauseCount = segments.isEmpty ? 0 : segments.length - 1;
    final markers = computeWalkRouteMarkers(walk.route, isFinished: true);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Passeggiata di ${widget.petName}', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _WalkDetailMap(
                segments: segments,
                markers: markers,
                pins: _pins,
                photosById: _photosById,
                onOpenPhoto: _openPhoto,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Text(walkDateLabel(walk.startedAt), style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(label: 'Distanza', value: walkDistanceLabel(walk.distanceMeters)),
                      _StatColumn(label: 'Durata', value: walkDurationLabel(walk.durationSeconds)),
                      if (pauseCount > 0)
                        _StatColumn(
                          label: pauseCount == 1 ? 'Pausa' : 'Pause',
                          value: '$pauseCount · ${walkDurationLabel(walk.pausedSeconds)}',
                        ),
                      if (_pins.isNotEmpty)
                        _StatColumn(label: 'Foto', value: '${_pins.length}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
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

class _WalkDetailMap extends StatelessWidget {
  const _WalkDetailMap({
    required this.segments,
    required this.markers,
    required this.pins,
    required this.photosById,
    required this.onOpenPhoto,
  });

  final List<List<RoutePoint>> segments;
  final WalkRouteMarkers markers;
  final List<WalkPhotoPin> pins;
  final Map<String, PetPhotoEntry> photosById;
  final void Function(WalkPhotoPin pin) onOpenPhoto;

  static const latlong.LatLng _fallbackCenter = latlong.LatLng(45.4642, 9.1900);

  @override
  Widget build(BuildContext context) {
    final allPoints = [
      for (final segment in segments)
        for (final point in segment) latlong.LatLng(point.coordinates.latitude, point.coordinates.longitude),
    ];

    return FlutterMap(
      options: allPoints.isEmpty
          ? const MapOptions(initialCenter: _fallbackCenter, initialZoom: 15)
          : MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(allPoints),
                padding: const EdgeInsets.all(48),
              ),
            ),
      children: [
        buildWalkTileLayer(),
        PolylineLayer(
          polylines: [
            for (final segment in segments)
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
        buildWalkRouteMarkersLayer(markers),
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
                    storagePath: photosById[pin.photoId]?.storagePath,
                    onTap: () => onOpenPhoto(pin),
                  ),
                ),
            ],
          ),
        buildWalkMapAttribution(),
      ],
    );
  }
}

/// A round thumbnail on the map with a white rim and a small camera badge;
/// the whole thing is the tap target for opening the photo.
class WalkPhotoPinMarker extends StatefulWidget {
  const WalkPhotoPinMarker({required this.storagePath, required this.onTap, super.key});

  final String? storagePath;
  final VoidCallback onTap;

  @override
  State<WalkPhotoPinMarker> createState() => _WalkPhotoPinMarkerState();
}

class _WalkPhotoPinMarkerState extends State<WalkPhotoPinMarker> {
  late final Future<Uint8List?> _bytes = widget.storagePath == null
      ? Future<Uint8List?>.value(null)
      : PetPhotoRepository().loadBytes(widget.storagePath!);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Foto scattata durante la passeggiata',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceElevated,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
              ),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<Uint8List?>(
                future: _bytes,
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null) {
                    return const Icon(Icons.photo_camera_rounded, size: 20, color: AppColors.mutedText);
                  }
                  return Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 120);
                },
              ),
            ),
            const Positioned(
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.photo_camera_rounded, size: 10, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
