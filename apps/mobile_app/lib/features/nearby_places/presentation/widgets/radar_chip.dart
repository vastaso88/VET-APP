import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';

/// The radar's one chip: radius options, quick categories and the filter
/// sheet all use it. Sets the selected-state colors explicitly because the
/// app-wide chip theme pairs a dark selected background with a dark label,
/// which made the selected option unreadable.
class RadarChip extends StatelessWidget {
  const RadarChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Icon tint while unselected; a selected chip always uses the light
  /// foreground so it stays legible on the dark background.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.onPrimary : AppColors.text;
    return ChoiceChip(
      label: Text(label),
      labelStyle: (Theme.of(context).chipTheme.labelStyle ?? const TextStyle()).copyWith(
        color: foreground,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      avatar: icon == null
          ? null
          : Icon(icon, size: 18, color: selected ? foreground : iconColor ?? foreground),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.borderStrong),
      onSelected: (_) => onTap(),
    );
  }
}
