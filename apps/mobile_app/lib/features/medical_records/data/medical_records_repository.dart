import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/auth/current_user.dart';
import '../../../../shared/config/app_runtime_config_loader.dart';
import '../../pets/data/pet_demo_store.dart';

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
      final response = await client.from('clinical_events').select(
          'id,pet_id,pet_name,title,subtitle,meta,badge,detail_source,created_at,attachment_id');
      final rows = response as List<dynamic>;
      final fromServer = rows
          .map(
            (row) => MedicalRecordEntry(
              id: (row['id'] ?? '').toString(),
              petName: (row['pet_name'] ?? '').toString(),
              title: (row['title'] ?? 'Referto clinico').toString(),
              subtitle: (row['subtitle'] ?? '').toString(),
              meta: (row['meta'] ?? '').toString(),
              badge: (row['badge'] ?? '').toString(),
              detailSource: (row['detail_source'] ?? '').toString(),
              createdAt: formatStoredRecordDate(row['created_at']),
              attachmentId: row['attachment_id'] as String?,
              timeline: const [],
            ),
          )
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
      throw const MedicalRecordSaveException(
        'Accesso non disponibile: riprova dopo aver effettuato di nuovo il login.',
      );
    }
    await PetDemoStore.instance.ensureHydrated();
    final petId = PetDemoStore.instance.byName(record.petName)?.id;
    if (petId == null) {
      throw MedicalRecordSaveException(
        'Il profilo di ${record.petName} non è sincronizzato sul server: sistemalo prima di caricare referti.',
      );
    }

    final now = DateTime.now().toUtc();
    try {
      await client.from('clinical_events').upsert({
        'id': record.id,
        'owner_id': ownerId,
        'pet_id': petId,
        'event_type': 'document',
        'event_date': _isoDate(now),
        'created_at': now.toIso8601String(),
        'title': record.title,
        'pet_name': record.petName,
        'subtitle': record.subtitle,
        'meta': record.meta,
        'badge': record.badge,
        'detail_source': record.detailSource,
        'attachment_id': record.attachmentId,
      });
    } catch (_) {
      throw const MedicalRecordSaveException(
        'Non sono riuscito a salvare il referto sul server. Controlla la connessione e riprova.',
      );
    }
    _savedThisSession.removeWhere((item) => item.id == record.id);
    _savedThisSession.add(record);
    changes.value++;
  }

  /// Changes only the title: the date and the file stay as they were.
  Future<void> renameRecord(MedicalRecordEntry record, String title) async {
    final client = _resolveClient();
    if (client == null) {
      final index = _previewRecords.indexWhere((item) => item.id == record.id);
      if (index != -1) _previewRecords[index] = _withTitle(record, title);
      changes.value++;
      return;
    }

    try {
      await client.from('clinical_events').update({'title': title}).eq('id', record.id);
    } catch (_) {
      throw const MedicalRecordSaveException(
        'Non sono riuscito a rinominare il referto. Riprova.',
      );
    }
    final sessionIndex = _savedThisSession.indexWhere((item) => item.id == record.id);
    if (sessionIndex != -1) _savedThisSession[sessionIndex] = _withTitle(record, title);
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
      throw const MedicalRecordSaveException(
        'Non sono riuscito a eliminare il referto. Riprova.',
      );
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
    const MedicalRecordEntry(
      id: 'moka-richiamo-vaccinale',
      petName: 'Moka',
      title: 'Richiamo vaccinale di Moka',
      subtitle: 'PDF - 2 pagine - Clinica Vet Roma',
      meta: 'Caricato oggi, pronto da mostrare a Francesco',
      badge: 'Da condividere',
      detailSource: 'Clinica Vet Roma',
      createdAt: '25 Mar 2026, 09:32',
      timeline: [
        MedicalRecordTimelineEntry(label: 'Importato', value: '25 Mar 2026'),
        MedicalRecordTimelineEntry(
            label: 'Revisionato', value: '25 Mar 2026, 09:45'),
        MedicalRecordTimelineEntry(
            label: "Pronto per l'invio", value: 'Disponibile'),
      ],
    ),
    const MedicalRecordEntry(
      id: 'moka-esame-ematico',
      petName: 'Moka',
      title: 'Esame ematico di Moka',
      subtitle: 'PDF - 4 pagine - controlli di routine',
      meta: 'Letto ieri, richiede un controllo rapido',
      badge: 'Da rivedere',
      detailSource: 'Laboratorio Vet',
      createdAt: '24 Mar 2026, 17:08',
      timeline: [
        MedicalRecordTimelineEntry(label: 'Importato', value: '24 Mar 2026'),
        MedicalRecordTimelineEntry(
            label: 'Revisionato', value: '24 Mar 2026, 18:20'),
        MedicalRecordTimelineEntry(
            label: "Pronto per l'invio", value: 'In attesa di nota'),
      ],
    ),
    const MedicalRecordEntry(
      id: 'moka-controllo-peso',
      petName: 'Moka',
      title: 'Nota clinica controllo peso',
      subtitle: 'Immagine - follow-up breve',
      meta: 'Archiviato il 12 marzo, utile come storico',
      badge: 'Archivio',
      detailSource: 'Ambulatorio San Marco',
      createdAt: '12 Mar 2026, 14:10',
      timeline: [
        MedicalRecordTimelineEntry(label: 'Importato', value: '12 Mar 2026'),
        MedicalRecordTimelineEntry(
            label: 'Revisionato', value: '13 Mar 2026, 10:00'),
        MedicalRecordTimelineEntry(
            label: "Pronto per l'invio", value: 'Archiviato'),
      ],
    ),
    const MedicalRecordEntry(
      id: 'oliver-dentale',
      petName: 'Oliver',
      title: 'Controllo dentale di Oliver',
      subtitle: 'PDF - 3 pagine - ambulatorio di fiducia',
      meta: 'Utile per il follow-up dentale della prossima settimana',
      badge: 'In revisione',
      detailSource: 'Ambulatorio San Marco',
      createdAt: '18 Mar 2026, 11:20',
      timeline: [
        MedicalRecordTimelineEntry(label: 'Importato', value: '18 Mar 2026'),
        MedicalRecordTimelineEntry(
            label: 'Revisionato', value: '18 Mar 2026, 12:05'),
        MedicalRecordTimelineEntry(
            label: "Pronto per l'invio", value: 'Da controllare'),
      ],
    ),
    const MedicalRecordEntry(
      id: 'oliver-esami-sangue',
      petName: 'Oliver',
      title: 'Esami del sangue di Oliver',
      subtitle: 'PDF - 2 pagine - profilo completo annuale',
      meta: 'Valori nella norma, archiviato come riferimento',
      badge: 'Archivio',
      detailSource: 'Laboratorio Vet',
      createdAt: '02 Mar 2026, 10:15',
      timeline: [
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

String _isoDate(DateTime utc) =>
    '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';

const _monthsIt = [
  'gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic',
];

/// Display text for a `created_at` timestamptz from the server, in local time.
/// Unparseable values are shown as they are rather than hidden.
String formatStoredRecordDate(Object? stored) {
  final text = stored?.toString() ?? '';
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return text;
  final local = parsed.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_monthsIt[local.month - 1]} ${local.year}, $hh:$mm';
}

/// Records saved this session, kept in memory. They are shown at once, and
/// stay visible even when the server read that follows is slow or fails.
final List<MedicalRecordEntry> _savedThisSession = [];

/// [recent] first (newest), then the server's records, without repeating an id.
List<MedicalRecordEntry> mergeRecentRecords(
  List<MedicalRecordEntry> fromServer,
  List<MedicalRecordEntry> recent,
) {
  final serverIds = fromServer.map((record) => record.id).toSet();
  return [
    ...recent.where((record) => !serverIds.contains(record.id)),
    ...fromServer,
  ];
}

MedicalRecordEntry _withTitle(MedicalRecordEntry record, String title) => MedicalRecordEntry(
      id: record.id,
      petName: record.petName,
      title: title,
      subtitle: record.subtitle,
      meta: record.meta,
      badge: record.badge,
      detailSource: record.detailSource,
      createdAt: record.createdAt,
      timeline: record.timeline,
      attachmentId: record.attachmentId,
    );
