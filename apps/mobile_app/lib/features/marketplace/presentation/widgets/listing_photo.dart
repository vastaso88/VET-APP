import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../data/listing_photo_store.dart';

/// One listing photo, from the public bucket or - in demo mode - from the
/// session's memory (ListingPhotoStore's `memory://` urls).
class ListingPhoto extends StatelessWidget {
  const ListingPhoto({super.key, required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final memory = ListingPhotoStore.memoryBytes(url);
    if (memory != null) {
      return Image.memory(memory, fit: fit, gaplessPlayback: true);
    }
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: AppColors.warmSurface,
        child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.mutedText)),
      ),
    );
  }
}
