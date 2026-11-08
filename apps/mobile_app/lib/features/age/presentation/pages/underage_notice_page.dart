import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../account/presentation/widgets/account_page_scaffold.dart';

/// Shown at registration when the date of birth is under the minimum age.
/// No account was created and nothing was sent or saved: the date was only
/// compared on the phone.
class UnderageNoticePage extends StatelessWidget {
  const UnderageNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AccountPageScaffold(
      title: l10n.ageClosedTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.pets_rounded, size: 40, color: AppColors.mutedText),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.ageUnderageBody, style: AppTextStyles.body.copyWith(color: AppColors.text)),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }
}
