import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../domain/fish_species.dart';
import '../domain/pet_breeds.dart';
import '../domain/pet_format.dart';
import '../domain/pet_species_breeds.dart';
import 'pet_photo_repository.dart';
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

  static final List<PetSpeciesOption> speciesOptions = [
    const PetSpeciesOption(
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
    const PetSpeciesOption(
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
      accentColor: const Color(0xFFF5F0D8),
      breeds: smallMammalBreeds,
    ),
    PetSpeciesOption(
      label: 'Uccello',
      avatarEmoji: '🦜',
      accentColor: const Color(0xFFE3EBF0),
      breeds: birdBreeds,
    ),
    PetSpeciesOption(
      label: 'Rettili e anfibi',
      avatarEmoji: '🦎',
      accentColor: const Color(0xFFEDF0DF),
      breeds: reptileAmphibianBreeds,
    ),
    PetSpeciesOption(
      label: 'Pesce',
      avatarEmoji: '🐠',
      accentColor: const Color(0xFFE1EEEE),
      breeds: aquariumFishSpecies,
    ),
    PetSpeciesOption(
      label: 'Altro',
      avatarEmoji: '🐾',
      accentColor: const Color(0xFFF1E7F3),
      breeds: otherAnimalBreeds,
    ),
  ];

  /// Values stored in pet_profiles.sex and read by the chat backend (which
  /// echoes them as text, so changing them needs its prompt side aligned).
  static const List<String> sexOptions = [
    'Maschio',
    'Femmina',
    'Maschio intero',
    'Maschio castrato',
    'Femmina intera',
    'Femmina sterilizzata',
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

  /// Bumped whenever the pet list changes (hydration, upsert, delete), so a
  /// list page kept alive under the bottom-nav IndexedStack re-reads it.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// Loads this owner's pets from Supabase into the in-memory store, once
  /// per owner id. No-ops (and leaves the store as-is) when Supabase isn't
  /// configured or the request fails — same best-effort-remote pattern as
  /// RemindersRepository.
  Future<void> ensureHydrated() {
    final ownerId = CurrentUser.get()?.id;
    if (ownerId == null || ownerId == _hydratedOwnerId) {
      return Future<void>.value();
    }
    // Concurrent callers (splash preload, Home, Pets, walk widget...) share
    // one in-flight query instead of each issuing their own.
    return _hydrating ??= _hydrate(ownerId).whenComplete(() => _hydrating = null);
  }

  Future<void>? _hydrating;

  Future<void> _hydrate(String ownerId) async {
    final client = _resolveClient();
    if (client == null) {
      return;
    }

    try {
      final response = await client
          .from('pet_profiles')
          .select('*')
          .eq('owner_id', ownerId)
          .timeout(const Duration(seconds: 12));
      final rows = response as List<dynamic>;
      final loaded = <PetProfile>[];
      for (final row in rows) {
        final pet = _petFromRow(row as Map<String, dynamic>);
        if (pet != null) {
          loaded.add(pet);
        }
      }
      for (final pet in _pets) {
        if (_unsynced.contains(pet.id) && loaded.every((item) => item.id != pet.id)) {
          loaded.add(pet);
        }
      }
      _pets = loaded;
      _hydratedOwnerId = ownerId;
      changes.value++;
    } catch (_) {
      // Leave the local/demo contents in place; retried next call since
      // _hydratedOwnerId wasn't set.
    }
  }

  /// Pets whose last write to the server failed. They stay visible on this
  /// device, flagged for the owner, and are kept across reloads this session.
  final Set<String> _unsynced = {};

  bool isUnsynced(String id) => _unsynced.contains(id);

  /// Writes [pet] to the server. Returns false (and flags the pet) when the
  /// write failed; local-only mode (no backend or signed out) counts as saved.
  Future<bool> _persistRemote(PetProfile pet) async {
    final ownerId = CurrentUser.get()?.id;
    final client = _resolveClient();
    if (ownerId == null || client == null) {
      return true;
    }

    try {
      await client.from('pet_profiles').upsert(_petToRow(pet, ownerId));
      _unsynced.remove(pet.id);
      changes.value++;
      return true;
    } catch (_) {
      _unsynced.add(pet.id);
      changes.value++;
      return false;
    }
  }

  /// Tries again to save a pet flagged as unsynced. Returns true when it worked.
  Future<bool> retrySync(String id) async {
    final pet = _pets.where((item) => item.id == id).firstOrNull;
    if (pet == null) return true;
    return _persistRemote(pet);
  }

  Future<void> _deleteRemote(String id) async {
    final client = _resolveClient();
    if (client == null) {
      return;
    }

    try {
      await client.from('pet_profiles').delete().eq('id', id);
    } catch (_) {
      throw const PetSyncException('Non sono riuscito a eliminare il profilo. Riprova.');
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
        'photo_path': pet.photoPath,
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
      photoPath: (row['photo_path'] as String?)?.isNotEmpty == true ? row['photo_path'] as String : null,
      medicalRecordConsentGranted: _grantedFromConsentJson(row['medical_record_consent']),
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

    changes.value++;
    await _persistRemote(pet);
    return pet;
  }

  /// Applies a consent decision to the in-memory pet and notifies listeners,
  /// so the records tab and anything else showing the pet update at once.
  void setMedicalRecordConsentLocal(String petId, bool granted) {
    _pets = [
      for (final pet in _pets)
        if (pet.id == petId) pet.copyWith(medicalRecordConsentGranted: granted) else pet,
    ];
    changes.value++;
  }

  /// Reads this pet's consent from its Supabase row (the same data the backend
  /// stores in `pet_profiles.medical_record_consent`). Null when unavailable.
  Future<bool?> fetchMedicalRecordConsent(String petId) async {
    final client = _resolveClient();
    if (client == null) return null;
    try {
      final row = await client
          .from('pet_profiles')
          .select('medical_record_consent')
          .eq('id', petId)
          .maybeSingle();
      return _grantedFromConsentJson(row?['medical_record_consent']);
    } catch (_) {
      return null;
    }
  }

  /// The consent text version the app shows today (see
  /// medical_record_consent_card.dart and, on the backend,
  /// packages/core/domain/medical_record/consent_text.py).
  static const _currentConsentVersion = 'v2';

  /// A decision taken under an earlier consent text counts as no decision
  /// (2026-10-06): the switch shows "off / not decided" and the owner
  /// decides again on the current wording. Same rule as the backend.
  static bool? _grantedFromConsentJson(Object? json) {
    if (json is! Map || json['granted'] is! bool) return null;
    if (json['version'] != _currentConsentVersion) return null;
    return json['granted'] as bool;
  }

  /// Deletes the pet. If the server refuses, the pet is put back and the
  /// [PetSyncException] reaches the caller — never a silent disappearance.
  Future<void> delete(String id) async {
    final previous = _pets;
    _pets = _pets.where((pet) => pet.id != id).toList();
    changes.value++;
    try {
      await _deleteRemote(id);
    } catch (_) {
      _pets = previous;
      changes.value++;
      rethrow;
    }
    _unsynced.remove(id);
    await PetPhotoRepository().deleteAllForPet(id);
  }

  Future<PetProfile> create({
    required String name,
    required String species,
    required String? breed,
    required DateTime? birthDate,
    required String sex,
    double? weightKg,
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
      weightLabel: weightKg == null ? '' : formatPetWeight(weightKg),
      medicalNote: medicalNote.trim().isEmpty
          ? 'Profilo creato da poco, pronto per la prossima visita.'
          : medicalNote.trim(),
      healthBadge: 'Da valutare',
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
    final key = species.trim().toLowerCase();
    // Dogs and cats: the full recognised list (alphabetical) and the free
    // "Meticcio / altra razza" option last, which opens a text field.
    if (key == 'cane') return [meticcioBreedLabel, ...fciDogBreeds, otherBreedLabel];
    if (key == 'gatto') return [catMeticcioBreedLabel, ...fifeCatBreeds, otherBreedLabel];
    // Every other category: its generic entries first (styled like
    // "Meticcio / incrocio"), then the list, then "Altra (scrivi)".
    return otherSpeciesBreedOptions(key) ?? ['Razza non specificata', ...optionForSpecies(species).breeds];
  }

}

/// A pet change that did not reach the server. The message is shown to the owner.
class PetSyncException implements Exception {
  const PetSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}
