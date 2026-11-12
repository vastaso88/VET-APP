import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../data/language_store.dart';
import '../../domain/app_language.dart';

/// First-run page: the owner picks the language (with a flag) before
/// registering. Shown only when more than one translation exists, see
/// [FirstRunLanguageGate].
class LanguagePickerPage extends StatelessWidget {
  const LanguagePickerPage({super.key, required this.onChosen});

  /// Called once a variant has been chosen and applied.
  final VoidCallback onChosen;

  @override
  Widget build(BuildContext context) {
    final store = LanguageStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final l10n = context.l10n;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                const SizedBox(height: AppSpacing.xl),
                Text(l10n.languagePickerTitle, style: AppTextStyles.display.copyWith(fontSize: 28)),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.languagePickerSubtitle, style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.xl),
                for (final variant in store.available)
                  LanguageVariantTile(
                    variant: variant,
                    selected: store.hasChosen && store.variant.id == variant.id,
                    onTap: () async {
                      await store.choose(variant);
                      onChosen();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A flag + name row, shared by the first-run page and the Settings section.
class LanguageVariantTile extends StatelessWidget {
  const LanguageVariantTile({
    super.key,
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  final AppLanguageVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: variant.nativeName,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(variant.flag, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    variant.nativeName,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
                  ),
                ),
                if (selected) const Icon(Icons.check_rounded, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
