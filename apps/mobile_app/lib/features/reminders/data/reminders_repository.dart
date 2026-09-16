import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/config/app_runtime_config_loader.dart';

class ReminderEntry {
  const ReminderEntry({
    required this.id,
    required this.petName,
    required this.title,
    required this.subtitle,
    required this.due,
    required this.badge,
    required this.note,
    required this.schedule,
    this.dueAt,
  });

  final String id;
  final String petName;
  final String title;
  final String subtitle;
  final String due;
  final String badge;
  final String note;
  final String schedule;

  /// Real due date, used for date-based views (e.g. the Home agenda).
  /// Nullable because remote reminders may not have a `due_at` column yet.
  final DateTime? dueAt;
}

class RemindersRepository {
  RemindersRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<List<ReminderEntry>> loadReminders() async {
    final remote = await _tryLoadRemoteReminders();
    if (remote.isNotEmpty) {
      return remote;
    }
    return _previewReminders;
  }

  Future<ReminderEntry?> loadReminderById(String id) async {
    final reminders = await loadReminders();
    for (final reminder in reminders) {
      if (reminder.id == id) {
        return reminder;
      }
    }
    return reminders.isEmpty ? null : reminders.first;
  }

  Future<void> saveReminder(ReminderEntry reminder) async {
    final client = _resolveClient();
    if (client == null) {
      return;
    }

    await client.from('reminders').upsert({
      'id': reminder.id,
      'pet_name': reminder.petName,
      'title': reminder.title,
      'subtitle': reminder.subtitle,
      'due': reminder.due,
      'badge': reminder.badge,
      'note': reminder.note,
      'schedule': reminder.schedule,
      'due_at': reminder.dueAt?.toIso8601String(),
    });
  }

  Future<List<ReminderEntry>> _tryLoadRemoteReminders() async {
    final client = _resolveClient();
    if (client == null) {
      return const [];
    }

    try {
      final response = await client.from('reminders').select('*');
      final rows = response as List<dynamic>;
      return rows
          .map(
            (row) => ReminderEntry(
              id: (row['id'] ?? '').toString(),
              petName: (row['pet_name'] ?? '').toString(),
              title: (row['title'] ?? 'Promemoria').toString(),
              subtitle: (row['subtitle'] ?? 'Promemoria sincronizzato').toString(),
              due: (row['due'] ?? 'A breve').toString(),
              badge: (row['badge'] ?? 'Sincronizzato').toString(),
              note: (row['note'] ?? 'Fonte Supabase').toString(),
              schedule: (row['schedule'] ?? 'Una volta').toString(),
              dueAt: DateTime.tryParse((row['due_at'] ?? '').toString()),
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

  static final List<ReminderEntry> _previewReminders = [
    ReminderEntry(
      id: 'moka-antiparassitario',
      petName: 'Moka',
      title: 'Antiparassitario di Moka',
      subtitle: 'Ogni 30 giorni',
      due: 'Scade tra 3 giorni',
      badge: 'Prioritario',
      note: 'Notifica gia pronta per Francesco e collegata al profilo di Moka.',
      schedule: 'Ricorrente ogni 30 giorni',
      dueAt: DateTime.now().add(const Duration(days: 3)),
    ),
    ReminderEntry(
      id: 'moka-richiamo-vaccinale',
      petName: 'Moka',
      title: 'Richiamo vaccinale di Moka',
      subtitle: 'Ogni 12 mesi',
      due: 'Scade tra 12 giorni',
      badge: 'Programmato',
      note: 'Documento gia caricato in cartella per la prossima visita.',
      schedule: 'Ricorrente ogni 12 mesi',
      dueAt: DateTime.now().add(const Duration(days: 12)),
    ),
    ReminderEntry(
      id: 'moka-controllo-peso',
      petName: 'Moka',
      title: 'Controllo peso di Moka',
      subtitle: 'Promemoria manuale',
      due: 'Domani alle 11:30',
      badge: 'Vicino',
      note: 'Rivedi andamento, peso e note cliniche prima della chiamata.',
      schedule: 'Promemoria una tantum',
      dueAt: DateTime.now().add(const Duration(days: 1)),
    ),
    ReminderEntry(
      id: 'oliver-controllo-dentale',
      petName: 'Oliver',
      title: 'Controllo dentale di Oliver',
      subtitle: 'Promemoria manuale',
      due: 'La prossima settimana',
      badge: 'Programmato',
      note: 'Porta il libretto sanitario e conferma la disponibilita con la clinica.',
      schedule: 'Promemoria una tantum',
      dueAt: DateTime.now().add(const Duration(days: 7)),
    ),
    ReminderEntry(
      id: 'rex-controllo-uvb',
      petName: 'Rex',
      title: 'Controllo UVB terrario di Rex',
      subtitle: 'Ogni 6 mesi',
      due: 'Scade tra 3 giorni',
      badge: 'Prioritario',
      note: 'Verifica intensita della lampada UVB e temperatura del terrario.',
      schedule: 'Ricorrente ogni 6 mesi',
      dueAt: DateTime.now().add(const Duration(days: 3)),
    ),
    ReminderEntry(
      id: 'pico-becco-unghie',
      petName: 'Pico',
      title: 'Controllo becco e unghie di Pico',
      subtitle: 'Promemoria manuale',
      due: 'Tra un mese',
      badge: 'Programmato',
      note: 'Controllo di routine su becco, unghie e piumaggio.',
      schedule: 'Promemoria una tantum',
      dueAt: DateTime.now().add(const Duration(days: 30)),
    ),
  ];
}
