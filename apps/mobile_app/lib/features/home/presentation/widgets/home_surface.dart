import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../../shared/widgets/app_card.dart';

/// The card of every page ([AppCard]), with no room of its own around its rows.
class HomeCard extends AppCard {
  const HomeCard({super.key, required super.child, super.padding = EdgeInsets.zero, super.onTap});
}

/// While a section of Home loads: the spinning animal, never an empty grey box.
class HomeSectionLoader extends StatelessWidget {
  const HomeSectionLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        height: 96,
        child: Center(child: PetLoader()),
      ),
    );
  }
}

/// A section that has nothing to show: what happened and, when asking again
/// makes sense, "Riprova".
class HomeSectionNotice extends StatelessWidget {
  const HomeSectionNotice({super.key, required this.text, this.action});

  final Widget text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text,
            if (action != null) ...[const SizedBox(height: AppSpacing.sm), action!],
          ],
        ),
      ),
    );
  }
}
