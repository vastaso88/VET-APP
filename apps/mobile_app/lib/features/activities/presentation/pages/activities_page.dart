import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/coming_soon_page.dart';
import '../../../../app/launch/restorable_pages.dart';
import '../../../travel_guide/data/travel_cards_repository.dart';
import '../../../travel_guide/presentation/pages/travel_guide_page.dart';

/// The "Pet friend" entry is frozen: set to true to bring it back.
const _petFriendEnabled = false;

class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key, this.travelCardsRepository});

  /// Tests pass a fake; the app reads the real backend.
  final TravelCardsRepository? travelCardsRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            Text(context.l10n.activitiesTitle, style: AppTextStyles.display.copyWith(fontSize: 28)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.activitiesSubtitle,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            _ActivityRow(
              icon: Icons.newspaper_outlined,
              iconTone: AppColors.primary,
              title: context.l10n.petNewsTitle,
              subtitle: context.l10n.activitiesNewsSubtitle,
              onTap: () => Navigator.of(context)
                  .push(restorableRoute<void>('news_feed')),
            ),
            _ActivityRow(
              icon: Icons.map_outlined,
              iconTone: AppColors.info,
              title: context.l10n.activitiesNearbyTitle,
              subtitle: context.l10n.activitiesNearbySubtitle,
              onTap: () => Navigator.of(context)
                  .push(restorableRoute<void>('local_events')),
            ),
            _ActivityRow(
              icon: Icons.event_outlined,
              iconTone: AppColors.secondaryStrong,
              title: context.l10n.activitiesEventsTitle,
              subtitle: context.l10n.activitiesEventsSubtitle,
              onTap: () => Navigator.of(context)
                  .push(restorableRoute<void>('events')),
            ),
            _ActivityRow(
              icon: Icons.photo_library_outlined,
              iconTone: AppColors.info,
              title: context.l10n.activitiesGalleryTitle,
              subtitle: context.l10n.activitiesGallerySubtitle,
              onTap: () => Navigator.of(context)
                  .push(restorableRoute<void>('gallery_folders')),
            ),
            _ActivityRow(
              icon: Icons.storefront_outlined,
              iconTone: AppColors.warning,
              title: context.l10n.activitiesMarketplaceTitle,
              subtitle: context.l10n.activitiesMarketplaceSubtitle,
              onTap: () => Navigator.of(context)
                  .push(restorableRoute<void>('marketplace')),
            ),
            _AroundWorldRow(repository: travelCardsRepository),
            // Frozen (owner, 2026-11-16): the code stays, nothing reaches it.
            if (_petFriendEnabled)
              _ActivityRow(
                icon: Icons.favorite_outline,
                iconTone: AppColors.secondaryStrong,
                title: context.l10n.activitiesPetFriendTitle,
                subtitle: context.l10n.activitiesPetFriendSubtitle,
                badge: context.l10n.activitiesComingSoonBadge,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ComingSoonPage(
                      title: context.l10n.activitiesPetFriendTitle,
                      icon: Icons.favorite_outline,
                      description: context.l10n.activitiesPetFriendDescription,
                    ),
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Around the world": shown only once at least one approved travel card exists
/// (docs/product/18 §9): a section without verified cards would be an offer of
/// information nobody has checked. While the cards load, or if they cannot be
/// reached, the row is simply not there.
class _AroundWorldRow extends StatefulWidget {
  const _AroundWorldRow({this.repository});

  final TravelCardsRepository? repository;

  @override
  State<_AroundWorldRow> createState() => _AroundWorldRowState();
}

class _AroundWorldRowState extends State<_AroundWorldRow> {
  late final Future<bool> _available = _check();

  Future<bool> _check() async {
    try {
      final cards = await (widget.repository ?? BackendTravelCardsRepository()).fetchAll();
      return cards.isNotEmpty;
    } on TravelCardsUnavailable {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _available,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return _ActivityRow(
          icon: Icons.public,
          iconTone: AppColors.primary,
          title: context.l10n.aroundWorldTitle,
          subtitle: context.l10n.aroundWorldActivitySubtitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TravelGuidePage(repository: widget.repository),
            ),
          ),
        );
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.iconTone,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color iconTone;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconTone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(icon, color: iconTone, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondarySoft,
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Text(
                              badge!,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}
