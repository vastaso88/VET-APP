import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/listing_content.dart';

/// Why the team took the seller's ad down, and how to ask for a review.
class ListingRemovalNotice extends StatelessWidget {
  const ListingRemovalNotice({super.key, required this.removal});

  final ListingRemoval removal;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('listing-removal-notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Text(
        removal.message(context.l10n),
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerStrong),
      ),
    );
  }
}
