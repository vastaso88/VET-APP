import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../data/medical_record_consent_remote_data_source.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_models.dart';

/// At the end of creating an animal: asks once whether the assistant may read
/// its medical record, with the same text and the same stored decision as the
/// card on the animal's page and in Settings. "Attiva" and "Più tardi" weigh the
/// same; "Più tardi" records nothing and nothing insists afterwards.
///
/// Nothing is asked when a decision already exists for this animal.
Future<void> proposeMedicalRecordConsent(
  BuildContext context,
  PetProfile pet, {
  MedicalRecordConsentRemoteDataSource? remote,
}) async {
  if (pet.medicalRecordConsentGranted != null) return;
  final activate = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.petsConsentCardTitle(pet.name)),
      content: SingleChildScrollView(child: Text(dialogContext.l10n.petsConsentFullText)),
      actions: [
        TextButton(
          key: const ValueKey('consent-proposal-later'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.petsConsentProposalLater),
        ),
        TextButton(
          key: const ValueKey('consent-proposal-activate'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(dialogContext.l10n.petsConsentProposalActivate),
        ),
      ],
    ),
  );
  if (activate != true) return;
  final result =
      await (remote ?? MedicalRecordConsentRemoteDataSource()).setGranted(petId: pet.id, granted: true);
  result.fold(
    onSuccess: (saved) => PetDemoStore.instance.setMedicalRecordConsentLocal(pet.id, saved),
    onFailure: (_) {
      // Not saved: the card on the animal's page still offers it.
    },
  );
}
