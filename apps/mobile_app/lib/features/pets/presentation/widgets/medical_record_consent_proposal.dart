import 'package:flutter/material.dart';

import 'medical_record_consent_card.dart';
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
  final activate = await askToActivateClinicalConsent(context, pet.name);
  if (!activate) return;
  final result =
      await (remote ?? MedicalRecordConsentRemoteDataSource()).setGranted(petId: pet.id, granted: true);
  result.fold(
    onSuccess: (saved) => PetDemoStore.instance.setMedicalRecordConsentLocal(pet.id, saved),
    onFailure: (_) {
      // Not saved: the card on the animal's page still offers it.
    },
  );
}
