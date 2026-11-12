import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../location/domain/coordinates.dart';
import '../../domain/walk_map_framing.dart';
import '../../domain/walk_route_markers.dart';
import '../../domain/walk_route_segments.dart';
import '../../domain/walk_session.dart';
import 'walk_map_style.dart';
import 'walk_route_markers_layer.dart';

/// Static preview of one walk's route for the history cards: framed on that
/// walk's own bounds (never fewer than ~250 m across, so a short walk is still
/// a readable line), a white-cased route line that stands out from the basemap,
/// and small start/finish dots that do not hide the path. [photoPoints] are
/// the places photos were taken on this walk (walk_photo_pins.dart), shown as
/// small coral dots.
///
/// FlutterMap reads its initial camera only once, when its State is created.
/// A list that reorders or drops cards reuses States by position, so the key
/// below carries the walk id and the route length: another walk (or the same
/// walk after its route changed) always builds a fresh map and frames itself.
class WalkMiniMap extends StatelessWidget {
  WalkMiniMap({required this.walk, this.photoPoints = const [], super.key})
      : _route = walk.route;

  final WalkSession walk;
  final List<Coordinates> photoPoints;
  final List<RoutePoint> _route;

  @override
  Widget build(BuildContext context) {
    final frame = walkMapFrame(_route);
    if (frame == null) return const WalkMapUnavailable();

    final segments = splitRouteIntoSegments(_route);
    final bounds = LatLngBounds(
      latlong.LatLng(frame.south, frame.west),
      latlong.LatLng(frame.north, frame.east),
    );

    return IgnorePointer(
      child: FlutterMap(
        key: ValueKey('walk-mini-map-${walk.id}-${_route.length}'),
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            maxZoom: 17,
          ),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          buildWalkTileLayer(),
          PolylineLayer(
            polylines: [
              for (final segment in segments)
                if (segment.length >= 2)
                  Polyline(
                    points: [
                      for (final point in segment)
                        latlong.LatLng(point.coordinates.latitude, point.coordinates.longitude),
                    ],
                    color: AppColors.primaryStrong,
                    strokeWidth: 5,
                    borderColor: AppColors.onMedia,
                    borderStrokeWidth: 2.5,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
            ],
          ),
          if (photoPoints.isNotEmpty)
            MarkerLayer(
              markers: [
                for (final point in photoPoints)
                  Marker(
                    point: latlong.LatLng(point.latitude, point.longitude),
                    width: 14,
                    height: 14,
                    child: const DecoratedBox(
                      key: ValueKey('walk-mini-photo-dot'),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryStrong,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(BorderSide(color: AppColors.onMedia, width: 2)),
                      ),
                    ),
                  ),
              ],
            ),
          buildWalkRouteMarkersLayer(
            computeWalkRouteMarkers(_route, isFinished: true),
            compact: true,
          ),
          // The basemap's credit, kept to a tiny non-interactive line: the
          // stock attribution widgets are sized for full-screen maps.
          const Align(
            alignment: Alignment.bottomRight,
            child: DecoratedBox(
              decoration: BoxDecoration(color: AppColors.onMediaMuted),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text('© OpenStreetMap', style: TextStyle(fontSize: 9, color: AppColors.text)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the map when a walk has no drawable path - its route was
/// removed by the retention cleanup, was saved before GPS tracking existed, or
/// holds a single point.
class WalkMapUnavailable extends StatelessWidget {
  const WalkMapUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, color: AppColors.mutedText, size: 28),
          const SizedBox(height: 4),
          Text(context.l10n.walksMapUnavailable, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
