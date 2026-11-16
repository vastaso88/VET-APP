import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../app/router/app_router.dart';
import '../../pets/data/pet_demo_store.dart';
import '../../pets/domain/pet_models.dart';
import '../application/reminder_completion_service.dart';
import '../data/reminders_repository.dart';
import '../domain/memorial_reminders.dart';
import '../domain/reminder_completion.dart';
import 'widgets/reminder_completion_sheet.dart';

/// Asks "Fatto? Registralo nello storico" on its own: for clinical reminders
/// that have just fallen due (when the app opens or comes back) and for the
/// reminder whose notification the owner tapped. One question at a time; each
/// reminder at most once per run unless the owner postponed it.
class ReminderCompletionPrompter {
  ReminderCompletionPrompter({
    RemindersRepository? repository,
    ReminderCompletionService? service,
    DateTime Function()? now,
    BuildContext? Function()? contextProvider,
    Future<bool> Function(ReminderEntry reminder)? ask,
    Future<List<PetProfile>> Function()? loadPets,
  })  : _repository = repository ?? RemindersRepository(),
        _loadPets = loadPets ?? _allPets,
        _service = service ?? ReminderCompletionService(),
        _now = now ?? DateTime.now,
        _context = contextProvider ?? (() => AppRouter.navigatorKey.currentContext),
        _ask = ask;

  static final ReminderCompletionPrompter instance = ReminderCompletionPrompter();

  /// Most automatic questions in one go: a phone left for a week must not open
  /// with a queue of sheets.
  static const maxAutoPrompts = 2;

  final RemindersRepository _repository;
  final ReminderCompletionService _service;
  final DateTime Function() _now;
  final BuildContext? Function() _context;
  /// Replaces the real sheet (tests).
  final Future<bool> Function(ReminderEntry reminder)? _ask;

  /// Every pet, those in Ricordi included: their reminders are never asked
  /// about (docs/product/17_ricordi_animali.md §4).
  final Future<List<PetProfile>> Function() _loadPets;

  static Future<List<PetProfile>> _allPets() async {
    await PetDemoStore.instance.ensureHydrated();
    return PetDemoStore.instance.list(includeMemorial: true);
  }

  Future<List<ReminderEntry>> _remindersToAsk() async =>
      remindersOfActivePets(await _repository.loadReminders(), await _loadPets());

  bool get _canAsk => _ask != null || (_context()?.mounted ?? false);

  Future<bool> _askAbout(ReminderEntry reminder) {
    final override = _ask;
    if (override != null) return override(reminder);
    return askToCompleteReminder(_context()!, reminder, service: _service);
  }

  bool _busy = false;
  final Set<String> _askedThisRun = {};

  /// Asks about the clinical reminders that fell due and were not answered.
  Future<void> checkDue() async {
    if (_busy) return;
    _busy = true;
    try {
      final reminders = await _remindersToAsk();
      var asked = 0;
      for (final reminder in reminders) {
        if (asked >= maxAutoPrompts) break;
        final now = _now();
        final key = completedRecordId(reminder);
        if (_askedThisRun.contains(key)) continue;
        final postponedUntil = await _service.postponedUntil(reminder);
        if (!shouldAutoPrompt(reminder, now, snoozedUntil: postponedUntil)) continue;
        if (!_canAsk) return;
        _askedThisRun.add(key);
        asked++;
        await _askAbout(reminder);
      }
    } catch (_) {
      // Best-effort: the list still offers "Fatto?" on every reminder.
    } finally {
      _busy = false;
    }
  }

  /// The owner tapped the notification of [reminderId]: asks about it, even if
  /// it is not due yet or was postponed (they are looking at it right now).
  Future<void> promptFor(String reminderId) async {
    if (_busy) return;
    _busy = true;
    try {
      final reminders = await _remindersToAsk();
      final matches = reminders.where((r) => r.id == reminderId && !r.isDone);
      if (matches.isEmpty) return;
      if (!_canAsk) return;
      final reminder = matches.first;
      _askedThisRun.add(completedRecordId(reminder));
      await _askAbout(reminder);
    } catch (_) {
      // The reminder is still in the list.
    } finally {
      _busy = false;
    }
  }
}
