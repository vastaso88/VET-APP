import 'dart:typed_data';

import 'package:flutter/material.dart';

enum PetsScreenStatus {
  loading,
  empty,
  error,
  success,
}

class PetProfile {
  const PetProfile({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.birthDateLabel,
    required this.sex,
    required this.weightLabel,
    required this.medicalNote,
    required this.healthBadge,
    required this.nextVisitLabel,
    required this.avatarEmoji,
    required this.accentColor,
    required this.identityColor,
    this.photoBytes,
  });

  final String id;
  final String name;
  final String species;
  final String breed;
  final String birthDateLabel;
  final String sex;
  final String weightLabel;
  final String medicalNote;
  final String healthBadge;
  final String nextVisitLabel;
  final String avatarEmoji;
  final Color accentColor;

  /// The pet's identity color: picked by the owner, shown on the avatar
  /// badge, the Home calendar markers and its legend — always the same
  /// color for the same pet, unlike [accentColor] which is a pale,
  /// species-shared tone used for card backgrounds.
  final Color identityColor;

  /// Owner-picked photo, session-lifetime only (no backend storage in this
  /// demo). Null falls back to the plain letter avatar.
  final Uint8List? photoBytes;

  String get title => '$name - $species';
  String get breedLabel =>
      breed.trim().isEmpty ? 'Razza non specificata' : breed.trim();

  PetProfile copyWith({
    String? id,
    String? name,
    String? species,
    String? breed,
    String? birthDateLabel,
    String? sex,
    String? weightLabel,
    String? medicalNote,
    String? healthBadge,
    String? nextVisitLabel,
    String? avatarEmoji,
    Color? accentColor,
    Color? identityColor,
    Uint8List? photoBytes,
    bool clearPhoto = false,
  }) {
    return PetProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      birthDateLabel: birthDateLabel ?? this.birthDateLabel,
      sex: sex ?? this.sex,
      weightLabel: weightLabel ?? this.weightLabel,
      medicalNote: medicalNote ?? this.medicalNote,
      healthBadge: healthBadge ?? this.healthBadge,
      nextVisitLabel: nextVisitLabel ?? this.nextVisitLabel,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      accentColor: accentColor ?? this.accentColor,
      identityColor: identityColor ?? this.identityColor,
      photoBytes: clearPhoto ? null : (photoBytes ?? this.photoBytes),
    );
  }
}

const samplePets = <PetProfile>[
  PetProfile(
    id: 'pet-moka',
    name: 'Moka',
    species: 'Cane',
    breed: 'Meticcio di taglia media',
    birthDateLabel: 'Mag 2021',
    sex: 'Femmina',
    weightLabel: '17,8 kg',
    medicalNote:
        'Stomaco delicato, dieta leggera e controllo periodico già pianificato.',
    healthBadge: 'Stabile',
    nextVisitLabel: 'Vaccino di richiamo tra 12 giorni',
    avatarEmoji: 'M',
    accentColor: Color(0xFFE7F2EE),
    identityColor: Color(0xFF2F9E68),
  ),
  PetProfile(
    id: 'pet-oliver',
    name: 'Oliver',
    species: 'Gatto',
    breed: 'Europeo a pelo corto',
    birthDateLabel: 'Set 2019',
    sex: 'Maschio',
    weightLabel: '5,1 kg',
    medicalNote:
        'Vita in casa, toelettatura regolare e attenzione ai controlli dentali.',
    healthBadge: 'Da monitorare',
    nextVisitLabel: 'Controllo dentale la prossima settimana',
    avatarEmoji: 'O',
    accentColor: Color(0xFFF6EADF),
    identityColor: Color(0xFFD98C3D),
  ),
  PetProfile(
    id: 'pet-rex',
    name: 'Rex',
    species: 'Rettili e anfibi',
    breed: 'Drago barbuto',
    birthDateLabel: 'Lug 2023',
    sex: 'Maschio',
    weightLabel: '420 g',
    medicalNote:
        'Muta in corso: pelle secca vicino alla coda, terrario a 38°C con lampada UVB attiva.',
    healthBadge: 'In muta',
    nextVisitLabel: 'Controllo UVB terrario tra 3 giorni',
    avatarEmoji: 'R',
    accentColor: Color(0xFFEDF0DF),
    identityColor: Color(0xFF7A8C3D),
  ),
  PetProfile(
    id: 'pet-pico',
    name: 'Pico',
    species: 'Uccello',
    breed: 'Cocorita',
    birthDateLabel: 'Feb 2022',
    sex: 'Sconosciuto',
    weightLabel: '32 g',
    medicalNote: 'Piumaggio regolare, buon appetito, gabbia pulita ogni settimana.',
    healthBadge: 'Stabile',
    nextVisitLabel: 'Controllo becco e unghie tra un mese',
    avatarEmoji: 'P',
    accentColor: Color(0xFFE3EBF0),
    identityColor: Color(0xFF5B7FD6),
  ),
];
