import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';

class LocalEventsPage extends StatelessWidget {
  const LocalEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Eventi nei dintorni', style: AppTextStyles.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxxl,
        ),
        children: [
          Text(
            'Fiere, raduni e iniziative vicino a te, in base alla tua zona.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          _MapPlaceholder(),
          const SizedBox(height: AppSpacing.xxl),
          const DashboardSectionHeader(
            title: 'Prossimamente',
            subtitle: 'Un\'anteprima di come appariranno gli eventi reali.',
          ),
          const SizedBox(height: AppSpacing.lg),
          const _ExampleEventRow(
            emoji: '🐾',
            title: 'Fiera cinofila regionale',
            place: 'Parco cittadino · 12 km',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _ExampleEventRow(
            emoji: '💉',
            title: 'Giornata vaccinazioni gratuite',
            place: 'Ambulatorio comunale · 4 km',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _ExampleEventRow(
            emoji: '🏠',
            title: 'Giornata delle adozioni',
            place: 'Canile rifugio · 8 km',
          ),
        ],
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.warmSurface,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 28,
              top: 24,
              child: Icon(Icons.location_on_rounded, size: 18, color: AppColors.secondary.withValues(alpha: 0.5)),
            ),
            Positioned(
              right: 36,
              top: 48,
              child: Icon(Icons.location_on_rounded, size: 14, color: AppColors.secondary.withValues(alpha: 0.4)),
            ),
            Positioned(
              right: 60,
              bottom: 28,
              child: Icon(Icons.location_on_rounded, size: 20, color: AppColors.secondary.withValues(alpha: 0.5)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.map_outlined, size: 26, color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Mappa in arrivo', style: AppTextStyles.title.copyWith(fontSize: 15)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Richiede la tua posizione, ancora in lavorazione.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExampleEventRow extends StatelessWidget {
  const _ExampleEventRow({
    required this.emoji,
    required this.title,
    required this.place,
  });

  final String emoji;
  final String title;
  final String place;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: DashboardListRow(
        title: title,
        subtitle: place,
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        trailing: DashboardBadge(label: 'Esempio', tone: DashboardTone.neutral, compact: true),
      ),
    );
  }
}
