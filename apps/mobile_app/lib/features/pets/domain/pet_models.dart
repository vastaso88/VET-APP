import 'dart:typed_data';

import 'package:flutter/material.dart';

enum PetsScreenStatus {
  loading,
  empty,
  error,
  success,
}

/// One species' headcount within an aquarium population — split by sex
/// (fish are usually stocked and sexed that way, unlike a single pet with
/// one "Sesso" field) e.g. "Guppy" — 3 males, 5 females.
class FishStock {
  const FishStock({required this.species, this.maleCount = 0, this.femaleCount = 0});

  final String species;
  final int maleCount;
  final int femaleCount;

  int get count => maleCount + femaleCount;

  FishStock copyWith({String? species, int? maleCount, int? femaleCount}) => FishStock(
        species: species ?? this.species,
        maleCount: maleCount ?? this.maleCount,
        femaleCount: femaleCount ?? this.femaleCount,
      );
}

/// Dimensions and setup details for an enclosure — an aquarium (fish), a
/// terrarium (reptiles/amphibians) or an aviary (birds). All fields are
/// optional free text/numbers: owners fill in whatever they actually know,
/// and [isEmpty] lets callers skip rendering the section entirely when
/// nothing was filled in.
class HabitatDetails {
  const HabitatDetails({
    this.dimensions = '',
    this.volumeLiters,
    this.temperatureLabel = '',
    this.substrate = '',
    this.notes = '',
  });

  /// e.g. "60×30×36 cm".
  final String dimensions;

  /// Tank volume — meaningful for an aquarium only.
  final int? volumeLiters;

  /// e.g. "24-26°C" — water temperature, or ambient/UVB-basking temperature.
  final String temperatureLabel;

  /// e.g. "Ghiaia fine", "Fibra di cocco".
  final String substrate;

  /// Catch-all for equipment that varies a lot by setup: filter, lighting,
  /// UVB lamp, humidity, plants, perches, decor.
  final String notes;

  bool get isEmpty =>
      dimensions.trim().isEmpty &&
      volumeLiters == null &&
      temperatureLabel.trim().isEmpty &&
      substrate.trim().isEmpty &&
      notes.trim().isEmpty;

  HabitatDetails copyWith({
    String? dimensions,
    int? volumeLiters,
    bool clearVolume = false,
    String? temperatureLabel,
    String? substrate,
    String? notes,
  }) {
    return HabitatDetails(
      dimensions: dimensions ?? this.dimensions,
      volumeLiters: clearVolume ? null : (volumeLiters ?? this.volumeLiters),
      temperatureLabel: temperatureLabel ?? this.temperatureLabel,
      substrate: substrate ?? this.substrate,
      notes: notes ?? this.notes,
    );
  }
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
    this.aquariumStock = const [],
    this.isMemorial = false,
    this.memorialDate,
    this.habitat,
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

  /// When non-empty, this profile represents a whole aquarium rather than
  /// a single fish — [breed] is unused in that case, [breedLabel] instead
  /// summarizes the population.
  final List<FishStock> aquariumStock;

  bool get isAquarium => aquariumStock.isNotEmpty;

  /// The pet's identity color: picked by the owner, shown on the avatar
  /// badge, the Home calendar markers and its legend — always the same
  /// color for the same pet, unlike [accentColor] which is a pale,
  /// species-shared tone used for card backgrounds.
  final Color identityColor;

  /// Owner-picked photo, session-lifetime only (no backend storage in this
  /// demo). Null falls back to the plain letter avatar.
  final Uint8List? photoBytes;

  /// True once the owner has moved this pet to Ricordi (memories) — it
  /// drops out of the active Animali list but its profile is kept.
  final bool isMemorial;

  /// When this pet was moved to Ricordi, if it was.
  final DateTime? memorialDate;

  /// Aquarium/terrarium/aviary details — set only for species that live in
  /// an enclosure (Pesce, Rettili e anfibi, Uccello).
  final HabitatDetails? habitat;

  String get title => '$name - $species';

  String get breedLabel {
    if (isAquarium) {
      final totalFish = aquariumStock.fold<int>(0, (sum, stock) => sum + stock.count);
      final speciesCount = aquariumStock.length;
      final speciesLabel = speciesCount == 1 ? '1 specie' : '$speciesCount specie';
      final fishLabel = totalFish == 1 ? '1 pesce' : '$totalFish pesci';
      return '$speciesLabel · $fishLabel';
    }
    return breed.trim().isEmpty ? 'Razza non specificata' : breed.trim();
  }

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
    List<FishStock>? aquariumStock,
    bool? isMemorial,
    DateTime? memorialDate,
    HabitatDetails? habitat,
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
      aquariumStock: aquariumStock ?? this.aquariumStock,
      isMemorial: isMemorial ?? this.isMemorial,
      memorialDate: memorialDate ?? this.memorialDate,
      habitat: habitat ?? this.habitat,
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
    habitat: HabitatDetails(
      dimensions: '100×50×50 cm',
      temperatureLabel: '28-35°C giorno, 22°C notte',
      substrate: 'Substrato per rettili, sabbia fine',
      notes: 'Lampada UVB e punto luce basking, ciotola per bagno.',
    ),
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
    habitat: HabitatDetails(
      dimensions: '60×40×60 cm',
      substrate: 'Carta o pellet vegetale',
      notes: 'Posatoi di diverso diametro, giochi da rosicchiare, mangiatoia e abbeveratoio.',
    ),
  ),
  PetProfile(
    id: 'pet-acquario-salotto',
    name: 'Acquario del salotto',
    species: 'Pesce',
    breed: '',
    birthDateLabel: 'Giu 2024',
    sex: 'Sconosciuto',
    weightLabel: '0,4 kg',
    medicalNote:
        'Filtro pulito ogni settimana, parametri dell\'acqua controllati regolarmente.',
    healthBadge: 'Stabile',
    nextVisitLabel: 'Cambio acqua tra 5 giorni',
    avatarEmoji: 'A',
    accentColor: Color(0xFFE1EEEE),
    identityColor: Color(0xFF3D9E9E),
    habitat: HabitatDetails(
      dimensions: '80×35×40 cm',
      volumeLiters: 112,
      temperatureLabel: '24-26°C',
      substrate: 'Ghiaia fine scura',
      notes: 'Filtro esterno, riscaldatore 100W, piante vive, illuminazione LED a spettro completo.',
    ),
    aquariumStock: [
      FishStock(species: 'Guppy', maleCount: 3, femaleCount: 5),
      FishStock(species: 'Neon tetra', maleCount: 5, femaleCount: 5),
      FishStock(species: 'Corydoras', maleCount: 2, femaleCount: 2),
    ],
  ),
];
