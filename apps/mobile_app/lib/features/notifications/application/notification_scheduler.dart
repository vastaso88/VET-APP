import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../shared/auth/current_user.dart';
import '../../auth/data/auth_repository_factory.dart';
import '../../pets/data/pet_demo_store.dart';
import '../../pets/domain/pet_models.dart';
import '../../reminders/data/reminders_repository.dart';
import '../data/local_notifications_gateway.dart';
import '../data/notification_preferences_store.dart';
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
    DateTime Function()? now,
    this.debounce = const Duration(milliseconds: 400),
  })  : _gateway = gateway,
        _loadReminders = loadReminders,
        _loadPets = loadPets,
        _isSignedIn = isSignedIn,
        _loadPreferences = loadPreferences,
        _now = now ?? notificationNow;

  static NotificationScheduler? _instance;

  static NotificationScheduler get instance => _instance ??= NotificationScheduler(
        gateway: createPlatformNotificationsGateway(),
        loadReminders: () => RemindersRepository().loadReminders(),
        loadPets: () async {
          await PetDemoStore.instance.ensureHydrated();
          return PetDemoStore.instance.list();
        },
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
      PetDemoStore.changes,
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
    // Back from the phone's settings the permission may have changed, and
    // the 60-day window moves forward.
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

    final plan = planNotifications(
      reminders: await _loadReminders(),
      pets: await _loadPets(),
      now: _now(),
      preferences: await _loadPreferences(),
    );
    await _gateway.cancelPending();
    for (var index = 0; index < plan.length; index++) {
      await _gateway.schedule(index, plan[index]);
    }
  }
}
