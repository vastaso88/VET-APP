import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/walk_session.dart';
import '../walk_labels.dart';

/// Shown when the owner wants to star a new favorite walk but already has
/// [maxFavoriteWalks] saved (walk_retention.dart) - one of the current
/// favorites has to be given up first. [currentFavorites] always has
/// exactly that many entries.
///
/// Returns the id of the walk to un-star, or null if the owner backed out
/// of the picker - in that case the walk that triggered this isn't saved
/// as a favorite either, and the existing favorites are left untouched.
Future<String?> pickFavoriteToEvict(
  BuildContext context,
  List<WalkSession> currentFavorites,
) {
  final sorted = [...currentFavorites]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hai già 5 preferite'),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scegli quale togliere dalle preferite per fare posto a quella appena conclusa.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final walk in sorted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _FavoriteChoiceRow(walk: walk),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
      ],
    ),
  );
}

class _FavoriteChoiceRow extends StatelessWidget {
  const _FavoriteChoiceRow({required this.walk});

  final WalkSession walk;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        onTap: () => Navigator.of(context).pop(walk.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.star_rounded,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(walkDateLabel(walk.startedAt),
                        style: AppTextStyles.bodySmall),
                    Text(
                      [
                        walkDistanceLabel(walk.distanceMeters),
                        if (walk.durationSeconds != null)
                          walkDurationLabel(walk.durationSeconds),
                      ].join(' · '),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
