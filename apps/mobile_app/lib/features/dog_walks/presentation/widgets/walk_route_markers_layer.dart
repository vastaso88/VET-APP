import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../design_system/tokens/app_colors.dart';
import '../../domain/walk_route_markers.dart';

/// Start/pause/finish markers for a walk's map - shared by the history
/// thumbnail, the full-screen detail page, and the live tracker so all
/// three read the same way (owner request, 2026-09-30). Sizes are
/// deliberately different (finish/start biggest, pause smallest) rather
/// than three identical pins.
MarkerLayer buildWalkRouteMarkersLayer(WalkRouteMarkers markers) {
  return MarkerLayer(
    markers: [
      if (markers.start != null)
        Marker(
          point: latlong.LatLng(markers.start!.latitude, markers.start!.longitude),
          width: 26,
          height: 26,
          child: const Icon(Icons.flag_circle_rounded, color: AppColors.success, size: 26),
        ),
      for (final pause in markers.pausePoints)
        Marker(
          point: latlong.LatLng(pause.latitude, pause.longitude),
          width: 18,
          height: 18,
          child: const Icon(Icons.pause_circle_filled_rounded, color: AppColors.warning, size: 18),
        ),
      if (markers.finish != null)
        Marker(
          point: latlong.LatLng(markers.finish!.latitude, markers.finish!.longitude),
          width: 28,
          height: 28,
          child: const Icon(Icons.sports_score_rounded, color: AppColors.primaryStrong, size: 28),
        ),
    ],
  );
}
