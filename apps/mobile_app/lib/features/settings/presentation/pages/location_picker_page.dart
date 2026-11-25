import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../location/data/address_geocoder.dart';
import '../../../location/domain/coordinates.dart';
import '../../../location/presentation/center_pin_map_picker.dart';
import '../../../nearby_places/data/reverse_geocoder.dart';
import '../../../../shared/widgets/page_header.dart';

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
  late Coordinates _position = widget.initialPosition;
  bool _confirming = false;

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
      appBar: PageHeader(title: context.l10n.settingsLocationPickerTitle),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.l10n.settingsLocationPickerHint,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                Expanded(
                  child: CenterPinMapPicker(
                    initialPosition: widget.initialPosition,
                    onCenterChanged: (center) => _position = center,
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
                          : Text(context.l10n.settingsLocationPickerConfirm),
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
