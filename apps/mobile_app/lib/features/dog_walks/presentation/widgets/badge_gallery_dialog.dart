import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/badges.dart';
import '../../domain/walk_session.dart';

class _BadgeCatalogEntry {
  const _BadgeCatalogEntry({
    required this.idPrefix,
    required this.icon,
    required this.name,
    required this.description,
  });

  /// Matched against an earned badge id as `'$idPrefix$petId'` - exact
  /// match, not just startsWith, so one pet's badges never light up
  /// another pet's tile when [walksForPet] accidentally includes more
  /// than one pet's walks.
  final String idPrefix;
  final IconData icon;
  final String Function(AppLocalizations l10n) name;
  final String Function(AppLocalizations l10n) description;
}

/// All 13 badges evaluateBadges can award (badges.dart): the owner's
/// requested 12 (Prima passeggiata, 1/5/10/50 km, 30 min, 1 ora, 7 giorni
/// di fila, alba, notte, 10/50 uscite) plus 100 km and 30 uscite, kept from
/// the catalog that shipped before this gallery existed - dropping them
/// would have made a pet that already earned one lose it from view, since
/// badges are recomputed from walk history rather than stored on their own
/// (2026-09-29).
final List<_BadgeCatalogEntry> _walkBadgeCatalog = [
  _BadgeCatalogEntry(
    idPrefix: firstWalkBadgePrefix,
    icon: Icons.pets_rounded,
    name: (l10n) => l10n.walksBadgeNameFirstWalk,
    description: (l10n) => l10n.walksBadgeDescFirstWalk,
  ),
  _kmEntry(1, Icons.directions_walk_rounded),
  _kmEntry(5, Icons.directions_walk_rounded),
  _kmEntry(10, Icons.directions_run_rounded),
  _kmEntry(50, Icons.directions_run_rounded),
  _kmEntry(100, Icons.emoji_events_rounded),
  _BadgeCatalogEntry(
    idPrefix: singleWalkDuration30MinBadgePrefix,
    icon: Icons.timer_rounded,
    name: (l10n) => l10n.walksBadgeName30Min,
    description: (l10n) => l10n.walksBadgeDesc30Min,
  ),
  _BadgeCatalogEntry(
    idPrefix: singleWalkDuration1HourBadgePrefix,
    icon: Icons.timer_rounded,
    name: (l10n) => l10n.walksBadgeName1Hour,
    description: (l10n) => l10n.walksBadgeDesc1Hour,
  ),
  _BadgeCatalogEntry(
    idPrefix: sevenDayStreakBadgePrefix,
    icon: Icons.local_fire_department_rounded,
    name: (l10n) => l10n.walksBadgeNameStreak,
    description: (l10n) => l10n.walksBadgeDescStreak,
  ),
  _BadgeCatalogEntry(
    idPrefix: dawnWalkBadgePrefix,
    icon: Icons.wb_twilight_rounded,
    name: (l10n) => l10n.walksBadgeNameDawn,
    description: (l10n) => l10n.walksBadgeDescDawn,
  ),
  _BadgeCatalogEntry(
    idPrefix: nightWalkBadgePrefix,
    icon: Icons.nightlight_round,
    name: (l10n) => l10n.walksBadgeNameNight,
    description: (l10n) => l10n.walksBadgeDescNight,
  ),
  _walkCountEntry(10, Icons.looks_one_rounded),
  _walkCountEntry(50, Icons.military_tech_rounded),
];

_BadgeCatalogEntry _kmEntry(int km, IconData icon) => _BadgeCatalogEntry(
      idPrefix: 'distance_${km}km_pet_',
      icon: icon,
      name: (l10n) => l10n.walksBadgeNameKm('$km'),
      description: (l10n) => l10n.walksBadgeDescKm('$km'),
    );

_BadgeCatalogEntry _walkCountEntry(int count, IconData icon) => _BadgeCatalogEntry(
      idPrefix: 'walks_${count}_pet_',
      icon: icon,
      name: (l10n) => l10n.walksBadgeNameWalkCount('$count'),
      description: (l10n) => l10n.walksBadgeDescWalkCount('$count'),
    );

/// Almost-full-screen gallery of every badge, greyed out until earned
/// (owner request, 2026-09-29) - reuses evaluateBadges (badges.dart) rather
/// than any separate persisted "earned" state, since a badge is entirely a
/// function of [walksForPet]'s stored distance/duration/startedAt fields.
Future<void> showBadgeGalleryDialog(
  BuildContext context, {
  required String petId,
  required List<WalkSession> walksForPet,
}) {
  final earned = evaluateBadges(walksForPet).toSet();

  return showDialog<void>(
    context: context,
    builder: (context) {
      final size = MediaQuery.sizeOf(context);
      return Dialog(
        insetPadding:
            EdgeInsets.symmetric(horizontal: 12, vertical: size.height * 0.05),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.xl)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text(context.l10n.walksBadgeGalleryTitle, style: AppTextStyles.title)),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: _walkBadgeCatalog.length,
                  itemBuilder: (context, index) {
                    final entry = _walkBadgeCatalog[index];
                    final isEarned = earned.contains('${entry.idPrefix}$petId');
                    return _BadgeTile(entry: entry, earned: isEarned);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.entry, required this.earned});

  final _BadgeCatalogEntry entry;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    // Earned: full-color gold circle + white icon + a matching border, so
    // it reads as "won" at a glance. Not earned: desaturated grey and
    // dimmed further with Opacity - the previous version only changed a
    // couple of mid-tone colors, which didn't read as a clear on/off state
    // (owner report, 2026-09-30: "non si capisce bene").
    final tile = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: earned ? AppColors.surfaceElevated : AppColors.surface,
        border: Border.all(color: earned ? AppColors.warning : AppColors.border, width: earned ? 2 : 1),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: earned ? AppColors.warning : AppColors.border,
              shape: BoxShape.circle,
            ),
            child: Icon(
              entry.icon,
              color: earned ? AppColors.onPrimary : AppColors.mutedText,
              size: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            entry.name(context.l10n),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: earned ? AppColors.text : AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Text(
              entry.description(context.l10n),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption
                  .copyWith(color: earned ? AppColors.secondaryText : AppColors.mutedText),
            ),
          ),
        ],
      ),
    );

    return earned ? tile : Opacity(opacity: 0.45, child: tile);
  }
}
