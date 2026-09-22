import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../domain/fish_species.dart';
import '../domain/pet_identity_colors.dart';
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
        'Akita',
        'Alano',
        'Barboncino',
        'Basset Hound',
        'Bassotto',
        'Beagle',
        'Border Collie',
        'Boxer',
        'Bulldog francese',
        'Bulldog inglese',
        'Cane Corso',
        'Carlino',
        'Chihuahua',
        'Cocker Spaniel',
        'Dalmata',
        'Dobermann',
        'Golden Retriever',
        'Jack Russell Terrier',
        'Labrador Retriever',
        'Maltese',
        'Meticcio',
        'Pastore Australiano',
        'Pastore Belga Malinois',
        'Pastore Tedesco',
        'Pinscher',
        'Rottweiler',
        'San Bernardo',
        'Schnauzer',
        'Segugio Italiano',
        'Setter Inglese',
        'Shiba Inu',
        'Shih Tzu',
        'Siberian Husky',
        'Spitz',
        'Terranova',
        'Volpino Italiano',
        'Yorkshire Terrier',
      ],
    ),
    PetSpeciesOption(
      label: 'Gatto',
      avatarEmoji: '🐱',
      accentColor: Color(0xFFF6EADF),
      breeds: [
        'Abissino',
        'American Shorthair',
        'Angora Turco',
        'Bengala',
        'Birmano',
        'Blu di Russia',
        'Bombay',
        'British Shorthair',
        'Certosino',
        'Devon Rex',
        'Europeo',
        'Europeo a pelo corto',
        'Exotic Shorthair',
        'Maine Coon',
        'Manx',
        'Meticcio',
        'Norvegese delle foreste',
        'Orientale',
        'Persiano',
        'Ragdoll',
        'Sacro di Birmania',
        'Savannah',
        'Scottish Fold',
        'Siamese',
        'Sphynx',
      ],
    ),
    PetSpeciesOption(
      label: 'Piccoli mammiferi',
      avatarEmoji: '🐹',
      accentColor: Color(0xFFF5F0D8),
      breeds: [
        'Cavia',
        'Chinchilla',
        'Coniglio ariete',
        'Coniglio nano',
        'Coniglio olandese',
        'Coniglio Rex',
        'Criceto Roborovski',
        'Criceto Siberiano',
        'Criceto Siriano',
        'Degu',
        'Furetto',
        'Gerbillo',
        'Istrice africano',
        'Ratto domestico',
        'Riccio africano',
        'Topo domestico',
      ],
    ),
    PetSpeciesOption(
      label: 'Uccello',
      avatarEmoji: '🦜',
      accentColor: Color(0xFFE3EBF0),
      breeds: [
        'Agapornis (inseparabile)',
        'Amazzone',
        'Ara',
        'Cacatua',
        'Calopsite',
        'Canarino',
        'Cocorita',
        'Diamante mandarino',
        'Fringuello',
        'Lorichetto arcobaleno',
        'Pappagallo cenerino',
        'Pappagallo del Senegal',
        'Parrocchetto dal collare',
        'Passero del Giappone',
      ],
    ),
    PetSpeciesOption(
      label: 'Rettili e anfibi',
      avatarEmoji: '🦎',
      accentColor: Color(0xFFEDF0DF),
      breeds: [
        'Axolotl',
        'Boa constrictor',
        'Camaleonte del velo',
        'Drago barbuto',
        'Gecko crestato',
        'Gecko leopardino',
        'Iguana verde',
        'Pitone reale',
        'Rana artigliata africana',
        'Rana toro',
        'Salamandra tigrata',
        'Serpente del latte',
        'Serpente del mais',
        'Testuggine di terra',
        'Testuggine palustre',
        'Tritone',
      ],
    ),
    PetSpeciesOption(
      label: 'Pesce',
      avatarEmoji: '🐠',
      accentColor: Color(0xFFE1EEEE),
      breeds: aquariumFishSpecies,
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

  /// Size classes for a dog whose breed isn't in the list ("Altro") — there's
  /// no specific breed to infer a size range from, so the owner picks one
  /// directly.
  static const List<String> dogSizeCategories = [
    'Toy',
    'Piccola',
    'Media',
    'Grande',
    'Gigante',
  ];

  late List<PetProfile> _pets;

  /// Active pets only by default — pets moved to Ricordi ([PetProfile.isMemorial])
  /// are excluded so they don't clutter the main Animali list; pass
  /// [includeMemorial] to get them (used by the Ricordi page).
  List<PetProfile> list({String? species, bool includeMemorial = false}) {
    final normalizedSpecies = species?.trim().toLowerCase() ?? '';
    final base = includeMemorial ? _pets : _pets.where((pet) => !pet.isMemorial);
    if (normalizedSpecies.isEmpty || normalizedSpecies == 'tutti') {
      return List<PetProfile>.unmodifiable(base);
    }

    return List<PetProfile>.unmodifiable(
      base.where(
        (pet) => pet.species.trim().toLowerCase() == normalizedSpecies,
      ),
    );
  }

  List<PetProfile> memorialPets() =>
      List<PetProfile>.unmodifiable(_pets.where((pet) => pet.isMemorial));

  PetProfile? byId(String id) {
    for (final pet in _pets) {
      if (pet.id == id) {
        return pet;
      }
    }
    return null;
  }

  PetProfile? byName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final pet in _pets) {
      if (pet.name.trim().toLowerCase() == normalized) {
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

  void delete(String id) {
    _pets = _pets.where((pet) => pet.id != id).toList();
  }

  PetProfile create({
    required String name,
    required String species,
    required String? breed,
    required DateTime? birthDate,
    required String sex,
    required double weightKg,
    required Color identityColor,
    String medicalNote = '',
    Uint8List? photoBytes,
    List<FishStock> aquariumStock = const [],
    HabitatDetails? habitat,
    String? dogSizeCategory,
  }) {
    final option = optionForSpecies(species);
    final pet = PetProfile(
      id: 'pet-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      species: species,
      breed: breed?.trim() ?? '',
      dogSizeCategory: dogSizeCategory,
      birthDateLabel: birthDate == null ? '' : _formatDate(birthDate),
      sex: sex,
      weightLabel: _formatWeight(weightKg),
      medicalNote: medicalNote.trim().isEmpty
          ? 'Profilo creato da poco, pronto per la prossima visita.'
          : medicalNote.trim(),
      healthBadge: 'Nuovo profilo',
      nextVisitLabel: 'Da pianificare',
      avatarEmoji: name.trim().isEmpty ? option.avatarEmoji : name.trim()[0].toUpperCase(),
      accentColor: option.accentColor,
      identityColor: identityColor,
      photoBytes: photoBytes,
      aquariumStock: aquariumStock,
      habitat: habitat,
    );

    return upsert(pet);
  }

  /// A default identity color for a new pet, distinct from as many
  /// existing pets' colors as the palette allows.
  Color nextDefaultIdentityColor() => defaultIdentityColorForIndex(_pets.length);

  static PetSpeciesOption optionForSpecies(String species) {
    final normalized = species.trim().toLowerCase();
    return speciesOptions.firstWhere(
      (option) => option.label.toLowerCase() == normalized,
      orElse: () => speciesOptions.last,
    );
  }

  static List<String> breedsForSpecies(String species) {
    final option = optionForSpecies(species);
    // Dogs get "Altro" as the top default instead of an "unspecified"
    // placeholder — picking it unlocks the size-category field below, so an
    // owner whose dog's breed isn't listed can still describe it.
    if (species.trim().toLowerCase() == 'cane') {
      return ['Altro', ...option.breeds];
    }
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
