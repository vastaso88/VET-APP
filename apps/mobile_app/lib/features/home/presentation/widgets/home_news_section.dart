import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../pet_news/data/pet_news_repository.dart';
import '../../../pet_news/domain/pet_news_item.dart';
import '../../../pets/presentation/widgets/species_figure.dart';
import 'home_dashboard_primitives.dart';
import 'home_surface.dart';

/// "Curiosità per i tuoi animali": the four stories, one white row each.
class HomeNewsSection extends StatelessWidget {
  const HomeNewsSection({
    super.key,
    required this.news,
    required this.onRetry,
    required this.onOpen,
    required this.onMore,
  });

  final Future<List<PetNewsItem>> news;
  final VoidCallback onRetry;
  final ValueChanged<PetNewsItem> onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardSectionHeader(
          title: context.l10n.homeNewsTitle,
          subtitle: context.l10n.homeNewsSubtitle,
        ),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<List<PetNewsItem>>(
          future: news,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const HomeSectionLoader();
            }

            final items = snapshot.data ?? const <PetNewsItem>[];
            if (items.isEmpty) {
              final served = petNewsEditionServed();
              return HomeSectionNotice(
                // Edition without feeds yet: say so instead of "try later".
                text: Text(
                  served ? context.l10n.homeNewsUnavailable : context.l10n.petNewsEmptyLocal,
                  style: AppTextStyles.bodySmall,
                ),
                action: served
                    ? TextButton.icon(
                        key: const ValueKey('home-news-retry'),
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(context.l10n.commonRetry),
                      )
                    : null,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i != 0) const Divider(height: 1, color: AppColors.border),
                        HomeNewsRow(item: items[i], onTap: () => onOpen(items[i])),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  key: const ValueKey('home-news-more'),
                  onPressed: onMore,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.secondary),
                  ),
                  child: Text(context.l10n.homeNewsMore, textAlign: TextAlign.center),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One story: whose it is (figure), its title in full, where it comes from and
/// the sign that it opens outside the app.
class HomeNewsRow extends StatelessWidget {
  const HomeNewsRow({super.key, required this.item, required this.onTap});

  final PetNewsItem item;
  final VoidCallback onTap;

  static const _figureSize = 44.0;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        link: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(child: SpeciesFigure(species: item.species, size: _figureSize)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              newsSourceLine(item),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Fonte · 25 nov"; whichever of the two is missing is left out. The date
/// never breaks in two: on a narrow phone it goes whole to the second line.
String newsSourceLine(PetNewsItem item) {
  final published = item.publishedAt?.toLocal();
  return [
    if (item.extract.trim().isNotEmpty) item.extract.trim(),
    if (published != null) formatAppDate(published, 'd MMM').replaceAll(' ', _noBreak),
  ].join(' ·$_noBreak');
}

const _noBreak = ' ';
