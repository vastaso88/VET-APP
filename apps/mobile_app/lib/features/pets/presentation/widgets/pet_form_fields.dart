import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_details.dart';
import '../../domain/pet_value_labels.dart';

/// Shared by the single-page profile form and the step-by-step creation flow:
/// the fields that exist in both.

/// The look of every text/dropdown field of the pet forms.
InputDecoration petFieldDecoration(String label, String hint) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
    ),
  );
}

/// Maschio / Femmina / Non so. Neutering is a separate switch, not a sex value.
/// Leaving it unselected is the same as "Non so".
class PetSexField extends FormField<String> {
  PetSexField({
    required String? value,
    required ValueChanged<String> onChanged,
    super.key,
  }) : super(
          initialValue: value,
          builder: (state) {
            final context = state.context;
            final labels = {
              sexMale: localizedSexLabel(sexMale),
              sexFemale: localizedSexLabel(sexFemale),
              sexUnknown: context.l10n.petsValueSexUnknownShort,
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.petsFormSexLabel,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    emptySelectionAllowed: true,
                    showSelectedIcon: false,
                    segments: [
                      for (final sex in petSexValues)
                        ButtonSegment<String>(
                          value: sex,
                          // Same size for every option; a long one breaks onto a
                          // second line instead of shrinking.
                          label: Text(
                            labels[sex]!,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                    ],
                    selected: {if (state.value != null) state.value!},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) return;
                      state.didChange(selection.first);
                      onChanged(selection.first);
                    },
                    style: ButtonStyle(
                      textStyle: WidgetStatePropertyAll(
                        AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
}

/// One chip per species, each with its emoji (the same one the pet's avatar
/// falls back to).
class PetSpeciesChips extends FormField<String> {
  PetSpeciesChips({
    required String? value,
    required ValueChanged<String> onChanged,
    required String? Function(String?) validator,
    super.key,
  }) : super(
          initialValue: value,
          validator: validator,
          builder: (state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final option in PetDemoStore.speciesOptions)
                      _SpeciesChoiceChip(
                        emoji: option.avatarEmoji,
                        label: localizedSpeciesLabel(option.label),
                        selected: state.value == option.label,
                        onTap: () {
                          state.didChange(option.label);
                          onChanged(option.label);
                        },
                      ),
                  ],
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xs,
                      left: AppSpacing.xs,
                    ),
                    child: Text(
                      state.errorText!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
}

class _SpeciesChoiceChip extends StatelessWidget {
  const _SpeciesChoiceChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryStrong : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: selected ? AppColors.primaryStrong : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: selected
                          ? AppColors.onPrimary
                          : AppColors.secondaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A two-way choice shown as a segmented control ("Di razza" / "Meticcio").
class PetTwoWayToggle extends StatelessWidget {
  const PetTwoWayToggle({
    required this.firstLabel,
    required this.secondLabel,
    required this.secondSelected,
    required this.onChanged,
    super.key,
  });

  final String firstLabel;
  final String secondLabel;
  final bool secondSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: false, label: Text(firstLabel)),
          ButtonSegment(value: true, label: Text(secondLabel)),
        ],
        selected: {secondSelected},
        onSelectionChanged: (selection) => onChanged(selection.first),
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// A switch row styled like the other fields ("Sterilizzato / castrato").
class PetSwitchTile extends StatelessWidget {
  const PetSwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // A Material (not a decorated Container): the tile paints its ink on the
    // nearest Material, which a coloured box in between would hide.
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

/// A dropdown over a list of stored codes, shown with [labelOf].
class PetCodeDropdown extends StatelessWidget {
  const PetCodeDropdown({
    required this.label,
    required this.hint,
    required this.value,
    required this.codes,
    required this.labelOf,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String hint;
  final String? value;
  final List<String> codes;
  final String Function(String code) labelOf;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: codes.contains(value) ? value : null,
      isExpanded: true,
      decoration: petFieldDecoration(label, hint),
      items: [
        for (final code in codes)
          DropdownMenuItem<String>(value: code, child: Text(labelOf(code))),
      ],
      onChanged: onChanged,
    );
  }
}

/// The dots of the creation flow: [current] (0-based) is the long one.
class PetStepDots extends StatelessWidget {
  const PetStepDots({required this.current, required this.total, super.key});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.petsWizardStepSemantics(current + 1, total),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color:
                    i <= current ? AppColors.primary : AppColors.borderStrong,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
        ],
      ),
    );
  }
}
