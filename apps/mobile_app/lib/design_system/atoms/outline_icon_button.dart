import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// The round commands of a page's header (back, gallery, edit): outline only.
/// The full petrol is left to the one action the page is there for.
class OutlineIconButton extends StatelessWidget {
  const OutlineIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.child,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Only for what must not look like the others (a deletion); the accent
  /// when null.
  final Color? color;

  /// In place of the plain icon: the icon with a counter on it, a loader.
  final Widget? child;

  /// The same look for a command that is not a button of its own (a menu).
  static ButtonStyle get look => IconButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.surfaceElevated,
        side: BorderSide(color: AppColors.borderStrong),
        // 40 px visible, 48 px to touch.
        tapTargetSize: MaterialTapTargetSize.padded,
      );

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.primary;
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: child ?? Icon(icon),
      color: color,
      style: look.copyWith(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) ? AppColors.mutedText : color,
        ),
      ),
    );
  }
}
