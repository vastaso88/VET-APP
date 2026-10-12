import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../l10n/l10n.dart';

import '../../data/pet_demo_store.dart';
import '../../data/pet_photo_repository.dart';
import '../../domain/pet_models.dart';
import '../widgets/pet_profile_form.dart';
import '../widgets/pets_scaffold.dart';
import '../widgets/pets_state_views.dart';

class PetCreatePage extends StatelessWidget {
  const PetCreatePage({
    super.key,
    this.state = PetsScreenStatus.success,
    this.errorMessage,
  });

  final PetsScreenStatus state;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return PetsScaffold(
      title: context.l10n.petsCreateTitle,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryStrong,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: Text(context.l10n.commonCancel),
        ),
      ],
      body: switch (state) {
        PetsScreenStatus.loading =>
          PetsLoadingView(label: context.l10n.petsCreateLoading),
        PetsScreenStatus.error => PetsErrorView(
            title: context.l10n.petsCreateErrorTitle,
            subtitle: errorMessage ?? context.l10n.petsCreateErrorDefault,
            actionLabel: context.l10n.commonClose,
            onRetry: () => Navigator.of(context).maybePop(),
          ),
        PetsScreenStatus.empty => const _CreateForm(),
        PetsScreenStatus.success => const _CreateForm(),
      },
    );
  }
}

class _CreateForm extends StatelessWidget {
  const _CreateForm();

  @override
  Widget build(BuildContext context) {
    return PetProfileForm(
      title: context.l10n.petsCreateFormTitle,
      submitLabel: context.l10n.petsCreateSubmit,
      onSubmit: (draft) async {
        final pet = await PetDemoStore.instance.create(
          name: draft.name,
          species: draft.species,
          breed: draft.breed,
          birthDate: draft.birthDate,
          sex: draft.sex,
          weightKg: draft.weightKg,
          medicalNote: draft.medicalNote,
          identityColor: draft.identityColor,
          photoBytes: draft.photoBytes,
          aquariumStock: draft.aquariumStock,
          habitat: draft.habitat,
          dogSizeCategory: draft.dogSizeCategory,
        );
        final raw = draft.photoBytes;
        final photoPath = raw == null ? null : await saveProfilePhoto(petId: pet.id, raw: raw);
        final saved = photoPath == null
            ? pet
            : await PetDemoStore.instance.upsert(pet.copyWith(photoPath: photoPath));
        if (!context.mounted) return;
        if (PetDemoStore.instance.isUnsynced(saved.id)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.petsCreateUnsyncedSnack)),
          );
        }
        Navigator.of(context).pop(saved);
      },
    );
  }
}
