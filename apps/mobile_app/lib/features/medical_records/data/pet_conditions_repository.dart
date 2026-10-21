import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/auth/current_user.dart';
import '../../../../shared/config/app_runtime_config_loader.dart';
import '../../../l10n/l10n.dart';
import '../domain/pet_condition.dart';
import 'medical_records_repository.dart' show MedicalRecordSaveException;

/// The pets' illnesses ("Patologie"), kept in the `pet_conditions` table
/// (owner only, see supabase_schema.sql). Without Supabase (local tests, demo
/// builds) they live in memory for the session.
class PetConditionsRepository {
  PetConditionsRepository({SupabaseClient? client}) : _client = client;

  /// Bumped after every save/delete so open lists reload.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  final SupabaseClient? _client;

  static const _columns =
      'id,pet_id,name,started_on,status,ended_on,therapy,notes,attachment_id,attachment_name';

  static final List<PetConditionEntry> _preview = [];

  Future<List<PetConditionEntry>> loadForPet(String petId) async {
    final client = _resolveClient();
    if (client == null) {
      return sortConditions(_preview.where((c) => c.petId == petId));
    }
    // Errors are rethrown on purpose: an empty list would look like "no
    // illnesses" and hide that the server could not be read.
    final rows =
        await client.from('pet_conditions').select(_columns).eq('pet_id', petId)
            as List<dynamic>;
    return sortConditions(
      rows.map((row) => _fromRow(row as Map<String, dynamic>)),
    );
  }

  Future<void> save(PetConditionEntry condition) async {
    final client = _resolveClient();
    if (client == null) {
      _preview.removeWhere((c) => c.id == condition.id);
      _preview.add(condition);
      changes.value++;
      return;
    }
    final ownerId = CurrentUser.get()?.id;
    if (ownerId == null) {
      throw MedicalRecordSaveException(appL10n.medicalSaveNoSession);
    }
    try {
      await client.from('pet_conditions').upsert({
        'id': condition.id,
        'owner_id': ownerId,
        'pet_id': condition.petId,
        'name': condition.name,
        'started_on': _isoDate(condition.startedOn),
        'status': condition.ongoing ? 'ongoing' : 'resolved',
        'ended_on': condition.ongoing ? null : _isoDate(condition.endedOn),
        'therapy': condition.therapy.isEmpty ? null : condition.therapy,
        'notes': condition.notes.isEmpty ? null : condition.notes,
        'attachment_id': condition.attachmentId,
        'attachment_name': condition.attachmentName,
      });
    } catch (_) {
      throw MedicalRecordSaveException(appL10n.medCondSaveFailed);
    }
    changes.value++;
  }

  Future<void> delete(String id) async {
    final client = _resolveClient();
    if (client == null) {
      _preview.removeWhere((c) => c.id == id);
      changes.value++;
      return;
    }
    try {
      await client.from('pet_conditions').delete().eq('id', id);
    } catch (_) {
      throw MedicalRecordSaveException(appL10n.medCondDeleteFailed);
    }
    changes.value++;
  }

  SupabaseClient? _resolveClient() {
    if (_client != null) return _client;
    final config = const AppRuntimeConfigLoader().load();
    if (!config.hasSupabaseCredentials) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}

PetConditionEntry _fromRow(Map<String, dynamic> row) {
  return PetConditionEntry(
    id: (row['id'] ?? '').toString(),
    petId: (row['pet_id'] ?? '').toString(),
    name: (row['name'] ?? '').toString(),
    startedOn: _parseDay(row['started_on']),
    ongoing: row['status'] != 'resolved',
    endedOn: _parseDay(row['ended_on']),
    therapy: (row['therapy'] ?? '').toString(),
    notes: (row['notes'] ?? '').toString(),
    attachmentId: row['attachment_id'] as String?,
    attachmentName: row['attachment_name'] as String?,
  );
}

/// A `date` column ("2026-03-12") as a local calendar day.
DateTime? _parseDay(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

String? _isoDate(DateTime? date) {
  if (date == null) return null;
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
