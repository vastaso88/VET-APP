import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/walk_route_segments.dart';
import '../../domain/walk_session.dart';
import '../walk_labels.dart';
import '../widgets/walk_map_style.dart';

/// Full-screen view of one completed walk from the history (owner request,
/// 2026-09-30: tapping a history card's map thumbnail used to do nothing).
/// Pause count is derived from the route's segment breaks
/// (walk_route_segments.dart) rather than a separately-stored counter -
/// every pause produces exactly one break, so segments.length - 1 is always
/// consistent with the route that's actually drawn.
class WalkDetailPage extends StatelessWidget {
  const WalkDetailPage({super.key, required this.walk, required this.petName});

  final WalkSession walk;
  final String petName;

  @override
  Widget build(BuildContext context) {
    final segments = splitRouteIntoSegments(walk.route);
    final pauseCount = segments.isEmpty ? 0 : segments.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Passeggiata di $petName', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _WalkDetailMap(segments: segments)),
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
  const _WalkDetailMap({required this.segments});

  final List<List<RoutePoint>> segments;

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
                padding: const EdgeInsets.all(32),
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
        buildWalkMapAttribution(),
      ],
    );
  }
}
