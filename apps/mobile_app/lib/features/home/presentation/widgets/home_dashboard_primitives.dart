import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/widgets/app_card.dart';

enum DashboardTone {
  neutral,
  primary,
  success,
  warning,
  danger,
  info,
  warm,
}

class DashboardPrimitivePalette {
  const DashboardPrimitivePalette._();

  static ({Color foreground, Color background, Color border}) colorsFor(
    DashboardTone tone, {
    bool filled = false,
  }) {
    final base = switch (tone) {
      DashboardTone.primary => AppColors.primary,
      DashboardTone.success => AppColors.success,
      DashboardTone.warning => AppColors.warning,
      DashboardTone.danger => AppColors.danger,
      DashboardTone.info => AppColors.info,
      DashboardTone.warm => AppColors.secondaryStrong,
      DashboardTone.neutral => AppColors.secondaryText,
    };

    final background = switch (tone) {
      DashboardTone.primary => AppColors.primary.withValues(alpha: 0.10),
      DashboardTone.success => AppColors.success.withValues(alpha: 0.12),
      DashboardTone.warning => AppColors.warning.withValues(alpha: 0.14),
      DashboardTone.danger => AppColors.danger.withValues(alpha: 0.12),
      DashboardTone.info => AppColors.info.withValues(alpha: 0.12),
      DashboardTone.warm => AppColors.secondaryStrong.withValues(alpha: 0.14),
      DashboardTone.neutral => AppColors.secondarySoft,
    };

    return (
      foreground: filled ? AppColors.onPrimary : base,
      background: filled ? base : background,
      border: filled ? base : base.withValues(alpha: 0.18),
    );
  }
}

class DashboardBadge extends StatelessWidget {
  const DashboardBadge({
    super.key,
    required this.label,
    this.tone = DashboardTone.neutral,
    this.icon,
    this.filled = false,
    this.compact = false,
  });

  final String label;
  final DashboardTone tone;
  final IconData? icon;
  final bool filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPrimitivePalette.colorsFor(tone, filled: filled);
    final ink = filled
        ? palette.foreground
        : switch (tone) {
            DashboardTone.success => AppColors.successStrong,
            DashboardTone.warning => AppColors.warningStrong,
            DashboardTone.danger => AppColors.dangerStrong,
            DashboardTone.info => AppColors.infoStrong,
            _ => palette.foreground,
          };
    final textStyle =
        (compact ? AppTextStyles.caption : AppTextStyles.bodySmall).copyWith(
      color: ink,
      fontWeight: FontWeight.w600,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.md : AppSpacing.lg,
          vertical: compact ? AppSpacing.xs : AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: compact ? 14 : 16, color: ink),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(child: Text(label, style: textStyle)),
          ],
        ),
      ),
    );
  }
}

class DashboardActionButton extends StatelessWidget {
  const DashboardActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tone = DashboardTone.primary,
    this.filled = true,
    this.compact = false,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final DashboardTone tone;
  final bool filled;
  final bool compact;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPrimitivePalette.colorsFor(tone, filled: filled);
    final background = filled ? palette.background : AppColors.surface;
    final foreground = palette.foreground;
    final borderColor = palette.border;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.lg : AppSpacing.xl,
        vertical: compact ? AppSpacing.md : AppSpacing.lg,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 18 : 20, color: foreground),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.button.copyWith(color: foreground),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );

    final button = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: borderColor),
        boxShadow: filled
            ? const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: content,
    );

    if (onPressed == null) {
      return button;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.large),
        child: button,
      ),
    );
  }
}

class DashboardListRow extends StatelessWidget {
  const DashboardListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.tone = DashboardTone.neutral,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final DashboardTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.md : AppSpacing.lg,
        vertical: compact ? AppSpacing.md : AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (trailing != null) trailing!,
        ],
      ),
    );

    return AppCard(padding: EdgeInsets.zero, onTap: onTap, child: row);
  }
}

class DashboardSectionHeader extends StatelessWidget {
  const DashboardSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionPressed,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTextStyles.title.copyWith(
                  color: AppColors.text,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: AppTextStyles.bodySmall),
              ],
            ],
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: AppSpacing.lg),
          TextButton(
            onPressed: onActionPressed,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}
