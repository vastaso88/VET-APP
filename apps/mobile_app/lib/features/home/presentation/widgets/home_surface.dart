import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../shared/widgets/pet_loader.dart';

/// The white card of Home. When it can be tapped, the ripple is painted on the
/// card and under the text: nothing grey ever goes over what is written.
class HomeCard extends StatelessWidget {
  const HomeCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
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
