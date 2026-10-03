import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_text_styles.dart';
import '../../location/domain/coordinates.dart';
import '../../location/presentation/distance_label.dart';
import '../domain/radar_place.dart';
import 'radar_category.dart';

Future<void> callRadarPlace(RadarPlace place) =>
    launchUrl(Uri(scheme: 'tel', path: place.phone));

/// Opens the device's maps app with directions to [destination].
Future<void> openDirections(Coordinates destination) => launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${destination.latitude},${destination.longitude}',
      ),
      mode: LaunchMode.externalApplication,
    );

Future<void> showRadarPlaceSheet(BuildContext context, RadarPlace place) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _RadarPlaceSheet(place: place),
  );
}

class _RadarPlaceSheet extends StatelessWidget {
  const _RadarPlaceSheet({required this.place});

  final RadarPlace place;

  @override
  Widget build(BuildContext context) {
    final category = radarCategoryForPlace(place.type);
    final address = place.addressLabel ?? place.city;
    final isClinic = place.type == RadarPlaceType.veterinary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RadarCategoryBadge(category: category),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: AppTextStyles.title),
                      Text(
                        '${radarPlaceTypeLabel(place.type)} · ${formatDistance(place.distanceMeters)}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (address != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(address, style: AppTextStyles.body),
            ],
            if (place.openingHours != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Orari indicati: ${formatOpeningHours(place.openingHours!)}',
                style: AppTextStyles.bodySmall,
              ),
            ],
            if (place.summary != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(place.summary!, style: AppTextStyles.bodySmall),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (place.phone != null)
                  FilledButton.icon(
                    onPressed: () => callRadarPlace(place),
                    icon: const Icon(Icons.call),
                    label: const Text('Chiama'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => openDirections(place.location),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Indicazioni'),
                ),
                if (place.websiteUrl != null)
                  OutlinedButton.icon(
                    onPressed: () =>
                        launchUrl(Uri.parse(place.websiteUrl!), webOnlyWindowName: '_blank'),
                    icon: const Icon(Icons.public),
                    label: const Text('Sito web'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isClinic
                  ? 'In caso di urgenza telefona prima di partire: orari e recapiti '
                      'arrivano da OpenStreetMap e non sono verificati da VetApp.'
                  : 'Orari e recapiti arrivano da OpenStreetMap e non sono verificati da VetApp.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Dati © OpenStreetMap contributors', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
