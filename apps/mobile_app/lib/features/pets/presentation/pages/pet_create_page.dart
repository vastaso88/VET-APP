import 'package:flutter/material.dart';

import '../../data/pet_demo_store.dart';
import '../../domain/pet_models.dart';
import '../widgets/pet_profile_form.dart';
import '../widgets/pets_scaffold.dart';
import '../widgets/pets_state_views.dart';

class PetCreatePage extends StatelessWidget {
  const PetCreatePage({
    super.key,
    this.state = PetsScreenStatus.success,
    this.errorMessage = 'Al momento non riesco a creare un nuovo profilo pet.',
  });

  final PetsScreenStatus state;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return PetsScaffold(
      title: 'Crea un profilo pet',
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('Annulla'),
        ),
      ],
      body: switch (state) {
        PetsScreenStatus.loading =>
          const PetsLoadingView(label: 'Preparo il form di creazione...'),
        PetsScreenStatus.error => PetsErrorView(
            title: 'Form di creazione non disponibile',
            subtitle: errorMessage,
            actionLabel: 'Chiudi',
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
      title: 'Nuovo profilo',
      submitLabel: 'Salva profilo pet',
      onSubmit: (draft) async {
        final pet = PetDemoStore.instance.create(
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
        );
        Navigator.of(context).pop(pet);
      },
    );
  }
}
