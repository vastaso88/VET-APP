import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../data/pet_demo_store.dart';
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
    this.errorMessage = 'Non riesco ad aprire questo profilo pet per la modifica.',
  });

  final PetProfile pet;
  final PetsScreenStatus state;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return PetsScaffold(
      title: 'Modifica ${pet.name}',
      onBack: () => Navigator.of(context).maybePop(),
      badge: PetAvatar(
        label: pet.avatarEmoji,
        backgroundColor: pet.accentColor,
        photoBytes: pet.photoBytes,
        identityColor: pet.identityColor,
        size: 36,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('Chiudi'),
        ),
      ],
      body: switch (state) {
        PetsScreenStatus.loading =>
          const PetsLoadingView(label: 'Carico il form di modifica...'),
        PetsScreenStatus.error => PetsErrorView(
            title: 'Modifica non disponibile',
            subtitle: errorMessage,
            actionLabel: 'Chiudi',
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
      title: 'Bozza profilo',
      initialPet: pet,
      submitLabel: 'Salva modifiche',
      footerActions: _PetLifecycleActions(pet: pet),
      onSubmit: (draft) async {
        final updated = pet.copyWith(
          name: draft.name,
          species: draft.species,
          breed: draft.breed ?? '',
          birthDateLabel: draft.birthDate == null ? '' : _formatDate(draft.birthDate!),
          sex: draft.sex,
          weightLabel: _formatWeight(draft.weightKg),
          medicalNote: draft.medicalNote,
          identityColor: draft.identityColor,
          photoBytes: draft.photoBytes,
          clearPhoto: draft.photoBytes == null,
          aquariumStock: draft.aquariumStock,
          habitat: draft.habitat,
          dogSizeCategory: draft.dogSizeCategory,
          clearDogSizeCategory: draft.dogSizeCategory == null,
        );
        PetDemoStore.instance.upsert(updated);
        Navigator.of(context).pop(updated);
      },
    );
  }

  String _formatWeight(double weightKg) {
    final normalized =
        weightKg.toStringAsFixed(weightKg.truncateToDouble() == weightKg ? 0 : 1);
    return '${normalized.replaceAll('.', ',')} kg';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Gen',
      'Feb',
      'Mar',
      'Apr',
      'Mag',
      'Giu',
      'Lug',
      'Ago',
      'Set',
      'Ott',
      'Nov',
      'Dic',
    ];

    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
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
        title: const Text('Rimuovere questo profilo?'),
        content: Text('Il profilo di "${pet.name}" verrà eliminato definitivamente, insieme ai suoi dati.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    PetDemoStore.instance.delete(pet.id);
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
        title: const Text('Spostare nei ricordi?'),
        content: Text(
          '"${pet.name}" uscirà dalla lista Animali e sarà conservato nella sezione Ricordi, '
          'con il suo profilo e le sue foto.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sposta'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated = pet.copyWith(isMemorial: true, memorialDate: DateTime.now());
    PetDemoStore.instance.upsert(updated);
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
            label: const Text('Sposta nei ricordi'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
            label: const Text('Rimuovi profilo', style: TextStyle(color: AppColors.danger)),
          ),
        ),
      ],
    );
  }
}
