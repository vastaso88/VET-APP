import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../design_system/tokens/app_colors.dart';
import '../domain/coordinates.dart';

/// A point picked by panning an OpenStreetMap map under a fixed pin at its
/// centre, with the map credit visible. Shared by "Segnala un luogo mancante"
/// and the home-address picker in Impostazioni: each screen keeps its own
/// saving, validation and sending, and only learns where the centre is.
///
/// [onCenterChanged] is called every time the map moves, with the new centre;
/// the screen keeps the last one and uses it when the owner confirms. It is not
/// called at the start: until the map moves the centre is [initialPosition].
class CenterPinMapPicker extends StatefulWidget {
  const CenterPinMapPicker({
    super.key,
    required this.initialPosition,
    required this.onCenterChanged,
    this.initialZoom = 16,
  });

  final Coordinates initialPosition;
  final ValueChanged<Coordinates> onCenterChanged;
  final double initialZoom;

  /// The credit OpenStreetMap's licence asks to show.
  static const attribution = 'OpenStreetMap contributors';

  @override
  State<CenterPinMapPicker> createState() => _CenterPinMapPickerState();
}

class _CenterPinMapPickerState extends State<CenterPinMapPicker> {
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: latlong.LatLng(
              widget.initialPosition.latitude,
              widget.initialPosition.longitude,
            ),
            initialZoom: widget.initialZoom,
            onPositionChanged: (camera, _) => widget.onCenterChanged(
              Coordinates(
                latitude: camera.center.latitude,
                longitude: camera.center.longitude,
              ),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.vetapp.mobile_app',
            ),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution(CenterPinMapPicker.attribution)],
            ),
          ],
        ),
        // Fixed pin at the center: the map moves under it. The padding lifts
        // the icon so its tip, not its middle, marks the spot.
        const IgnorePointer(
          child: Padding(
            padding: EdgeInsets.only(bottom: 36),
            child: Icon(Icons.location_on, size: 44, color: AppColors.danger),
          ),
        ),
      ],
    );
  }
}
