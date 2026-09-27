import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../domain/fish_species.dart';
import '../domain/pet_format.dart';
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
  // Starts empty: real per-account contents are loaded lazily via
  // [ensureHydrated] once the signed-in owner id is known (see
  // docs/auth/01_brainstorm.md, 2026-09-26), rather than seeding every
  // account with the same fixed cast of simulation pets.
  PetDemoStore._() {
    _pets = [];
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

  /// Owner id this store's current in-memory contents were hydrated for, so
  /// [ensureHydrated] is a no-op on repeated calls (e.g. every page's
  /// initState) and correctly re-hydrates if a different account signs in
  /// within the same app session.
  String? _hydratedOwnerId;

  /// Loads this owner's pets from Supabase into the in-memory store, once
  /// per owner id. No-ops (and leaves the store as-is) when Supabase isn't
  /// configured or the request fails — same best-effort-remote pattern as
  /// RemindersRepository.
  Future<void> ensureHydrated() async {
    final ownerId = CurrentUser.get()?.id;
    if (ownerId == null || ownerId == _hydratedOwnerId) {
      return;
    }

    final client = _resolveClient();
    if (client == null) {
      return;
    }

    try {
      final response = await client.from('pet_profiles').select('*').eq('owner_id', ownerId);
      final rows = response as List<dynamic>;
      final loaded = <PetProfile>[];
      for (final row in rows) {
        final pet = _petFromRow(row as Map<String, dynamic>);
        if (pet != null) {
          loaded.add(pet);
        }
      }
      _pets = loaded;
      _hydratedOwnerId = ownerId;
    } catch (_) {
      // Leave the local/demo contents in place; retried next call since
      // _hydratedOwnerId wasn't set.
    }
  }

  Future<void> _persistRemote(PetProfile pet) async {
    final ownerId = CurrentUser.get()?.id;
    final client = _resolveClient();
    if (ownerId == null || client == null) {
      return;
    }

    try {
      await client.from('pet_profiles').upsert(_petToRow(pet, ownerId));
    } catch (_) {
      // Best-effort: kept locally regardless.
    }
  }

  Future<void> _deleteRemote(String id) async {
    final client = _resolveClient();
    if (client == null) {
      return;
    }

    try {
      await client.from('pet_profiles').delete().eq('id', id);
    } catch (_) {
      // Removed locally regardless.
    }
  }

  SupabaseClient? _resolveClient() {
    final config = const AppRuntimeConfigLoader().load();
    if (!config.hasSupabaseCredentials) {
      return null;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _petToRow(PetProfile pet, String ownerId) => {
        'id': pet.id,
        'owner_id': ownerId,
        'name': pet.name,
        'species': pet.species,
        'breed': pet.breed,
        'notes': pet.medicalNote,
        'birth_date_label': pet.birthDateLabel,
        'sex': pet.sex,
        'weight_label': pet.weightLabel,
        'health_badge': pet.healthBadge,
        'next_visit_label': pet.nextVisitLabel,
        'avatar_emoji': pet.avatarEmoji,
        'accent_color_value': pet.accentColor.toARGB32(),
        'identity_color_value': pet.identityColor.toARGB32(),
        'dog_size_category': pet.dogSizeCategory,
        'is_memorial': pet.isMemorial,
        'memorial_date_label':
            pet.memorialDate == null ? null : formatPetBirthDate(pet.memorialDate!),
        'habitat': pet.habitat == null ? null : _habitatToJson(pet.habitat!),
        'aquarium_stock': pet.aquariumStock.map(_fishStockToJson).toList(),
      };

  PetProfile? _petFromRow(Map<String, dynamic> row) {
    final id = (row['id'] ?? '').toString();
    final name = (row['name'] ?? '').toString();
    final species = (row['species'] ?? '').toString();
    if (id.isEmpty || name.isEmpty || species.isEmpty) {
      return null;
    }

    final option = optionForSpecies(species);
    return PetProfile(
      id: id,
      name: name,
      species: species,
      breed: (row['breed'] ?? '').toString(),
      birthDateLabel: (row['birth_date_label'] ?? '').toString(),
      sex: (row['sex'] ?? '').toString(),
      weightLabel: (row['weight_label'] ?? '').toString(),
      medicalNote: (row['notes'] ?? '').toString(),
      healthBadge: (row['health_badge'] ?? '').toString(),
      nextVisitLabel: (row['next_visit_label'] ?? '').toString(),
      avatarEmoji: (row['avatar_emoji'] ?? (name.isEmpty ? '' : name[0].toUpperCase())).toString(),
      accentColor: _colorFromValue(row['accent_color_value']) ?? option.accentColor,
      identityColor: _colorFromValue(row['identity_color_value']) ?? option.accentColor,
      dogSizeCategory: row['dog_size_category'] as String?,
      isMemorial: row['is_memorial'] as bool? ?? false,
      habitat: _habitatFromJson(row['habitat'] as Map<String, dynamic>?),
      aquariumStock: ((row['aquarium_stock'] as List<dynamic>?) ?? const [])
          .map((item) => _fishStockFromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  static Color? _colorFromValue(dynamic value) {
    if (value is int) return Color(value);
    if (value is num) return Color(value.toInt());
    return null;
  }

  static Map<String, dynamic> _habitatToJson(HabitatDetails habitat) => {
        'length_cm': habitat.lengthCm,
        'width_cm': habitat.widthCm,
        'height_cm': habitat.heightCm,
        'volume_liters': habitat.volumeLiters,
        'temperature_label': habitat.temperatureLabel,
        'substrate': habitat.substrate,
        'notes': habitat.notes,
      };

  static HabitatDetails? _habitatFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return HabitatDetails(
      lengthCm: json['length_cm'] as int?,
      widthCm: json['width_cm'] as int?,
      heightCm: json['height_cm'] as int?,
      volumeLiters: json['volume_liters'] as int?,
      temperatureLabel: (json['temperature_label'] ?? '').toString(),
      substrate: (json['substrate'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
    );
  }

  static Map<String, dynamic> _fishStockToJson(FishStock stock) => {
        'species': stock.species,
        'male_count': stock.maleCount,
        'female_count': stock.femaleCount,
      };

  static FishStock _fishStockFromJson(Map<String, dynamic> json) => FishStock(
        species: (json['species'] ?? '').toString(),
        maleCount: json['male_count'] as int? ?? 0,
        femaleCount: json['female_count'] as int? ?? 0,
      );

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

  /// Awaits the remote write before returning — a fire-and-forget write
  /// here previously let the caller navigate away (or the tab close/reload)
  /// before the Supabase upsert actually landed, so a just-created pet
  /// could silently vanish on the next load even though it looked saved.
  Future<PetProfile> upsert(PetProfile pet) async {
    final index = _pets.indexWhere((item) => item.id == pet.id);
    if (index == -1) {
      _pets = [pet, ..._pets];
    } else {
      _pets = [
        ..._pets.take(index),
        pet,
        ..._pets.skip(index + 1),
      ];
    }

    await _persistRemote(pet);
    return pet;
  }

  Future<void> delete(String id) async {
    _pets = _pets.where((pet) => pet.id != id).toList();
    await _deleteRemote(id);
  }

  Future<PetProfile> create({
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
      birthDateLabel: birthDate == null ? '' : formatPetBirthDate(birthDate),
      sex: sex,
      weightLabel: formatPetWeight(weightKg),
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

}
