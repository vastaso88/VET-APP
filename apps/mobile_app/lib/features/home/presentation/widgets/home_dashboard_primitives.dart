import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';

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

class DashboardSurfaceCard extends StatelessWidget {
  const DashboardSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.tone = DashboardTone.neutral,
    this.elevation = 0,
    this.radius = AppRadii.xl,
    this.backgroundColor,
    this.borderColor,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final DashboardTone tone;
  final double elevation;
  final double radius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPrimitivePalette.colorsFor(tone);
    final surface = Theme.of(context).colorScheme.surface;
    final background = backgroundColor ??
        (tone == DashboardTone.neutral
            ? surface
            : Color.lerp(surface, palette.background, 0.48)!);
    final outline = borderColor ?? palette.border.withValues(alpha: 0.9);

    final card = Material(
      color: background,
      elevation: elevation,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: outline),
      ),
      clipBehavior: clipBehavior,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap == null) {
      return Padding(padding: margin, child: card);
    }

    return Padding(
      padding: margin,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
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
    final textStyle =
        (compact ? AppTextStyles.caption : AppTextStyles.bodySmall).copyWith(
      color: palette.foreground,
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
              Icon(icon, size: compact ? 14 : 16, color: palette.foreground),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(label, style: textStyle),
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
    final palette = DashboardPrimitivePalette.colorsFor(tone);

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
                  maxLines: 1,
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

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: palette.border.withValues(alpha: 0.65)),
      ),
      child: row,
    );

    if (onTap == null) {
      return decorated;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.large),
        child: decorated,
      ),
    );
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
