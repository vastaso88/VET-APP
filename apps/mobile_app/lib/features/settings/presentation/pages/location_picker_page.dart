import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../location/data/address_geocoder.dart';
import '../../../location/domain/coordinates.dart';
import '../../../nearby_places/data/reverse_geocoder.dart';

/// Pick a point by panning the map under a fixed pin — same interaction as
/// "Segnala un luogo mancante" (report_missing_place_page.dart). Only one
/// Nominatim reverse-geocoding request is made, on "Conferma", respecting
/// its 1 req/sec usage policy.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    required this.initialPosition,
    this.reverseGeocoder,
  });

  final Coordinates initialPosition;

  /// Injectable for tests; defaults to Nominatim.
  final ReverseGeocoder? reverseGeocoder;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _mapController = MapController();
  late Coordinates _position = widget.initialPosition;
  bool _confirming = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    final label = await (widget.reverseGeocoder ?? ReverseGeocoder()).addressOf(_position);
    if (!mounted) return;
    setState(() => _confirming = false);
    Navigator.of(context).pop(
      GeocodedAddress(
        coordinates: _position,
        displayLabel: label ??
            '${_position.latitude.toStringAsFixed(5)}, ${_position.longitude.toStringAsFixed(5)}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Scegli sulla mappa', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Sposta la mappa finché il segnaposto è sul punto giusto, poi conferma.',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: latlong.LatLng(
                            widget.initialPosition.latitude,
                            widget.initialPosition.longitude,
                          ),
                          initialZoom: 16,
                          onPositionChanged: (camera, _) => _position = Coordinates(
                            latitude: camera.center.latitude,
                            longitude: camera.center.longitude,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.vetapp.mobile_app',
                          ),
                          const RichAttributionWidget(
                            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                          ),
                        ],
                      ),
                      // Fixed pin at the center: the map moves under it, same
                      // as report_missing_place_page.dart.
                      const IgnorePointer(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 36),
                          child: Icon(Icons.location_on, size: 44, color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _confirming ? null : _confirm,
                      child: _confirming
                          ? const PetLoader.small()
                          : const Text('Conferma questo punto'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
