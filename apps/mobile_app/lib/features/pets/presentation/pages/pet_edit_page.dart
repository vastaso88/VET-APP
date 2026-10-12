import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../data/pet_demo_store.dart';
import '../../data/pet_photo_repository.dart';
import '../../domain/pet_format.dart';
import '../../domain/pet_models.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pet_profile_form.dart';
import '../widgets/pets_scaffold.dart';
import '../widgets/pets_state_views.dart';

class PetEditPage extends StatelessWidget {
  const PetEditPage({
    required this.pet,
    super.key,
    this.state = PetsScreenStatus.success,
    this.errorMessage,
  });

  final PetProfile pet;
  final PetsScreenStatus state;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return PetsScaffold(
      title: context.l10n.petsEditTitle(pet.name),
      onBack: () => Navigator.of(context).maybePop(),
      badge: PetAvatar(
        label: pet.avatarEmoji,
        backgroundColor: pet.accentColor,
        photoBytes: pet.photoBytes,
        photoPath: pet.photoPath,
        identityColor: pet.identityColor,
        size: 36,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryStrong,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: Text(context.l10n.commonClose),
        ),
      ],
      body: switch (state) {
        PetsScreenStatus.loading =>
          PetsLoadingView(label: context.l10n.petsEditLoading),
        PetsScreenStatus.error => PetsErrorView(
            title: context.l10n.petsEditErrorTitle,
            subtitle: errorMessage ?? context.l10n.petsEditErrorDefault,
            actionLabel: context.l10n.commonClose,
            onRetry: () => Navigator.of(context).maybePop(),
          ),
        PetsScreenStatus.empty => _EditForm(pet: pet),
        PetsScreenStatus.success => _EditForm(pet: pet),
      },
    );
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({required this.pet});

  final PetProfile pet;

  @override
  Widget build(BuildContext context) {
    return PetProfileForm(
      title: context.l10n.petsEditFormTitle,
      initialPet: pet,
      submitLabel: context.l10n.petsEditSubmit,
      footerActions: _PetLifecycleActions(pet: pet),
      onSubmit: (draft) async {
        final raw = draft.photoBytes;
        final String? newPhotoPath;
        if (!draft.photoTouched) {
          newPhotoPath = pet.photoPath;
        } else if (raw == null) {
          newPhotoPath = null;
        } else {
          newPhotoPath = await saveProfilePhoto(petId: pet.id, raw: raw);
        }

        final updated = pet.copyWith(
          name: draft.name,
          species: draft.species,
          breed: draft.breed ?? '',
          birthDateLabel: draft.birthDate == null ? '' : formatPetBirthDate(draft.birthDate!),
          sex: draft.sex,
          weightLabel: draft.weightKg == null ? '' : formatPetWeight(draft.weightKg!),
          medicalNote: draft.medicalNote,
          identityColor: draft.identityColor,
          photoBytes: draft.photoTouched ? raw : pet.photoBytes,
          photoPath: newPhotoPath,
          clearPhoto: draft.photoTouched && raw == null,
          aquariumStock: draft.aquariumStock,
          habitat: draft.habitat,
          dogSizeCategory: draft.dogSizeCategory,
          clearDogSizeCategory: draft.dogSizeCategory == null,
        );
        await PetDemoStore.instance.upsert(updated);
        if (!context.mounted) return;
        if (PetDemoStore.instance.isUnsynced(updated.id)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.petsEditUnsyncedSnack)),
          );
        }
        Navigator.of(context).pop(updated);
      },
    );
  }

}

/// Delete and "move to Ricordi" — kept out of [PetProfileForm] itself since
/// they only make sense for an existing pet, never while creating one.
class _PetLifecycleActions extends StatelessWidget {
  const _PetLifecycleActions({required this.pet});

  final PetProfile pet;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
        title: Text(context.l10n.petsEditDeleteTitle),
        content: Text(context.l10n.petsEditDeleteMessage(pet.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(context.l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.petsEditDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await PetDemoStore.instance.delete(pet.id);
    } on PetSyncException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  Future<void> _moveToMemories(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
        title: Text(context.l10n.petsEditMemorialTitle),
        content: Text(context.l10n.petsEditMemorialMessage(pet.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(context.l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.petsEditMemorialConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated = pet.copyWith(isMemorial: true, memorialDate: DateTime.now());
    await PetDemoStore.instance.upsert(updated);
    if (!context.mounted) return;
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _moveToMemories(context),
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: Text(context.l10n.petsEditMemorialAction),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
            label: Text(context.l10n.petsEditDeleteAction, style: const TextStyle(color: AppColors.danger)),
          ),
        ),
      ],
    );
  }
}
