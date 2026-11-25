import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_spacing.dart';

/// The bar at the bottom of a phone. Its names stay whole, on one line and
/// clear of the edge: when the longest does not fit its part of the bar, all of
/// them get smaller together.
class ShellBottomBar extends StatelessWidget {
  const ShellBottomBar({
    super.key,
    required this.width,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final double width;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  static const _edge = AppSpacing.sm;

  /// Left free on the sides of the longest name, all together.
  static const _gap = 10.0;

  /// How much the names may grow: the longest fills its part, less a margin.
  double _largestScale(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium!;
    final longest = destinations
        .map((destination) => TextPainter.computeWidth(
              text: TextSpan(text: destination.label, style: style),
              textDirection: Directionality.of(context),
            ))
        .reduce(math.max);
    return ((width - 2 * _edge) / destinations.length - _gap) / longest;
  }

  @override
  Widget build(BuildContext context) {
    // The names are measured: again when the app's own font arrives.
    return ListenableBuilder(
      listenable: PaintingBinding.instance.systemFonts,
      builder: (context, _) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: _largestScale(context),
        child: ColoredBox(
          color: AppColors.surfaceElevated,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _edge),
            child: NavigationBar(
              height: 76,
              backgroundColor: AppColors.surfaceElevated,
              indicatorColor: AppColors.secondarySoft,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations,
            ),
          ),
        ),
      ),
    );
  }
}
