import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/auth/current_user.dart';
import '../../../../shared/config/app_runtime_config_loader.dart';
import '../../pets/data/pet_demo_store.dart';

enum EventKind { spot, recurring, course }

enum IntervalUnit { days, months }

/// How a recurring reminder's series ends — open-ended by default, or
/// bounded by a total occurrence count or a final date.
enum RecurrenceEnd { never, afterOccurrences, onDate }

class ReminderEntry {
  const ReminderEntry({
    required this.id,
    required this.petName,
    required this.title,
    required this.kind,
    required this.dueAt,
    this.note = '',
    this.intervalUnit,
    this.intervalValue,
    this.recurrenceEnd,
    this.occurrenceCount,
    this.recurrenceEndDate,
    this.courseDurationDays,
    this.isDone = false,
  });

  final String id;
  final String petName;
  final String title;
  final EventKind kind;

  /// Next occurrence for spot/recurring, start date for course.
  final DateTime dueAt;
  final String note;

  /// Recurring only.
  final IntervalUnit? intervalUnit;
  final int? intervalValue;

  /// Recurring only — defaults to [RecurrenceEnd.never] when null.
  final RecurrenceEnd? recurrenceEnd;

  /// Recurring only, when [recurrenceEnd] is [RecurrenceEnd.afterOccurrences].
  final int? occurrenceCount;

  /// Recurring only, when [recurrenceEnd] is [RecurrenceEnd.onDate].
  final DateTime? recurrenceEndDate;

  /// Course only.
  final int? courseDurationDays;

  final bool isDone;

  ReminderEntry copyWith({bool? isDone}) {
    return ReminderEntry(
      id: id,
      petName: petName,
      title: title,
      kind: kind,
      dueAt: dueAt,
      note: note,
      intervalUnit: intervalUnit,
      intervalValue: intervalValue,
      recurrenceEnd: recurrenceEnd,
      occurrenceCount: occurrenceCount,
      recurrenceEndDate: recurrenceEndDate,
      courseDurationDays: courseDurationDays,
      isDone: isDone ?? this.isDone,
    );
  }
}

class RemindersRepository {
  RemindersRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  /// Session-lifetime local store: `_seedReminders` only while nobody is
  /// signed in (offline/demo preview); once a real owner is known,
  /// [ensureHydrated] replaces this with that owner's real (possibly empty)
  /// reminders, so a brand-new account never inherits Moka/Oliver/Rex's
  /// demo activities — same pattern as PetDemoStore.ensureHydrated.
  static List<ReminderEntry> _localReminders =
      List<ReminderEntry>.of(_seedReminders);

  /// Owner id this store's contents were hydrated for — see
  /// PetDemoStore.ensureHydrated for the same no-op-on-repeat rationale.
  static String? _hydratedOwnerId;

  /// Ticks on every mutation (save/delete) and every completed hydration,
  /// so any screen showing reminders — the list, a pet's tab, Home's
  /// calendar — can rebuild itself the moment the shared data changes,
  /// instead of each keeping its own one-shot Future that only a manual
  /// "did you just come back from that screen?" reload ever refreshes.
  /// Screens that stay alive under the bottom-nav IndexedStack (Home,
  /// Attività) never get that manual-reload trigger on their own, which is
  /// why Home's calendar previously never picked up a reminder created
  /// elsewhere.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

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
      final response =
          await client.from('reminders').select('*').eq('owner_id', ownerId);
      final rows = response as List<dynamic>;
      final loaded = <ReminderEntry>[];
      for (final row in rows) {
        final entry = _parseRow(row as Map<String, dynamic>);
        if (entry != null) {
          loaded.add(entry);
        }
      }
      _localReminders = loaded;
      _hydratedOwnerId = ownerId;
      changes.value++;
    } catch (_) {
      // Leave current contents in place; retried next call since
      // _hydratedOwnerId wasn't set.
    }
  }

  Future<List<ReminderEntry>> loadReminders() async {
    await ensureHydrated();
    return List<ReminderEntry>.unmodifiable(_localReminders);
  }

  Future<ReminderEntry?> loadReminderById(String id) async {
    final reminders = await loadReminders();
    for (final reminder in reminders) {
      if (reminder.id == id) {
        return reminder;
      }
    }
    return null;
  }

  Future<void> saveReminder(ReminderEntry reminder) async {
    final index = _localReminders.indexWhere((r) => r.id == reminder.id);
    if (index == -1) {
      _localReminders.insert(0, reminder);
    } else {
      _localReminders[index] = reminder;
    }
    changes.value++;

    final client = _resolveClient();
    if (client == null) {
      return;
    }

    final ownerId = CurrentUser.get()?.id;
    if (ownerId == null) {
      return;
    }

    // reminders.pet_id is a required FK to pet_profiles (and RLS checks the
    // referenced pet's owner_id) — a reminder whose pet name doesn't
    // resolve to a real pet can't be written remotely at all, so it stays
    // local-only rather than sending a row that would fail the FK/RLS.
    await PetDemoStore.instance.ensureHydrated();
    final petId = PetDemoStore.instance.byName(reminder.petName)?.id;
    if (petId == null) {
      return;
    }

    try {
      await client.from('reminders').upsert({
        'id': reminder.id,
        'owner_id': ownerId,
        'pet_id': petId,
        'pet_name': reminder.petName,
        'title': reminder.title,
        'due_date': _dateOnly(reminder.dueAt),
        'notes': reminder.note,
        'kind': reminder.kind.name,
        'due_at': reminder.dueAt.toIso8601String(),
        'interval_unit': reminder.intervalUnit?.name,
        'interval_value': reminder.intervalValue,
        'recurrence_end': reminder.recurrenceEnd?.name,
        'occurrence_count': reminder.occurrenceCount,
        'recurrence_end_date': reminder.recurrenceEndDate?.toIso8601String(),
        'course_duration_days': reminder.courseDurationDays,
        'is_done': reminder.isDone,
      });
    } catch (_) {
      // Kept locally regardless — same best-effort-remote pattern as
      // deleteReminder below.
    }
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> deleteReminder(String id) async {
    _localReminders.removeWhere((r) => r.id == id);
    changes.value++;

    final client = _resolveClient();
    if (client == null) {
      return;
    }

    try {
      await client.from('reminders').delete().eq('id', id);
    } catch (_) {
      // Removed locally regardless — same best-effort-remote pattern as
      // the rest of this demo repository.
    }
  }

  /// Defensive parsing: `kind` and `due_at` are now required fields, so a
  /// row missing or with an unparsable value for either is skipped rather
  /// than risking a crash or a fabricated default.
  ReminderEntry? _parseRow(Map<String, dynamic> row) {
    final dueAt = DateTime.tryParse((row['due_at'] ?? '').toString());
    final kind = _kindFromName(row['kind'] as String?);
    if (dueAt == null || kind == null) {
      return null;
    }

    return ReminderEntry(
      id: (row['id'] ?? '').toString(),
      petName: (row['pet_name'] ?? '').toString(),
      title: (row['title'] ?? 'Promemoria').toString(),
      kind: kind,
      dueAt: dueAt,
      note: (row['notes'] ?? '').toString(),
      intervalUnit: _unitFromName(row['interval_unit'] as String?),
      intervalValue: row['interval_value'] as int?,
      recurrenceEnd: _recurrenceEndFromName(row['recurrence_end'] as String?),
      occurrenceCount: row['occurrence_count'] as int?,
      recurrenceEndDate:
          DateTime.tryParse((row['recurrence_end_date'] ?? '').toString()),
      courseDurationDays: row['course_duration_days'] as int?,
      isDone: row['is_done'] as bool? ?? false,
    );
  }

  static EventKind? _kindFromName(String? name) {
    for (final kind in EventKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  static IntervalUnit? _unitFromName(String? name) {
    for (final unit in IntervalUnit.values) {
      if (unit.name == name) return unit;
    }
    return null;
  }

  static RecurrenceEnd? _recurrenceEndFromName(String? name) {
    for (final end in RecurrenceEnd.values) {
      if (end.name == name) return end;
    }
    return null;
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

  static final List<ReminderEntry> _seedReminders = [
    ReminderEntry(
      id: 'moka-antiparassitario',
      petName: 'Moka',
      title: 'Antiparassitario di Moka',
      kind: EventKind.recurring,
      dueAt: DateTime.now().add(const Duration(days: 3)),
      intervalUnit: IntervalUnit.days,
      intervalValue: 30,
      recurrenceEnd: RecurrenceEnd.afterOccurrences,
      occurrenceCount: 6,
      note: 'Notifica già pronta per Francesco e collegata al profilo di Moka.',
    ),
    ReminderEntry(
      id: 'moka-richiamo-vaccinale',
      petName: 'Moka',
      title: 'Richiamo vaccinale di Moka',
      kind: EventKind.recurring,
      dueAt: DateTime.now().add(const Duration(days: 12)),
      intervalUnit: IntervalUnit.months,
      intervalValue: 12,
      recurrenceEnd: RecurrenceEnd.onDate,
      recurrenceEndDate: DateTime.now().add(const Duration(days: 365 * 3)),
      note: 'Documento già caricato in cartella per la prossima visita.',
    ),
    ReminderEntry(
      id: 'moka-controllo-peso',
      petName: 'Moka',
      title: 'Controllo peso di Moka',
      kind: EventKind.spot,
      dueAt: DateTime.now().add(const Duration(days: 1)),
      note: 'Rivedi andamento, peso e note cliniche prima della chiamata.',
    ),
    ReminderEntry(
      id: 'moka-ciclo-antibiotico',
      petName: 'Moka',
      title: 'Ciclo antibiotico di Moka',
      kind: EventKind.course,
      dueAt: DateTime.now().subtract(const Duration(days: 2)),
      courseDurationDays: 7,
      note: 'Una compressa mattina e sera, insieme al cibo.',
    ),
    ReminderEntry(
      id: 'oliver-controllo-dentale',
      petName: 'Oliver',
      title: 'Controllo dentale di Oliver',
      kind: EventKind.spot,
      dueAt: DateTime.now().add(const Duration(days: 7)),
      note:
          'Porta il libretto sanitario e conferma la disponibilità con la clinica.',
    ),
    ReminderEntry(
      id: 'rex-controllo-uvb',
      petName: 'Rex',
      title: 'Controllo UVB terrario di Rex',
      kind: EventKind.recurring,
      dueAt: DateTime.now().add(const Duration(days: 3)),
      intervalUnit: IntervalUnit.months,
      intervalValue: 6,
      note: 'Verifica intensità della lampada UVB e temperatura del terrario.',
    ),
    ReminderEntry(
      id: 'pico-becco-unghie',
      petName: 'Pico',
      title: 'Controllo becco e unghie di Pico',
      kind: EventKind.spot,
      dueAt: DateTime.now().add(const Duration(days: 30)),
      note: 'Controllo di routine su becco, unghie e piumaggio.',
    ),
  ];
}
