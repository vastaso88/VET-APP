import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../../../../shared/auth/current_user.dart';
import '../../../../shared/config/app_runtime_config_loader.dart';
import '../../pets/data/pet_demo_store.dart';
import '../domain/record_category.dart';

class MedicalRecordEntry {
  const MedicalRecordEntry({
    required this.id,
    required this.petName,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.badge,
    required this.detailSource,
    required this.createdAt,
    required this.timeline,
    this.attachmentId,
    this.category = RecordCategory.document,
    this.subtype,
    this.eventDate,
    this.notes = '',
    this.createdOn,
  });

  final String id;
  final String petName;
  final String title;
  final String subtitle;
  final String meta;
  final String badge;
  final String detailSource;
  final String createdAt;
  final List<MedicalRecordTimelineEntry> timeline;

  /// Id of the real file behind this record in the chat-attachments
  /// storage pipeline (see HttpChatAttachmentRemoteDataSource) — null for
  /// records with no uploaded file (seed/demo entries, or a PDF, which
  /// that pipeline doesn't support yet).
  final String? attachmentId;

  /// Visit, exam, vaccine, therapy or document (the default, and what every
  /// record uploaded before the categories is).
  final RecordCategory category;

  /// The finer type from [RecordCategory.subtypes] (e.g. 'blood'), if chosen.
  final String? subtype;

  /// The day the visit/exam/vaccine happened, as the owner set it. Not the
  /// upload day ([createdAt]).
  final DateTime? eventDate;

  /// The owner's own notes. Never sent to the chat.
  final String notes;

  /// When the record was created, kept raw for sorting ([createdAt] is text).
  final DateTime? createdOn;

  /// The day lists are ordered by: when it happened, else when it was added.
  DateTime get sortDate => eventDate ?? createdOn ?? DateTime.fromMillisecondsSinceEpoch(0);

  MedicalRecordEntry copyWith({
    String? title,
    RecordCategory? category,
    String? subtype,
    DateTime? eventDate,
    String? notes,
    bool clearSubtype = false,
  }) {
    return MedicalRecordEntry(
      id: id,
      petName: petName,
      title: title ?? this.title,
      subtitle: subtitle,
      meta: meta,
      badge: badge,
      detailSource: detailSource,
      createdAt: createdAt,
      timeline: timeline,
      attachmentId: attachmentId,
      category: category ?? this.category,
      subtype: clearSubtype ? null : subtype ?? this.subtype,
      eventDate: eventDate ?? this.eventDate,
      notes: notes ?? this.notes,
      createdOn: createdOn,
    );
  }
}

class MedicalRecordTimelineEntry {
  const MedicalRecordTimelineEntry({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class MedicalRecordsRepository {
  MedicalRecordsRepository({SupabaseClient? client}) : _client = client;

  /// Bumped after every save/delete so any list showing records (under the
  /// bottom-nav IndexedStack, or a pushed page that stays mounted) re-fetches
  /// instead of keeping the snapshot it loaded once in initState.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  final SupabaseClient? _client;

  Future<List<MedicalRecordEntry>> loadRecords() async {
    final client = _resolveClient();
    if (client == null) {
      return _previewRecords;
    }

    // Errors are rethrown on purpose: an empty list would look like "no
    // records" and hide that the server could not be read.
    try {
      final rows = await _selectRows(client);
      final fromServer = rows
          .map((row) => medicalRecordFromRow(row as Map<String, dynamic>))
          .toList(growable: false);
      return mergeRecentRecords(fromServer, _savedThisSession);
    } catch (_) {
      // A read that fails (e.g. a schema mismatch) must not hide what was just saved.
      if (_savedThisSession.isEmpty) rethrow;
      return List<MedicalRecordEntry>.of(_savedThisSession);
    }
  }

  Future<MedicalRecordEntry?> loadRecordById(String id) async {
    final records = await loadRecords();
    for (final record in records) {
      if (record.id == id) {
        return record;
      }
    }
    return records.isEmpty ? null : records.first;
  }

  Future<void> saveRecord(MedicalRecordEntry record) async {
    final client = _resolveClient();
    if (client == null) {
      _upsertPreviewRecord(record);
      changes.value++;
      return;
    }

    final ownerId = CurrentUser.get()?.id;
    if (ownerId == null) {
      throw MedicalRecordSaveException(appL10n.medicalSaveNoSession);
    }
    await PetDemoStore.instance.ensureHydrated();
    final petId = PetDemoStore.instance.byName(record.petName)?.id;
    if (petId == null) {
      throw MedicalRecordSaveException(appL10n.medicalSavePetNotSynced(record.petName));
    }

    final now = DateTime.now().toUtc();
    final legacyRow = <String, Object?>{
      'id': record.id,
      'owner_id': ownerId,
      'pet_id': petId,
      // The category also travels in event_type (a plain text column the live
      // table always had), so even before the category columns exist an
      // entry keeps its category after a reload instead of becoming a document.
      'event_type': record.category.key,
      'event_date': _isoDate(record.eventDate ?? now),
      'created_at': now.toIso8601String(),
      'title': record.title,
      'pet_name': record.petName,
      'subtitle': record.subtitle,
      'meta': record.meta,
      'badge': record.badge,
      'detail_source': record.detailSource,
      'attachment_id': record.attachmentId,
    };
    final fullRow = <String, Object?>{
      ...legacyRow,
      'event_type': record.category.key,
      'category': record.category.key,
      'subtype': record.subtype,
      'notes': record.notes.isEmpty ? null : record.notes,
    };
    try {
      try {
        await client.from('clinical_events').upsert(fullRow);
      } catch (error) {
        // The schema script not run yet (no category columns): the file and
        // its date are worth more than the label, so save without them.
        if (!_isMissingColumn(error)) rethrow;
        await client.from('clinical_events').upsert(legacyRow);
      }
    } catch (_) {
      throw MedicalRecordSaveException(appL10n.medicalSaveFailed);
    }
    _savedThisSession.removeWhere((item) => item.id == record.id);
    _savedThisSession.add(record);
    changes.value++;
  }

  /// Saves what the owner can edit after the fact: title, category, type,
  /// event date and notes. The file stays as it was.
  Future<void> updateRecordDetails(MedicalRecordEntry updated) async {
    final client = _resolveClient();
    if (client == null) {
      final index = _previewRecords.indexWhere((item) => item.id == updated.id);
      if (index != -1) _previewRecords[index] = updated;
      changes.value++;
      return;
    }

    // event_date is NOT NULL on the live table: only written when there is one.
    final legacyChanges = <String, Object?>{
      'title': updated.title,
      'event_type': updated.category.key,
      if (updated.eventDate != null) 'event_date': _isoDate(updated.eventDate!),
    };
    try {
      try {
        await client
            .from('clinical_events')
            .update({
              ...legacyChanges,
              'category': updated.category.key,
              'subtype': updated.subtype,
              'notes': updated.notes.isEmpty ? null : updated.notes,
            })
            .eq('id', updated.id);
      } catch (error) {
        // The schema script not run yet: keep at least the title, type and date.
        if (!_isMissingColumn(error)) rethrow;
        await client.from('clinical_events').update(legacyChanges).eq('id', updated.id);
      }
    } catch (_) {
      throw MedicalRecordSaveException(appL10n.medicalSaveFailed);
    }
    final sessionIndex = _savedThisSession.indexWhere((item) => item.id == updated.id);
    if (sessionIndex != -1) _savedThisSession[sessionIndex] = updated;
    changes.value++;
  }

  /// Changes only the title: the date and the file stay as they were.
  Future<void> renameRecord(MedicalRecordEntry record, String title) async {
    final client = _resolveClient();
    if (client == null) {
      final index = _previewRecords.indexWhere((item) => item.id == record.id);
      if (index != -1) _previewRecords[index] = record.copyWith(title: title);
      changes.value++;
      return;
    }

    try {
      await client.from('clinical_events').update({'title': title}).eq('id', record.id);
    } catch (_) {
      throw MedicalRecordSaveException(appL10n.medicalRenameFailed);
    }
    final sessionIndex = _savedThisSession.indexWhere((item) => item.id == record.id);
    if (sessionIndex != -1) _savedThisSession[sessionIndex] = record.copyWith(title: title);
    changes.value++;
  }

  Future<void> deleteRecord(String id) async {
    final client = _resolveClient();
    if (client == null) {
      _previewRecords.removeWhere((record) => record.id == id);
      changes.value++;
      return;
    }

    try {
      await client.from('clinical_events').delete().eq('id', id);
    } catch (_) {
      throw MedicalRecordSaveException(appL10n.medicalDeleteFailed);
    }
    _savedThisSession.removeWhere((item) => item.id == id);
    changes.value++;
  }

  static List<MedicalRecordEntry> get previewRecords =>
      List<MedicalRecordEntry>.unmodifiable(_previewRecords);

  static MedicalRecordEntry? previewRecordById(String id) {
    for (final record in _previewRecords) {
      if (record.id == id) {
        return record;
      }
    }
    return _previewRecords.isEmpty ? null : _previewRecords.first;
  }

  SupabaseClient? _resolveClient() {
    if (_client != null) {
      return _client;
    }

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

  static final List<MedicalRecordEntry> _previewRecords = [
    MedicalRecordEntry(
      id: 'moka-richiamo-vaccinale',
      eventDate: DateTime(2026, 3, 25),
      category: RecordCategory.vaccine,
      petName: 'Moka',
      title: 'Richiamo vaccinale di Moka',
      subtitle: 'PDF - 2 pagine - Clinica Vet Roma',
      meta: 'Caricato oggi, pronto da mostrare a Francesco',
      badge: 'Da condividere',
      detailSource: 'Clinica Vet Roma',
      createdAt: '25 Mar 2026, 09:32',
      timeline: const [
        MedicalRecordTimelineEntry(label: 'Importato', value: '25 Mar 2026'),
        MedicalRecordTimelineEntry(
            label: 'Revisionato', value: '25 Mar 2026, 09:45'),
        MedicalRecordTimelineEntry(
            label: "Pronto per l'invio", value: 'Disponibile'),
      ],
    ),
    MedicalRecordEntry(
      id: 'moka-esame-ematico',
      eventDate: DateTime(2026, 3, 24),
      category: RecordCategory.exam,
      petName: 'Moka',
      title: 'Esame ematico di Moka',
      subtitle: 'PDF - 4 pagine - controlli di routine',
      meta: 'Letto ieri, richiede un controllo rapido',
      badge: 'Da rivedere',
      detailSource: 'Laboratorio Vet',
      createdAt: '24 Mar 2026, 17:08',
      timeline: const [
        MedicalRecordTimelineEntry(label: 'Importato', value: '24 Mar 2026'),
        MedicalRecordTimelineEntry(
            label: 'Revisionato', value: '24 Mar 2026, 18:20'),
        MedicalRecordTimelineEntry(
            label: "Pronto per l'invio", value: 'In attesa di nota'),
      ],
    ),
    MedicalRecordEntry(
      id: 'moka-controllo-peso',
      eventDate: DateTime(2026, 3, 12),
      category: RecordCategory.visit,
      petName: 'Moka',
      title: 'Nota clinica controllo peso',
      subtitle: 'Immagine - follow-up breve',
      meta: 'Archiviato il 12 marzo, utile come storico',
      badge: 'Archivio',
      detailSource: 'Ambulatorio San Marco',
      createdAt: '12 Mar 2026, 14:10',
      timeline: const [
        MedicalRecordTimelineEntry(label: 'Importato', value: '12 Mar 2026'),
        MedicalRecordTimelineEntry(
            label: 'Revisionato', value: '13 Mar 2026, 10:00'),
        MedicalRecordTimelineEntry(
            label: "Pronto per l'invio", value: 'Archiviato'),
      ],
    ),
    MedicalRecordEntry(
      id: 'oliver-dentale',
      eventDate: DateTime(2026, 3, 18),
      category: RecordCategory.visit,
      petName: 'Oliver',
      title: 'Controllo dentale di Oliver',
      subtitle: 'PDF - 3 pagine - ambulatorio di fiducia',
      meta: 'Utile per il follow-up dentale della prossima settimana',
      badge: 'In revisione',
      detailSource: 'Ambulatorio San Marco',
      createdAt: '18 Mar 2026, 11:20',
      timeline: const [
        MedicalRecordTimelineEntry(label: 'Importato', value: '18 Mar 2026'),
        MedicalRecordTimelineEntry(
            label: 'Revisionato', value: '18 Mar 2026, 12:05'),
        MedicalRecordTimelineEntry(
            label: "Pronto per l'invio", value: 'Da controllare'),
      ],
    ),
    MedicalRecordEntry(
      id: 'oliver-esami-sangue',
      eventDate: DateTime(2026, 3, 2),
      category: RecordCategory.exam,
      petName: 'Oliver',
      title: 'Esami del sangue di Oliver',
      subtitle: 'PDF - 2 pagine - profilo completo annuale',
      meta: 'Valori nella norma, archiviato come riferimento',
      badge: 'Archivio',
      detailSource: 'Laboratorio Vet',
      createdAt: '02 Mar 2026, 10:15',
      timeline: const [
        MedicalRecordTimelineEntry(label: 'Importato', value: '02 Mar 2026'),
        MedicalRecordTimelineEntry(
            label: 'Revisionato', value: '02 Mar 2026, 16:40'),
        MedicalRecordTimelineEntry(
            label: "Pronto per l'invio", value: 'Archiviato'),
      ],
    ),
  ];

  static void _upsertPreviewRecord(MedicalRecordEntry record) {
    final index = _previewRecords.indexWhere((item) => item.id == record.id);
    if (index == -1) {
      _previewRecords.insert(0, record);
      return;
    }

    _previewRecords[index] = record;
  }
}

/// A write to the server that did not happen. The message is shown to the owner.
class MedicalRecordSaveException implements Exception {
  const MedicalRecordSaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _legacyColumns =
    'id,pet_id,pet_name,title,subtitle,meta,badge,detail_source,created_at,attachment_id,event_date,event_type';
const _fullColumns = '$_legacyColumns,category,subtype,notes';

/// The rows, with the category columns when the table has them and without
/// when the schema script has not run yet, so the list never goes blank.
Future<List<dynamic>> _selectRows(SupabaseClient client) async {
  try {
    return await client.from('clinical_events').select(_fullColumns) as List<dynamic>;
  } catch (error) {
    if (!_isMissingColumn(error)) rethrow;
    return await client.from('clinical_events').select(_legacyColumns) as List<dynamic>;
  }
}

/// Postgres 42703 / PostgREST PGRST204: a column of the request is not in the table.
bool _isMissingColumn(Object error) =>
    error is PostgrestException && (error.code == '42703' || error.code == 'PGRST204');

/// One `clinical_events` row as an entry. The category is the `category` column
/// when the table has it, else the `event_type` the app also writes (any other
/// value, such as the old catch-all, is a document).
MedicalRecordEntry medicalRecordFromRow(Map<String, dynamic> row) {
  final storedCategory = row['category'] ?? row['event_type'];
  return MedicalRecordEntry(
    id: (row['id'] ?? '').toString(),
    petName: (row['pet_name'] ?? '').toString(),
    title: (row['title'] ?? appL10n.medicalDefaultRecordTitle).toString(),
    subtitle: (row['subtitle'] ?? '').toString(),
    meta: (row['meta'] ?? '').toString(),
    badge: (row['badge'] ?? '').toString(),
    detailSource: (row['detail_source'] ?? '').toString(),
    createdAt: formatStoredRecordDate(row['created_at']),
    attachmentId: row['attachment_id'] as String?,
    category: RecordCategory.fromKey(storedCategory),
    subtype: row['subtype'] as String?,
    eventDate: _parseDay(row['event_date']),
    notes: (row['notes'] ?? '').toString(),
    createdOn: DateTime.tryParse((row['created_at'] ?? '').toString())?.toLocal(),
    timeline: const [],
  );
}

/// A `date` column ("2026-03-12") as a local calendar day.
DateTime? _parseDay(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
}

String _isoDate(DateTime utc) =>
    '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';

/// Display text for a `created_at` timestamptz from the server, in local time.
/// Unparseable values are shown as they are rather than hidden.
String formatStoredRecordDate(Object? stored) {
  final text = stored?.toString() ?? '';
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return text;
  final local = parsed.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${appShortMonths()[local.month - 1]} ${local.year}, $hh:$mm';
}

/// Records saved this session, kept in memory. They are shown at once, and
/// stay visible even when the server read that follows is slow or fails.
final List<MedicalRecordEntry> _savedThisSession = [];

/// [recent] first (newest), then the server's records, without repeating an id.
/// For an id in both, the copy saved in this session wins: it is exactly what
/// the owner entered, while the server's row may lack the fields an older
/// schema cannot store (category, type, notes) and would bring them back as
/// "document" until the app is reopened.
List<MedicalRecordEntry> mergeRecentRecords(
  List<MedicalRecordEntry> fromServer,
  List<MedicalRecordEntry> recent,
) {
  final recentById = {for (final record in recent) record.id: record};
  final serverIds = fromServer.map((record) => record.id).toSet();
  return [
    ...recent.where((record) => !serverIds.contains(record.id)),
    for (final record in fromServer) recentById[record.id] ?? record,
  ];
}
