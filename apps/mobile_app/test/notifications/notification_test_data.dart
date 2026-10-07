import 'package:flutter/material.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';

/// Synthetic pets for the notification tests — no real data.
PetProfile testPet(String name, {String birth = '', bool memorial = false}) {
  return PetProfile(
    id: 'pet-$name',
    name: name,
    species: 'Cane',
    breed: '',
    birthDateLabel: birth,
    sex: '',
    weightLabel: '',
    medicalNote: '',
    healthBadge: '',
    nextVisitLabel: '',
    avatarEmoji: '',
    accentColor: Colors.blue,
    identityColor: Colors.blue,
    isMemorial: memorial,
  );
}
