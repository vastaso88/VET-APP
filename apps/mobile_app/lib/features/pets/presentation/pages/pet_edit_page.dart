import 'package:flutter/material.dart';

import '../../data/pet_demo_store.dart';
import '../../domain/pet_models.dart';
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
      title: 'Modifica ${pet.name}.',
      subtitle:
          'Aggiorna i dettagli del profilo senza perdere il tono dell app, con campi validati e selezioni guidate.',
      onBack: () => Navigator.of(context).maybePop(),
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
        PetsScreenStatus.empty => _EditForm(
            pet: pet,
            helperText: 'Nessun dato caricato, quindi la bozza parte pulita.',
          ),
        PetsScreenStatus.success => _EditForm(pet: pet),
      },
    );
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.pet,
    this.helperText = 'Aggiorna i campi da cambiare e lascia invariato il resto.',
  });

  final PetProfile pet;
  final String helperText;

  @override
  Widget build(BuildContext context) {
    return PetProfileForm(
      title: 'Bozza profilo',
      helperText: helperText,
      initialPet: pet,
      submitLabel: 'Salva modifiche',
      onSubmit: (draft) async {
        final updated = pet.copyWith(
          name: draft.name,
          species: draft.species,
          breed: draft.breed ?? '',
          birthDateLabel: _formatDate(draft.birthDate),
          sex: draft.sex,
          weightLabel: _formatWeight(draft.weightKg),
          medicalNote: draft.medicalNote,
          identityColor: draft.identityColor,
          photoBytes: draft.photoBytes,
          clearPhoto: draft.photoBytes == null,
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
