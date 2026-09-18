import 'package:flutter/material.dart';

import '../domain/pet_models.dart';

class PetSpeciesOption {
  const PetSpeciesOption({
    required this.label,
    required this.avatarEmoji,
    required this.accentColor,
    required this.breeds,
  });

  final String label;
  final String avatarEmoji;
  final Color accentColor;
  final List<String> breeds;
}

class PetDemoStore {
  PetDemoStore._() {
    _pets = List<PetProfile>.of(samplePets);
  }

  static final PetDemoStore instance = PetDemoStore._();

  static const List<PetSpeciesOption> speciesOptions = [
    PetSpeciesOption(
      label: 'Cane',
      avatarEmoji: '🐶',
      accentColor: Color(0xFFE7F2EE),
      breeds: [
        'Labrador Retriever',
        'Golden Retriever',
        'Border Collie',
        'Meticcio',
      ],
    ),
    PetSpeciesOption(
      label: 'Gatto',
      avatarEmoji: '🐱',
      accentColor: Color(0xFFF6EADF),
      breeds: [
        'Europeo',
        'Europeo a pelo corto',
        'Siamese',
        'Norvegese delle foreste',
      ],
    ),
    PetSpeciesOption(
      label: 'Piccoli mammiferi',
      avatarEmoji: '🐹',
      accentColor: Color(0xFFF5F0D8),
      breeds: [
        'Coniglio olandese',
        'Coniglio nano',
        'Coniglio ariete',
        'Criceto',
        'Cavia',
        'Cincillà',
        'Gerbillo',
        'Furetto',
      ],
    ),
    PetSpeciesOption(
      label: 'Uccello',
      avatarEmoji: '🦜',
      accentColor: Color(0xFFE3EBF0),
      breeds: [
        'Pappagallo',
        'Canarino',
        'Cocorita',
      ],
    ),
    PetSpeciesOption(
      label: 'Rettili e anfibi',
      avatarEmoji: '🦎',
      accentColor: Color(0xFFEDF0DF),
      breeds: [
        'Drago barbuto',
        'Gecko leopardino',
        'Testuggine',
        'Serpente del mais',
        'Rana',
        'Salamandra',
        'Axolotl',
      ],
    ),
    PetSpeciesOption(
      label: 'Pesce',
      avatarEmoji: '🐠',
      accentColor: Color(0xFFE1EEEE),
      breeds: [
        'Pesce rosso',
        'Betta',
        'Ciclide',
      ],
    ),
    PetSpeciesOption(
      label: 'Altro',
      avatarEmoji: '🐾',
      accentColor: Color(0xFFF1E7F3),
      breeds: [],
    ),
  ];

  static const List<String> sexOptions = [
    'Maschio',
    'Femmina',
    'Sconosciuto',
  ];

  late List<PetProfile> _pets;

  List<PetProfile> list({String? species}) {
    final normalizedSpecies = species?.trim().toLowerCase() ?? '';
    if (normalizedSpecies.isEmpty || normalizedSpecies == 'tutti') {
      return List<PetProfile>.unmodifiable(_pets);
    }

    return List<PetProfile>.unmodifiable(
      _pets.where(
        (pet) => pet.species.trim().toLowerCase() == normalizedSpecies,
      ),
    );
  }

  PetProfile? byId(String id) {
    for (final pet in _pets) {
      if (pet.id == id) {
        return pet;
      }
    }
    return null;
  }

  PetProfile upsert(PetProfile pet) {
    final index = _pets.indexWhere((item) => item.id == pet.id);
    if (index == -1) {
      _pets = [pet, ..._pets];
      return pet;
    }

    _pets = [
      ..._pets.take(index),
      pet,
      ..._pets.skip(index + 1),
    ];
    return pet;
  }

  PetProfile create({
    required String name,
    required String species,
    required String? breed,
    required DateTime birthDate,
    required String sex,
    required double weightKg,
    String medicalNote = '',
  }) {
    final option = optionForSpecies(species);
    final pet = PetProfile(
      id: 'pet-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      species: species,
      breed: breed?.trim() ?? '',
      birthDateLabel: _formatDate(birthDate),
      sex: sex,
      weightLabel: _formatWeight(weightKg),
      medicalNote: medicalNote.trim().isEmpty
          ? 'Profilo creato da poco, pronto per la prossima visita.'
          : medicalNote.trim(),
      healthBadge: 'Nuovo profilo',
      nextVisitLabel: 'Da pianificare',
      avatarEmoji: name.trim().isEmpty ? option.avatarEmoji : name.trim()[0].toUpperCase(),
      accentColor: option.accentColor,
    );

    return upsert(pet);
  }

  static PetSpeciesOption optionForSpecies(String species) {
    final normalized = species.trim().toLowerCase();
    return speciesOptions.firstWhere(
      (option) => option.label.toLowerCase() == normalized,
      orElse: () => speciesOptions.last,
    );
  }

  static List<String> breedsForSpecies(String species) {
    final option = optionForSpecies(species);
    return [
      'Razza non specificata',
      ...option.breeds,
    ];
  }

  static String _formatWeight(double weightKg) {
    final normalized = weightKg.toStringAsFixed(weightKg.truncateToDouble() == weightKg ? 0 : 1);
    return '${normalized.replaceAll('.', ',')} kg';
  }

  static String _formatDate(DateTime date) {
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
