import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/widgets/collapsible_section.dart';
import '../../data/language_store.dart';
import '../pages/language_picker_page.dart';

/// "Lingua" section of Impostazioni. Renders nothing while only one
/// translation exists, so today the Settings page is unchanged.
class LanguageSettingsSection extends StatelessWidget {
  const LanguageSettingsSection({
    super.key,
    required this.expanded,
    required this.onToggle,
  });

  static const sectionId = 'lingua';

  final bool expanded;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final store = LanguageStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.hasChoice) return const SizedBox.shrink();
        final l10n = context.l10n;
        return CollapsibleSection(
          sectionId: sectionId,
          expanded: expanded,
          onToggle: onToggle,
          title: l10n.languageSectionTitle,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                l10n.languageSectionHint,
                style: AppTextStyles.caption.copyWith(color: AppColors.secondaryText),
              ),
            ),
            for (final variant in store.available)
              LanguageVariantTile(
                variant: variant,
                selected: store.variant.id == variant.id,
                onTap: () => store.choose(variant),
              ),
          ],
        );
      },
    );
  }
}
