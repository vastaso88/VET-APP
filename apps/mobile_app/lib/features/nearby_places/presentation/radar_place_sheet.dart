import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_text_styles.dart';
import '../../location/presentation/distance_label.dart';
import '../domain/radar_place.dart';

String radarPlaceTypeLabel(RadarPlaceType type) {
  switch (type) {
    case RadarPlaceType.veterinary:
      return 'Veterinario';
    case RadarPlaceType.grooming:
      return 'Toelettatura';
    case RadarPlaceType.shop:
      return 'Negozio per animali';
    case RadarPlaceType.school:
      return 'Addestramento';
    case RadarPlaceType.petSitting:
      return 'Pet sitter';
    case RadarPlaceType.breeder:
      return 'Allevamento';
    case RadarPlaceType.hotel:
      return 'Pensione per animali';
    case RadarPlaceType.other:
      return 'Servizio per animali';
  }
}

IconData radarPlaceTypeIcon(RadarPlaceType type) {
  switch (type) {
    case RadarPlaceType.veterinary:
      return Icons.local_hospital_outlined;
    case RadarPlaceType.grooming:
      return Icons.content_cut_outlined;
    case RadarPlaceType.shop:
      return Icons.storefront_outlined;
    case RadarPlaceType.school:
      return Icons.school_outlined;
    case RadarPlaceType.petSitting:
      return Icons.volunteer_activism_outlined;
    case RadarPlaceType.breeder:
      return Icons.pets_outlined;
    case RadarPlaceType.hotel:
      return Icons.night_shelter_outlined;
    case RadarPlaceType.other:
      return Icons.place_outlined;
  }
}

Future<void> showRadarPlaceSheet(BuildContext context, RadarPlace place) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (_) => _RadarPlaceSheet(place: place),
  );
}

class _RadarPlaceSheet extends StatelessWidget {
  const _RadarPlaceSheet({required this.place});

  final RadarPlace place;

  @override
  Widget build(BuildContext context) {
    final details = [
      radarPlaceTypeLabel(place.type),
      formatDistance(place.distanceMeters),
    ].join(' · ');
    final address = place.addressLabel ?? place.city;
    final mapUri = Uri.parse(
      'https://www.openstreetmap.org/?mlat=${place.location.latitude}'
      '&mlon=${place.location.longitude}#map=17/${place.location.latitude}/${place.location.longitude}',
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.name, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            Text(details, style: AppTextStyles.bodySmall),
            if (address != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(address, style: AppTextStyles.body),
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
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: place.phone)),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Chiama'),
                  ),
                if (place.websiteUrl != null)
                  OutlinedButton.icon(
                    onPressed: () =>
                        launchUrl(Uri.parse(place.websiteUrl!), webOnlyWindowName: '_blank'),
                    icon: const Icon(Icons.public),
                    label: const Text('Sito web'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(mapUri, webOnlyWindowName: '_blank'),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Apri in mappa'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Dati © OpenStreetMap contributors. Orari e contatti possono non essere aggiornati.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}
