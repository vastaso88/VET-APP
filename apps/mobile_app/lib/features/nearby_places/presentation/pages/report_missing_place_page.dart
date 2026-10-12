import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../location/domain/coordinates.dart';
import '../../data/radar_contributions_repository.dart';
import '../../data/reverse_geocoder.dart';
import '../../domain/radar_place.dart';
import '../radar_category.dart';
import '../radar_contributions.dart';
import '../widgets/radar_chip.dart';
import '../../../../l10n/l10n.dart';

/// "Segnala!" for a place missing from the map: a category from a closed
/// list, the name on the sign, and a position picked on the map. No notes
/// and no contact fields by design: nothing here can carry personal data.
class ReportMissingPlacePage extends StatefulWidget {
  const ReportMissingPlacePage({
    super.key,
    required this.contributions,
    required this.initialPosition,
    this.reverseGeocoder,
  });

  final RadarContributions contributions;

  /// Where the map starts: the user's reference location.
  final Coordinates initialPosition;

  /// Injectable for tests; defaults to Nominatim.
  final ReverseGeocoder? reverseGeocoder;

  @override
  State<ReportMissingPlacePage> createState() => _ReportMissingPlacePageState();
}

class _ReportMissingPlacePageState extends State<ReportMissingPlacePage> {
  static const _maxNameLength = 60;

  final _nameController = TextEditingController();
  final _mapController = MapController();
  late final Future<RadarReportOptions> _optionsFuture =
      widget.contributions.repository.loadOptions();
  late Coordinates _position = widget.initialPosition;
  RadarPlaceType? _type;
  bool _sending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  bool get _nameIsOptional => _type == RadarPlaceType.dogPark;

  bool get _canSend =>
      !_sending && _type != null && (_nameIsOptional || _nameController.text.trim().isNotEmpty);

  Future<void> _send() async {
    final type = _type;
    if (type == null) {
      return;
    }
    setState(() => _sending = true);
    final expiryDays = (await _optionsFuture).expiryDays;
    final address = await (widget.reverseGeocoder ?? ReverseGeocoder()).addressOf(_position);
    if (!mounted) {
      return;
    }
    final done = await widget.contributions.run(
      context,
      () => widget.contributions.repository.reportMissing(
        type: type,
        name: _nameController.text.trim(),
        position: _position,
        addressLabel: address,
      ),
      successMessage: (receipt) => receipt.countedAsConfirmation
          ? context.l10n.placesReportAlreadyKnown
          : context.l10n.placesReportSentExpiry(expiryDays),
    );
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    if (done) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(context.l10n.placesReportTitle, style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: FutureBuilder<RadarReportOptions>(
          future: _optionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: PetLoader());
            }
            final options = snapshot.data;
            if (options == null || !options.enabled || options.missingPlaceTypes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Text(
                    context.l10n.placesReportUnavailable,
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _buildForm(options);
          },
        ),
      ),
    );
  }

  Widget _buildForm(RadarReportOptions options) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(context.l10n.placesReportWhatIs, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: options.missingPlaceTypes.map((type) {
            final category = radarCategoryForPlace(type);
            return RadarChip(
              label: radarPlaceTypeLabel(type),
              icon: category.icon,
              iconColor: category.color,
              selected: _type == type,
              onTap: () => setState(() => _type = type),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _nameController,
          maxLength: _maxNameLength,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: _nameIsOptional
                ? context.l10n.placesReportNameOptional
                : context.l10n.placesReportNameLabel,
            helperText: context.l10n.placesReportNameHelper,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(context.l10n.placesReportWhere, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.placesReportMapHint,
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          child: AspectRatio(
            aspectRatio: 1.2,
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
                // Fixed pin at the center: the map moves under it. The
                // padding lifts the icon so its tip, not its middle,
                // marks the spot.
                const IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(Icons.location_on, size: 44, color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _canSend ? _send : null,
          child: _sending ? const PetLoader.small() : Text(context.l10n.placesReportSubmit),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.placesReportFootnote(options.expiryDays),
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
