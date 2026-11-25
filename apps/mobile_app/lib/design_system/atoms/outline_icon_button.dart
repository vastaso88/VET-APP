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
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: AppColors.primary,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceElevated,
        side: const BorderSide(color: AppColors.borderStrong),
        // 40 px visible, 48 px to touch.
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
