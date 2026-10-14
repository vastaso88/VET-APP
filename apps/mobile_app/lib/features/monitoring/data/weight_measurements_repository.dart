import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/auth/current_owner.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../pets/data/pet_demo_store.dart';
import '../../pets/domain/pet_format.dart';
import '../domain/body_condition.dart';
import '../domain/weight_measurement.dart';

/// The weighings of the owner's pets (`pet_weight_measurements`). Same shape
/// as the other repositories: Supabase when the app is configured for it, a
/// session-lifetime list otherwise (demo / tests), and every write is awaited
/// so the caller knows whether it reached the server.
///
/// The latest weighing is also the weight of the pet profile: after every
/// change [PetProfile.weightLabel] is rewritten from it (the chat backend
/// reads the weighings themselves, with their date, and falls back on that
/// label for a pet that has none).
class WeightMeasurementsRepository {
  WeightMeasurementsRepository(
      {SupabaseClient? client, String Function()? ownerIdResolver})
      : _clientOverride = client,
        _ownerIdResolver = ownerIdResolver ?? resolveCurrentOwnerId;

  final SupabaseClient? _clientOverride;
  final String Function() _ownerIdResolver;

  static const _table = 'pet_weight_measurements';

  /// What each pet's list looked like the last time it was read or written:
  /// the answer while the server cannot be reached, and the whole truth when
  /// no server is configured.
  static final Map<String, List<WeightMeasurement>> _known = {};

  /// Ticks whenever a weighing is added, changed or deleted, so open pages
  /// reload.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  @visibleForTesting
  static void resetForTest() {
    _known.clear();
    changes.value = 0;
  }

  SupabaseClient? _resolveClient() {
    if (_clientOverride != null) return _clientOverride;
    if (!const AppRuntimeConfigLoader().load().hasSupabaseCredentials) {
      return null;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// The weighings of [petId], oldest first.
  Future<List<WeightMeasurement>> load(String petId) async {
    final client = _resolveClient();
    if (client != null) {
      try {
        final rows = await client
            .from(_table)
            .select('*')
            .eq('pet_id', petId)
            .timeout(const Duration(seconds: 12)) as List<dynamic>;
        _known[petId] = [
          for (final row in rows)
            if (WeightMeasurement.fromRow(row as Map<String, dynamic>)
                case final item?)
              item,
        ];
      } catch (_) {
        // Keep showing what this session already knows.
      }
    }
    return sortedByDate(_known[petId] ?? const <WeightMeasurement>[]);
  }

  /// Tells apart two weighings created within the same clock tick.
  static int _sequence = 0;

  /// A new weighing for [petId], not saved yet.
  WeightMeasurement create({
    required String petId,
    required DateTime measuredOn,
    required double weightKg,
    BodyCondition? bodyCondition,
    String note = '',
  }) =>
      WeightMeasurement(
        id: 'wm-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
        petId: petId,
        ownerId: _ownerIdResolver(),
        measuredOn: DateTime(measuredOn.year, measuredOn.month, measuredOn.day),
        weightKg: weightKg,
        bodyCondition: bodyCondition,
        note: note.trim(),
        createdAt: DateTime.now(),
      );

  /// Saves a new weighing. False when the server refused it (nothing is kept).
  Future<bool> add(WeightMeasurement measurement) => _write(
        measurement.petId,
        apply: (list) => [...list, measurement],
        remote: (client) => client.from(_table).insert(measurement.toRow()),
      );

  /// Saves the changes to an existing weighing.
  Future<bool> update(WeightMeasurement measurement) => _write(
        measurement.petId,
        apply: (list) => [
          for (final item in list)
            item.id == measurement.id ? measurement : item
        ],
        remote: (client) {
          final row = measurement.toRow()
            ..remove('id')
            ..remove('pet_id')
            ..remove('owner_id');
          return client.from(_table).update(row).eq('id', measurement.id);
        },
      );

  Future<bool> delete(WeightMeasurement measurement) => _write(
        measurement.petId,
        apply: (list) => [
          for (final item in list)
            if (item.id != measurement.id) item,
        ],
        remote: (client) =>
            client.from(_table).delete().eq('id', measurement.id),
      );

  Future<bool> _write(
    String petId, {
    required List<WeightMeasurement> Function(List<WeightMeasurement>) apply,
    required Future<dynamic> Function(SupabaseClient client) remote,
  }) async {
    final client = _resolveClient();
    // Start from what the server has, so the profile weight never ignores
    // weighings this session has not read yet.
    if (!_known.containsKey(petId)) await load(petId);
    if (client != null) {
      try {
        await remote(client).timeout(const Duration(seconds: 12));
      } catch (_) {
        return false;
      }
    }
    _known[petId] =
        apply(List.of(_known[petId] ?? const <WeightMeasurement>[]));
    changes.value++;
    await _syncProfileWeight(petId);
    return true;
  }

  /// Makes the latest weighing the weight shown in the pet profile.
  Future<void> _syncProfileWeight(String petId) async {
    final pet = PetDemoStore.instance.byId(petId);
    if (pet == null) return;
    final latest =
        latestMeasurement(_known[petId] ?? const <WeightMeasurement>[]);
    final label = latest == null ? '' : formatPetWeight(latest.weightKg);
    if (label == pet.weightLabel) return;
    await PetDemoStore.instance.upsert(pet.copyWith(weightLabel: label));
  }
}
