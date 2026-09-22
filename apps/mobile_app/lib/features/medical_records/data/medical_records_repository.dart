import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/config/app_runtime_config_loader.dart';

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

  final SupabaseClient? _client;

  Future<List<MedicalRecordEntry>> loadRecords() async {
    final remote = await _tryLoadRemoteRecords();
    if (remote.isNotEmpty) {
      return remote;
    }
    return _previewRecords;
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
      return;
    }

    try {
      await client.from('clinical_events').upsert({
        'id': record.id,
        'pet_name': record.petName,
        'title': record.title,
        'subtitle': record.subtitle,
        'meta': record.meta,
        'badge': record.badge,
        'detail_source': record.detailSource,
        'created_at': record.createdAt,
      });
    } catch (_) {
      _upsertPreviewRecord(record);
    }
  }

  Future<void> deleteRecord(String id) async {
    final client = _resolveClient();
    if (client == null) {
      _previewRecords.removeWhere((record) => record.id == id);
      return;
    }

    try {
      await client.from('clinical_events').delete().eq('id', id);
    } catch (_) {
      _previewRecords.removeWhere((record) => record.id == id);
    }
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

  Future<List<MedicalRecordEntry>> _tryLoadRemoteRecords() async {
    final client = _resolveClient();
    if (client == null) {
      return const [];
    }

    try {
      final response = await client.from('clinical_events').select('*');
      final rows = response as List<dynamic>;
      return rows
          .map(
            (row) => MedicalRecordEntry(
              id: (row['id'] ?? '').toString(),
              petName: (row['pet_name'] ?? 'Moka').toString(),
              title: (row['title'] ?? 'Referto clinico').toString(),
              subtitle:
                  (row['subtitle'] ?? 'Documento sincronizzato').toString(),
              meta: (row['meta'] ?? 'Sincronizzato da Supabase').toString(),
              badge: (row['badge'] ?? 'Sincronizzato').toString(),
              detailSource: (row['detail_source'] ?? 'Supabase').toString(),
              createdAt: (row['created_at'] ?? 'Adesso').toString(),
              timeline: const [
                MedicalRecordTimelineEntry(
                    label: 'Importato', value: 'Sincronizzato'),
                MedicalRecordTimelineEntry(
                    label: 'Revisionato', value: 'In attesa'),
                MedicalRecordTimelineEntry(
                    label: "Pronto per l'invio", value: 'Disponibile'),
              ],
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
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
