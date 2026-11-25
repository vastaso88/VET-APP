import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radii.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_text_styles.dart';

/// The one field of the app: its name above, always in view and whole (it wraps,
/// it never shrinks), and under it a TextFormField, a dropdown or a [PickerField],
/// whose look (white, round, visible edge) comes from the theme. The name is also
/// what the screen reader says for the field.
class AppField extends StatelessWidget {
  const AppField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: FieldLabel(label)),
        Semantics(label: label, child: child),
      ],
    );
  }
}

/// The name of a field or of a group of choices.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(color: AppColors.text),
      ),
    );
  }
}

/// A field whose value is picked, not typed: same look as the others.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.text,
    required this.onTap,
    this.icon,
    this.placeholder = false,
    this.trailing = const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.mutedText),
  });

  final String text;
  final VoidCallback? onTap;
  final IconData? icon;

  /// [text] says what to do, nothing is picked yet.
  final bool placeholder;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final field = Theme.of(context).inputDecorationTheme;
    final ShapeBorder border = (onTap == null ? field.disabledBorder : field.enabledBorder) ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        );
    return Semantics(
      button: true,
      child: Material(
        color: field.fillColor ?? AppColors.surfaceElevated,
        shape: border,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            // As tall as a field one types in: 48 and its edge.
            constraints: const BoxConstraints(minHeight: 51),
            child: Padding(
              padding: field.contentPadding ??
                  const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      text,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: placeholder ? AppColors.mutedText : AppColors.text,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
