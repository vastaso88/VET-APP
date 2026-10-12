import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';

class PetsLoadingView extends StatelessWidget {
  const PetsLoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return _StateSurface(
      icon: Icons.hourglass_top_rounded,
      title: label ?? context.l10n.petsLoadingDefaultLabel,
      subtitle: context.l10n.petsLoadingSubtitle,
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 2 ? 0 : AppSpacing.md),
            child: Container(
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PetsErrorView extends StatelessWidget {
  const PetsErrorView({
    required this.title,
    required this.subtitle,
    super.key,
    this.onRetry,
    this.actionLabel,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return _StateSurface(
      icon: Icons.warning_amber_rounded,
      title: title,
      subtitle: subtitle,
      accent: const Color(0xFFF8E8E0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onRetry,
          child: Text(actionLabel ?? context.l10n.commonRetry),
        ),
      ),
    );
  }
}

class PetsEmptyView extends StatelessWidget {
  const PetsEmptyView({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    super.key,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _StateSurface(
      icon: Icons.pets_rounded,
      title: title,
      subtitle: subtitle,
      accent: AppColors.accentSoft,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onAction,
          child: Text(actionLabel),
        ),
      ),
    );
  }
}

class _StateSurface extends StatelessWidget {
  const _StateSurface({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.accent = AppColors.accentSoft,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11163A35),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                ),
                child: Icon(icon, color: AppColors.primary, size: 34),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
