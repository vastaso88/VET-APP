import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../pets/presentation/pages/pet_create_page.dart';

/// Last step of the first-run flow: an optional, skippable nudge to add the
/// first pet right away instead of landing on an empty home. Pops as soon
/// as the owner either creates a pet or explicitly skips.
class AddFirstPetPromptPage extends StatelessWidget {
  const AddFirstPetPromptPage({super.key});

  Future<void> _addPet(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PetCreatePage()),
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // Scrolls instead of overflowing on a small phone or a large system text scale.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 2 * AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.xxl),
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined,
                        size: 44, color: AppColors.accent),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    context.l10n.firstRunAddPetTitle,
                    style: AppTextStyles.title.copyWith(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.l10n.firstRunAddPetBody,
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _addPet(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.pill)),
                      ),
                      child: Text(context.l10n.firstRunAddPetNow),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.firstRunAddPetLater),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
