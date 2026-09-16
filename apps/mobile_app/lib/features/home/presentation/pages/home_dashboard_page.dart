import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/auth/current_user.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../../pets/domain/pet_models.dart';
import '../../../pets/presentation/pages/pet_detail_page.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pets = PetDemoStore.instance.list();
    final ownerName = CurrentUser.firstName(fallback: 'Ospite');

    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF9F6F1),
              Color(0xFFF4EFE7),
              Color(0xFFEDE6DC),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buongiorno', style: AppTextStyles.caption),
                    const SizedBox(height: AppSpacing.xs),
                    Text(ownerName, style: AppTextStyles.display),
                    const SizedBox(height: AppSpacing.xxl),
                    if (pets.isEmpty)
                      const _EmptyPets()
                    else
                      ...pets.map(
                        (pet) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: _PetCard(pet: pet),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet});

  final PetProfile pet;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PetDetailPage(pet: pet)),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [pet.accentColor.withValues(alpha: 0.55), AppColors.surface],
            ),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: pet.accentColor,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                ),
                child: Center(
                  child: Text(
                    pet.avatarEmoji,
                    style: AppTextStyles.title.copyWith(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name, style: AppTextStyles.title),
                    const SizedBox(height: 2),
                    Text(pet.title, style: AppTextStyles.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            pet.healthBadge,
                            style: AppTextStyles.caption.copyWith(color: AppColors.primaryStrong),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      pet.nextVisitLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPets extends StatelessWidget {
  const _EmptyPets();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nessun animale ancora', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Aggiungi il primo profilo dalla scheda Animali per iniziare.',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}
