import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radii.dart';
import '../../design_system/tokens/app_spacing.dart';

/// The one card of the app: white, round, no shadow. When it can be tapped its
/// edge is the visible one (3 to 1) and the ripple is painted on the card, under
/// the text; a card that is only read keeps the hairline.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.borderColor,
    this.width,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The chosen one among several: petrol edge, thicker.
  final bool selected;

  /// Only for an edge that means something (a warning).
  final Color? borderColor;

  /// `double.infinity` where the parent leaves the card its own width.
  final double? width;

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null || onLongPress != null;
    final content = Padding(padding: padding, child: child);
    return Container(
      width: width,
      margin: margin,
      child: Material(
        color: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: BorderSide(
            color: borderColor ??
                (selected
                    ? AppColors.primary
                    : tappable
                        ? AppColors.borderStrong
                        : AppColors.border),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: tappable
            ? InkWell(onTap: onTap, onLongPress: onLongPress, child: content)
            : content,
      ),
    );
  }
}
