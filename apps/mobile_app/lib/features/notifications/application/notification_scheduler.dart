import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../shared/auth/current_user.dart';
import '../../auth/data/auth_repository_factory.dart';
import '../../dog_walks/data/dog_walks_repository.dart';
import '../../dog_walks/domain/walk_session.dart';
import '../../pets/data/pet_demo_store.dart';
import '../../pets/data/pet_photo_repository.dart';
import '../../pets/domain/pet_models.dart';
import '../../reminders/data/reminder_postponement_store.dart';
import '../../reminders/data/reminders_repository.dart';
import '../data/local_notifications_gateway.dart';
import '../data/notification_preferences_store.dart';
import '../domain/memory_notifications.dart';
import '../domain/notification_plan.dart';
import '../domain/notification_time_zone.dart';

/// Keeps the phone's scheduled notifications equal to the current plan:
/// every time reminders, pets, switches, sign-in or permission change, it
/// cancels what is pending and schedules [planNotifications] again whole.
/// Simpler than diffing, and a few dozen alarms take milliseconds.
class NotificationScheduler {
  NotificationScheduler({
    required LocalNotificationsGateway gateway,
    required Future<List<ReminderEntry>> Function() loadReminders,
    required Future<List<PetProfile>> Function() loadPets,
    required bool Function() isSignedIn,
    required Future<NotificationPreferences> Function() loadPreferences,
    Future<Map<String, List<MemoryWalk>>> Function(List<PetProfile> pets)? loadFavouriteWalks,
    Future<Map<String, List<DateTime>>> Function(List<PetProfile> pets)? loadPhotoDates,
    Future<Map<String, DateTime>> Function(List<ReminderEntry> reminders)? loadPostponements,
    DateTime Function()? now,
    this.debounce = const Duration(milliseconds: 400),
  })  : _gateway = gateway,
        _loadReminders = loadReminders,
        _loadPets = loadPets,
        _isSignedIn = isSignedIn,
        _loadPreferences = loadPreferences,
        _loadFavouriteWalks = loadFavouriteWalks ?? _noWalks,
        _loadPhotoDates = loadPhotoDates ?? _noPhotos,
        _loadPostponements = loadPostponements ?? _noPostponements,
        _now = now ?? notificationNow;

  static Future<Map<String, List<MemoryWalk>>> _noWalks(List<PetProfile> _) async => const {};
  static Future<Map<String, List<DateTime>>> _noPhotos(List<PetProfile> _) async => const {};
  static Future<Map<String, DateTime>> _noPostponements(List<ReminderEntry> _) async => const {};

  static NotificationScheduler? _instance;

  static NotificationScheduler get instance => _instance ??= NotificationScheduler(
        gateway: createPlatformNotificationsGateway(),
        loadReminders: () => RemindersRepository().loadReminders(),
        // Pets in Ricordi included: their reminders must be recognised to be
        // left out, and their memories planned (docs/product/17).
        loadPets: () async {
          await PetDemoStore.instance.ensureHydrated();
          return PetDemoStore.instance.list(includeMemorial: true);
        },
        loadFavouriteWalks: _favouriteWalksOfMemories,
        loadPhotoDates: _photoDatesOfMemories,
        loadPostponements: ReminderPostponementStore.instance.forReminders,
        isSignedIn: () => CurrentUser.get() != null,
        loadPreferences: () async {
          await NotificationPreferencesStore.instance.ensureLoaded();
          return NotificationPreferencesStore.instance.preferences;
        },
      );

  final LocalNotificationsGateway _gateway;
  final Future<List<ReminderEntry>> Function() _loadReminders;
  final Future<List<PetProfile>> Function() _loadPets;
  final bool Function() _isSignedIn;
  final Future<NotificationPreferences> Function() _loadPreferences;
  final Future<Map<String, List<MemoryWalk>>> Function(List<PetProfile> pets) _loadFavouriteWalks;
  final Future<Map<String, List<DateTime>>> Function(List<PetProfile> pets) _loadPhotoDates;
  final Future<Map<String, DateTime>> Function(List<ReminderEntry> reminders) _loadPostponements;

  /// Favourite walks of the pets in Ricordi whose walk memories are on. Read
  /// only when at least one is: nothing is fetched otherwise.
  static Future<Map<String, List<MemoryWalk>>> _favouriteWalksOfMemories(
    List<PetProfile> pets,
  ) async {
    final ids = {
      for (final pet in pets)
        if (pet.isMemorial && pet.memorialWalksReminder) pet.id,
    };
    final ownerId = CurrentUser.get()?.id;
    if (ids.isEmpty || ownerId == null) return const {};
    final walks = await DogWalksRepository().loadWalkSummaries(ownerId);
    final byPet = <String, List<MemoryWalk>>{};
    for (final walk in walks) {
      if (!ids.contains(walk.petId) || !walk.isFavorite) continue;
      if (walk.status != WalkStatus.completed) continue;
      byPet.putIfAbsent(walk.petId, () => []).add(
            MemoryWalk(id: walk.id, startedAt: walk.startedAt.toLocal()),
          );
    }
    return byPet;
  }

  /// Shooting dates of the photos of the pets in Ricordi whose "foto di
  /// questo giorno" is on. A photo without a shooting date is skipped: its
  /// upload day says nothing about the day it shows.
  static Future<Map<String, List<DateTime>>> _photoDatesOfMemories(
    List<PetProfile> pets,
  ) async {
    final byPet = <String, List<DateTime>>{};
    for (final pet in pets) {
      if (!pet.isMemorial || !pet.memorialPhotosReminder) continue;
      final photos = await PetPhotoRepository().list(pet.id);
      byPet[pet.id] = [
        for (final photo in photos)
          if (photo.takenAt != null) photo.takenAt!.toLocal(),
      ];
    }
    return byPet;
  }
  final DateTime Function() _now;
  final Duration debounce;

  Timer? _debounceTimer;
  Future<void> _queue = Future<void>.value();
  final List<void Function()> _stopListening = [];

  /// Starts following the app's data. Nothing happens where notifications
  /// aren't supported (web).
  void start() {
    if (_gateway is NoopNotificationsGateway || _stopListening.isNotEmpty) return;
    listenTo(Listenable.merge([
      RemindersRepository.changes,
      ReminderPostponementStore.instance,
      PetDemoStore.changes,
      DogWalksRepository.changes,
      NotificationPreferencesStore.instance,
    ]));
    final authSubscription =
        const AuthRepositoryFactory().create().watchContext().listen((context) {
      if (context.user == null) {
        unawaited(clearAll());
      } else {
        requestResync();
      }
    });
    // Back from the phone's settings the permissions may have changed (the
    // notifications', or the exact alarms': what was scheduled inexact is
    // scheduled again exact), and the 60-day window moves forward.
    final lifecycle = AppLifecycleListener(onResume: requestResync);
    _stopListening
      ..add(() => unawaited(authSubscription.cancel()))
      ..add(lifecycle.dispose);
    requestResync();
  }

  /// Re-plans after any tick of [triggers] (debounced: one save bumps
  /// several notifiers).
  void listenTo(Listenable triggers) {
    triggers.addListener(requestResync);
    _stopListening.add(() => triggers.removeListener(requestResync));
  }

  void stop() {
    _debounceTimer?.cancel();
    for (final stop in _stopListening) {
      stop();
    }
    _stopListening.clear();
  }

  void requestResync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => unawaited(resync()));
  }

  /// Runs after any resync already in progress, never alongside it.
  Future<void> resync() => _enqueue(_resync);

  /// A pet was just moved to Ricordi: its notifications already in the shade
  /// go away now, and the plan is rebuilt without it.
  Future<void> forgetPet(String petId) {
    requestResync();
    return _enqueue(() => _gateway.cancelShownForPet(petId));
  }

  /// Logout: removes every notification, scheduled or already shown.
  Future<void> clearAll() {
    _debounceTimer?.cancel();
    return _enqueue(_gateway.cancelAll);
  }

  Future<void> _enqueue(Future<void> Function() task) {
    final next = _queue.then((_) => task()).catchError((Object _) {
      // A failed platform call must not break the queue: the next change
      // re-plans everything anyway.
    });
    _queue = next;
    return next;
  }

  Future<void> _resync() async {
    if (!_isSignedIn()) {
      await _gateway.cancelAll();
      return;
    }
    if (!await _gateway.canNotify()) {
      await _gateway.cancelPending();
      return;
    }

    final pets = await _loadPets();
    // A memory source that cannot be read (offline) must not stop the rest.
    Future<Map<String, T>> orEmpty<T>(Future<Map<String, T>> Function() load) async {
      try {
        return await load();
      } catch (_) {
        return const {};
      }
    }

    final reminders = await _loadReminders();
    final plan = planNotifications(
      reminders: reminders,
      pets: pets,
      now: _now(),
      preferences: await _loadPreferences(),
      favouriteWalksByPet: await orEmpty(() => _loadFavouriteWalks(pets)),
      photoDatesByPet: await orEmpty(() => _loadPhotoDates(pets)),
      postponedUntilByReminder: await orEmpty(() => _loadPostponements(reminders)),
    );
    await _gateway.cancelPending();
    lastScheduleFailures = 0;
    for (var index = 0; index < plan.length; index++) {
      // One notification the system refuses must not drop the ones after it.
      try {
        await _gateway.schedule(index, plan[index]);
      } catch (error) {
        lastScheduleFailures++;
        lastScheduleError = error;
        debugPrint('Could not schedule notification ${plan[index]}: $error');
      }
    }
  }

  /// How many notifications of the last re-plan the system refused, and the
  /// last reason (null when it never happened). For diagnosis and tests.
  int lastScheduleFailures = 0;
  Object? lastScheduleError;
}
