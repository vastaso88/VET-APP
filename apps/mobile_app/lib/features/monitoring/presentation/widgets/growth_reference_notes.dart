import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/domain/unit_system.dart';
import '../../domain/growth_reference.dart';
import '../../domain/weight_units.dart';

/// What the owner decided in the adult size sheet: a class, or "I don't know".
/// The sheet returns null when it is just dismissed.
class AdultSizeChoice {
  const AdultSizeChoice(this.sizeClass);

  final AdultSizeClass? sizeClass;
}

/// "Meno di 6,5 kg", "Da 6,5 kg a 9 kg", "Più di 40 kg".
String adultSizeLabel(AdultSizeClass sizeClass, UnitSystem system) {
  final l10n = appL10n;
  final from = sizeClass.fromKg;
  final to = sizeClass.toKg;
  if (from == null) {
    return l10n.monitoringGrowthClassUnder(formatMeasuredWeight(to!, system));
  }
  if (to == null) {
    return l10n.monitoringGrowthClassOver(formatMeasuredWeight(from, system));
  }
  return l10n.monitoringGrowthClassBetween(
    formatMeasuredWeight(from, system),
    formatMeasuredWeight(to, system),
  );
}

Future<AdultSizeChoice?> showAdultSizeSheet(
  BuildContext context, {
  required String petName,
  required UnitSystem system,
  AdultSizeClass? current,
}) {
  return showModalBottomSheet<AdultSizeChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
    ),
    builder: (context) {
      final l10n = context.l10n;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.monitoringGrowthSheetTitle(petName),
                style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            for (final sizeClass in AdultSizeClass.values)
              ListTile(
                key: ValueKey('growth-class-${sizeClass.code}'),
                contentPadding: EdgeInsets.zero,
                title: Text(adultSizeLabel(sizeClass, system)),
                trailing: sizeClass == current
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () =>
                    Navigator.of(context).pop(AdultSizeChoice(sizeClass)),
              ),
            ListTile(
              key: const ValueKey('growth-class-unknown'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.monitoringGrowthClassUnknown),
              onTap: () => Navigator.of(context).pop(const AdultSizeChoice(null)),
            ),
          ],
        ),
      );
    },
  );
}

/// Under the growth chart: the expected adult weight of a dog (to change it),
/// the legend of the bands, the source with its "derived from" wording and the
/// "a reference, not a diagnosis" notice. Without bands for a dog that could
/// have them, it asks for the expected adult weight instead.
class GrowthReferenceNotes extends StatelessWidget {
  const GrowthReferenceNotes({
    required this.petName,
    required this.system,
    required this.reference,
    required this.sizeClass,
    required this.canChooseSize,
    required this.onChooseSize,
    super.key,
  });

  final String petName;
  final UnitSystem system;

  /// Null when no bands are drawn.
  final GrowthReference? reference;

  /// The class of a dog (chosen, or implied by "Toy"); null when unknown.
  final AdultSizeClass? sizeClass;

  /// Whether this is a young dog whose class can be chosen.
  final bool canChooseSize;
  final VoidCallback onChooseSize;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reference = this.reference;

    if (reference == null && !canChooseSize) return const SizedBox.shrink();

    final children = <Widget>[];
    if (reference == null) {
      // A dog without a usable class: ask for it, or explain there is none.
      final heavy = sizeClass == AdultSizeClass.vi;
      children
        ..add(Text(
          heavy
              ? l10n.monitoringGrowthNoReferenceHeavy
              : l10n.monitoringGrowthPromptBody(petName),
          key: const ValueKey('growth-prompt'),
          style: AppTextStyles.bodySmall,
        ))
        ..add(const SizedBox(height: AppSpacing.sm))
        ..add(OutlinedButton(
          key: const ValueKey('growth-choose'),
          onPressed: onChooseSize,
          child: Text(heavy
              ? l10n.monitoringGrowthChange
              : l10n.monitoringGrowthPromptButton),
        ));
    } else {
      if (reference.isPuppy && sizeClass != null) {
        children.add(Row(
          children: [
            Expanded(
              child: Text(
                l10n.monitoringGrowthExpectedAdult(
                    adultSizeLabel(sizeClass!, system)),
                key: const ValueKey('growth-expected'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('growth-change'),
              onPressed: onChooseSize,
              child: Text(l10n.monitoringGrowthChange),
            ),
          ],
        ));
      }
      children
        ..add(Text(l10n.monitoringGrowthLegend,
            key: const ValueKey('growth-legend'),
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500)))
        ..add(const SizedBox(height: AppSpacing.xs))
        ..add(Text(
          reference.isPuppy
              ? l10n.monitoringGrowthSourcePuppy(
                  adultSizeLabel(reference.sizeClass!, system))
              : l10n.monitoringGrowthSourceKitten,
          key: const ValueKey('growth-source'),
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500),
        ))
        ..add(const SizedBox(height: AppSpacing.xs))
        ..add(Text(
          l10n.monitoringGrowthDisclaimer(petName),
          key: const ValueKey('growth-disclaimer'),
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500),
        ));
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
