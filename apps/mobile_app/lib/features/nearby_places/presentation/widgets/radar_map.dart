import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../location/domain/coordinates.dart';
import '../radar_category.dart';

/// One marker on the radar map, whatever it stands for (an OpenStreetMap
/// place, an event, a user-submitted service).
class RadarMapItem {
  const RadarMapItem({
    required this.category,
    required this.location,
    required this.label,
    required this.onTap,
  });

  final RadarCategory category;
  final Coordinates location;
  final String label;
  final VoidCallback onTap;
}

/// Zoom that roughly fits a circle of [radiusKm] in the map viewport.
double radarZoomForRadius(double radiusKm) {
  if (radiusKm <= 5) return 12.5;
  if (radiusKm <= 10) return 11.5;
  if (radiusKm <= 25) return 10;
  return 9;
}

class RadarMap extends StatelessWidget {
  const RadarMap({
    super.key,
    required this.center,
    required this.radiusKm,
    required this.items,
    this.interactive = true,
  });

  final Coordinates center;
  final double radiusKm;
  final List<RadarMapItem> items;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final centerPoint = latlong.LatLng(center.latitude, center.longitude);
    return FlutterMap(
      // Re-created when the radius changes so the new zoom is applied.
      key: ValueKey('radar-map-$radiusKm'),
      options: MapOptions(
        initialCenter: centerPoint,
        initialZoom: radarZoomForRadius(radiusKm),
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.vetapp.mobile_app',
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: centerPoint,
              radius: radiusKm * 1000,
              useRadiusInMeter: true,
              color: AppColors.primary.withValues(alpha: 0.06),
              borderColor: AppColors.primary.withValues(alpha: 0.5),
              borderStrokeWidth: 1.5,
            ),
          ],
        ),
        _ClusteredMarkers(items: items, interactive: interactive),
        MarkerLayer(
          markers: [
            Marker(
              point: centerPoint,
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
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

/// Every item of the radius is on the map; items that would overlap at
/// the current zoom are merged into one numbered marker instead of being
/// left out. Tapping a cluster zooms into it. Recomputed on every camera
/// change (MapCamera.of registers the dependency).
class _ClusteredMarkers extends StatelessWidget {
  const _ClusteredMarkers({required this.items, required this.interactive});

  final List<RadarMapItem> items;
  final bool interactive;

  /// Side, in screen pixels, of the grid cell items are merged within.
  static const _cellPixels = 44.0;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final controller = MapController.of(context);

    final cells = <(int, int), List<RadarMapItem>>{};
    for (final item in items) {
      final point = camera.projectAtZoom(
        latlong.LatLng(item.location.latitude, item.location.longitude),
      );
      final key = ((point.dx / _cellPixels).floor(), (point.dy / _cellPixels).floor());
      cells.putIfAbsent(key, () => []).add(item);
    }

    return MarkerLayer(
      markers: cells.values.map((group) {
        if (group.length == 1) {
          return _itemMarker(group.single);
        }
        final center = latlong.LatLng(
          group.map((item) => item.location.latitude).reduce((a, b) => a + b) / group.length,
          group.map((item) => item.location.longitude).reduce((a, b) => a + b) / group.length,
        );
        return Marker(
          point: center,
          width: 36,
          height: 36,
          child: Semantics(
            label: '${group.length} luoghi vicini tra loro',
            button: true,
            child: GestureDetector(
              onTap: interactive ? () => controller.move(center, camera.zoom + 2) : null,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.text,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '${group.length}',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Marker _itemMarker(RadarMapItem item) {
    return Marker(
      point: latlong.LatLng(item.location.latitude, item.location.longitude),
      width: 30,
      height: 30,
      child: Semantics(
        label: '${item.category.label}: ${item.label}',
        button: true,
        child: GestureDetector(
          onTap: interactive ? item.onTap : null,
          child: Container(
            decoration: BoxDecoration(
              color: item.category.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(item.category.icon, color: Colors.white, size: 16),
          ),
        ),
      ),
    );
  }
}

/// Which symbol/color means what, limited to the categories on screen.
class RadarLegend extends StatelessWidget {
  const RadarLegend({super.key, required this.categories});

  final Iterable<RadarCategory> categories;

  @override
  Widget build(BuildContext context) {
    final ordered = RadarCategory.values.where(categories.contains).toList();
    if (ordered.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: ordered
          .map(
            (category) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(category.icon, color: category.color, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(category.label, style: AppTextStyles.caption),
              ],
            ),
          )
          .toList(),
    );
  }
}
