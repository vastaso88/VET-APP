import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';

/// The tabs of the animal's page: all of them always in view across the full
/// width, every title whole and at the same size. One row when the titles fit,
/// otherwise the same tabs on two (four: 2 + 2; a dog's five: 3 + 2).
class PetTabBar extends StatelessWidget {
  const PetTabBar({super.key, required this.controller, required this.labels});

  final TabController controller;
  final List<String> labels;

  /// As few rows as the titles need, as even as possible. [widths] are what
  /// each title takes; the result holds the index of the tabs of each row.
  static List<List<int>> rowsFor(List<double> widths, double maxWidth) {
    for (var rows = 1; rows < widths.length; rows++) {
      final perRow = (widths.length / rows).ceil();
      final split = [
        for (var start = 0; start < widths.length; start += perRow)
          [for (var i = start; i < math.min(start + perRow, widths.length); i++) i],
      ];
      final fits = split.every(
        (row) => row.fold<double>(0, (sum, i) => sum + widths[i]) <= maxWidth,
      );
      if (fits) return split;
    }
    return [
      for (var i = 0; i < widths.length; i++) [i],
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Measured exactly as it is drawn, with what the page's text style adds.
    final bold = DefaultTextStyle.of(context)
        .style
        .merge(AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700));
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    // The titles are measured: again when the app's own font arrives.
    return ListenableBuilder(
      listenable: PaintingBinding.instance.systemFonts,
      builder: (context, _) {
        final widths = [
          for (final label in labels)
            TextPainter.computeWidth(
                  text: TextSpan(text: label, style: bold),
                  textDirection: direction,
                  textScaler: scaler,
                  maxLines: 1,
                ) +
                2 * AppSpacing.xs,
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final rows = rowsFor(widths, constraints.maxWidth);
            // Equal columns where the titles allow it, else each as wide as its title.
            bool equal(List<int> row) =>
                row.every((i) => widths[i] <= constraints.maxWidth / row.length);
            return AnimatedBuilder(
              animation: controller.animation!,
              builder: (context, _) {
                final current = controller.animation!.value.round();
                return Semantics(
                  role: SemanticsRole.tabBar,
                  container: true,
                  explicitChildNodes: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final row in rows)
                        Row(
                          children: [
                            for (final i in row)
                              Expanded(
                                flex: equal(row) ? 1 : (widths[i] * 100).round(),
                                child: _tab(context, i, selected: i == current, bold: bold),
                              ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _tab(BuildContext context, int index, {required bool selected, required TextStyle bold}) {
    return MergeSemantics(
      child: Semantics(
        role: SemanticsRole.tab,
        selected: selected,
        hint: MaterialLocalizations.of(context)
            .tabLabel(tabIndex: index + 1, tabCount: labels.length),
        child: InkWell(
          onTap: () => controller.animateTo(index),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border(
                bottom: selected
                    ? BorderSide(color: AppColors.primary, width: 3)
                    : BorderSide(color: AppColors.border),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: DefaultTextStyle(
                style: bold.copyWith(
                  color: selected ? AppColors.primary : AppColors.mutedText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
                child: PetTabLabel(labels[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab title: on one line and whole, never shortened with dots.
class PetTabLabel extends StatelessWidget {
  const PetTabLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(child: Text(label, maxLines: 1, softWrap: false));
  }
}
