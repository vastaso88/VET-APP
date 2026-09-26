import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/widgets/coming_soon_page.dart';
import '../../../local_events/presentation/pages/local_events_page.dart';
import '../../../marketplace/presentation/pages/marketplace_page.dart';
import '../../../pet_news/presentation/pages/news_feed_page.dart';

class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          children: [
            Text('Attività', style: AppTextStyles.display.copyWith(fontSize: 28)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tutto quello che ruota attorno alla vita con i tuoi animali.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            _ActivityRow(
              icon: Icons.newspaper_outlined,
              iconTone: AppColors.primary,
              title: 'Notizie',
              subtitle: 'Curiosità e attualità sugli animali domestici.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const NewsFeedPage()),
              ),
            ),
            _ActivityRow(
              icon: Icons.map_outlined,
              iconTone: AppColors.info,
              title: 'Eventi nei dintorni',
              subtitle: 'Fiere, raduni e iniziative vicino a te.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LocalEventsPage()),
              ),
            ),
            _ActivityRow(
              icon: Icons.medical_services_outlined,
              iconTone: AppColors.success,
              title: 'Cerca il vet',
              subtitle: 'Trova un veterinario vicino a te.',
              badge: 'In arrivo',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ComingSoonPage(
                    title: 'Cerca il vet',
                    icon: Icons.medical_services_outlined,
                    description:
                        'Presto potrai trovare e contattare veterinari vicino a te direttamente dall\'app.',
                  ),
                ),
              ),
            ),
            _ActivityRow(
              icon: Icons.storefront_outlined,
              iconTone: AppColors.warning,
              title: 'Mercatino dell\'usato',
              subtitle: 'Compra, vendi e scambia articoli per animali.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const MarketplacePage()),
              ),
            ),
            _ActivityRow(
              icon: Icons.favorite_outline,
              iconTone: AppColors.accent,
              title: 'Pet friend',
              subtitle: 'Incontri e compagnia tra animali e proprietari.',
              badge: 'In arrivo',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ComingSoonPage(
                    title: 'Pet friend',
                    icon: Icons.favorite_outline,
                    description:
                        'Incontra altri proprietari e organizza uscite tra animali con affinità simili.',
                  ),
                ),
              ),
            ),
            _ActivityRow(
              icon: Icons.photo_library_outlined,
              iconTone: AppColors.secondary,
              title: 'Gallery',
              subtitle: 'Raccogli foto e ricordi dei tuoi animali.',
              badge: 'In arrivo',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ComingSoonPage(
                    title: 'Gallery',
                    icon: Icons.photo_library_outlined,
                    description: 'Una raccolta di foto e ricordi condivisibile per ogni animale.',
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
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Text(
                              badge!,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primaryStrong,
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
