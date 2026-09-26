import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../domain/pet_news_item.dart';

class PetNewsCard extends StatelessWidget {
  const PetNewsCard({super.key, required this.item});

  final PetNewsItem item;

  @override
  Widget build(BuildContext context) {
    final emoji = PetDemoStore.optionForSpecies(item.species).avatarEmoji;

    return DashboardSurfaceCard(
      tone: DashboardTone.warm,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => launchUrl(Uri.parse(item.sourceUrl), webOnlyWindowName: '_blank'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadii.medium),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.newspaper_outlined, size: 12, color: AppColors.mutedText),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.extract,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
