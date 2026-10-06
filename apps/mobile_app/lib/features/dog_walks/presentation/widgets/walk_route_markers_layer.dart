import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../design_system/tokens/app_colors.dart';
import '../../../location/domain/coordinates.dart';
import '../../domain/walk_route_markers.dart';

/// Start/pause/finish markers for a walk's map - shared by the history
/// thumbnail, the full-screen detail page, and the live tracker so all
/// three read the same way (owner request, 2026-09-30). Sizes are
/// deliberately different (finish/start biggest, pause smallest) rather
/// than three identical pins.
///
/// [compact] is for the history thumbnail: small round dots with a white rim
/// (green start, dark finish, amber pauses) that leave the path itself visible
/// instead of big icons sitting on top of it.
MarkerLayer buildWalkRouteMarkersLayer(WalkRouteMarkers markers, {bool compact = false}) {
  if (compact) {
    return MarkerLayer(
      markers: [
        for (final pause in markers.pausePoints)
          _dot(pause, AppColors.warning, 11),
        if (markers.start != null) _dot(markers.start!, AppColors.success, 16),
        if (markers.finish != null) _dot(markers.finish!, AppColors.primaryStrong, 16, icon: Icons.flag_rounded),
      ],
    );
  }
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

Marker _dot(Coordinates at, Color color, double size, {IconData? icon}) {
  return Marker(
    point: latlong.LatLng(at.latitude, at.longitude),
    width: size,
    height: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
      child: icon == null ? null : Icon(icon, color: Colors.white, size: size * 0.55),
    ),
  );
}
