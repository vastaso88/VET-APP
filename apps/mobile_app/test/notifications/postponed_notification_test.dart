import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/features/notifications/application/notification_availability.dart';
import 'package:vet_app_mobile/features/notifications/application/notification_scheduler.dart';
import 'package:vet_app_mobile/features/notifications/data/local_notifications_gateway.dart';
import 'package:vet_app_mobile/features/notifications/domain/notification_plan.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/reminders/application/reminder_completion_service.dart';
import 'package:vet_app_mobile/features/reminders/data/reminder_postponement_store.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';

import 'notification_test_data.dart';

/// "Rimanda": the notification at the moment the owner chose.
final _now = DateTime(2026, 10, 21, 12);

ReminderEntry _vaccine({String id = 'r1', DateTime? due, bool done = false}) => ReminderEntry(
      id: id,
      petName: 'Moka',
      title: 'Vaccino',
      kind: EventKind.spot,
      dueAt: due ?? DateTime(2026, 10, 21, 9),
      isDone: done,
    );

List<PlannedNotification> _plan(
  ReminderEntry reminder,
  DateTime postponedTo, {
  NotificationPreferences preferences = const NotificationPreferences(),
  List<PetProfile>? pets,
}) =>
    planNotifications(
      reminders: [reminder],
      pets: pets ?? [testPet('Moka')],
      now: _now,
      preferences: preferences,
      postponedUntilByReminder: {reminder.id: postponedTo},
    );

class _Phone implements LocalNotificationsGateway {
  bool permission = true;
  final Map<int, PlannedNotification> scheduled = {};

  @override
  Future<bool> canNotify() async => permission;

  @override
  Future<void> cancelPending() async => scheduled.clear();

  @override
  Future<void> cancelAll() async => scheduled.clear();

  @override
  Future<void> cancelShownForPet(String petId) async {}

  @override
  Future<void> schedule(int id, PlannedNotification notification) async =>
      scheduled[id] = notification;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the plan', () {
    test('a postponed reminder rings at the chosen moment and asks "Fatto?" when tapped', () {
      final planned = _plan(_vaccine(), DateTime(2026, 10, 21, 13)).single;

      expect(planned.at, DateTime(2026, 10, 21, 13));
      expect(planned.title, 'Vaccino');
      expect(planned.body, 'Moka · mi avevi chiesto di ricordartelo ora');
      expect(planned.category, NotificationCategory.reminders);
      expect(planned.payload, 'reminder:r1');
      expect(planned.petId, 'pet-Moka');
    });

    test('its own notifications stay where they are: the date has not changed', () {
      final ahead = _vaccine(due: DateTime(2026, 10, 25, 9));
      expect([for (final n in _plan(ahead, DateTime(2026, 10, 21, 13))) n.at], [
        DateTime(2026, 10, 21, 13),
        DateTime(2026, 10, 24, 18),
        DateTime(2026, 10, 25, 9),
      ]);
    });

    test('nothing for a moment gone, a finished reminder or a pet in Ricordi', () {
      final later = DateTime(2026, 10, 21, 13);
      expect(_plan(_vaccine(), _now), isEmpty);
      expect(_plan(_vaccine(done: true), later), isEmpty);
      expect(_plan(_vaccine(), later, pets: [testPet('Moka', memorial: true)]), isEmpty);
    });

    test('a kind switched off in Impostazioni does not ring, a course follows the medicines', () {
      final later = DateTime(2026, 10, 21, 13);
      final course = ReminderEntry(
        id: 'c1',
        petName: 'Moka',
        title: 'Ciclo antibiotico',
        kind: EventKind.course,
        dueAt: DateTime(2026, 10, 14, 8),
        courseDurationDays: 7,
      );

      expect(_plan(_vaccine(), later, preferences: const NotificationPreferences(reminders: false)),
          isEmpty);
      expect(_plan(course, later).single.category, NotificationCategory.medicines);
      expect(_plan(course, later, preferences: const NotificationPreferences(medicines: false)),
          isEmpty);
      expect(_plan(course, later, preferences: const NotificationPreferences(reminders: false)),
          hasLength(1));
    });

    test('never twice in the same minute: a daily one already rings at its own hour', () {
      final daily = ReminderEntry(
        id: 'd1',
        petName: 'Moka',
        title: 'Controllo',
        kind: EventKind.recurring,
        dueAt: DateTime(2026, 10, 21, 9),
        intervalUnit: IntervalUnit.days,
        intervalValue: 1,
      );
      final tomorrow = DateTime(2026, 10, 22, 9);

      expect(_plan(daily, tomorrow).where((n) => n.at == tomorrow), hasLength(1));
      // ...nor not at all, when the plan is full long before that day.
      final farAhead = DateTime(2026, 12, 10, 9);
      final full = _plan(daily, farAhead);
      expect(full, hasLength(kMaxPlannedNotifications));
      expect(full.where((n) => n.at == farAhead), hasLength(1));
    });

    test('a moment far ahead is kept, beyond the horizon and however full the plan is', () {
      final far = DateTime(2027, 2, 1, 18, 30);
      final doses = ReminderEntry(
        id: 'doses',
        petName: 'Moka',
        title: 'Gocce',
        kind: EventKind.course,
        dueAt: DateTime(2026, 10, 21),
        courseDurationDays: 60,
        doseTimes: const ['08:00', '14:00', '20:00'],
      );
      final plan = planNotifications(
        reminders: [_vaccine(), doses],
        pets: [testPet('Moka')],
        now: _now,
        postponedUntilByReminder: {'r1': far},
      );

      expect(plan, hasLength(kMaxPlannedNotifications));
      expect(plan.last.at, far);
      expect(plan.last.payload, 'reminder:r1');
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].at.isBefore(plan[i - 1].at), isFalse);
      }
    });
  });

  group('the scheduler', () {
    late _Phone phone;
    late List<ReminderEntry> reminders;
    late NotificationScheduler scheduler;
    late ReminderCompletionService service;
    final store = ReminderPostponementStore.instance;

    setUp(() {
      phone = _Phone();
      reminders = [_vaccine()];
      service = ReminderCompletionService(now: () => _now);
      scheduler = NotificationScheduler(
        gateway: phone,
        loadReminders: () async => reminders,
        loadPets: () async => [testPet('Moka')],
        isSignedIn: () => true,
        loadPreferences: () async => const NotificationPreferences(),
        loadPostponements: store.forReminders,
        now: () => _now,
        debounce: Duration.zero,
      );
      addTearDown(scheduler.stop);
    });

    Future<void> settle() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await scheduler.resync();
    }

    test('"Rimanda" schedules it, and planning again does not lose it', () async {
      scheduler.listenTo(store);
      await service.postpone(reminders.single, DateTime(2026, 10, 21, 13));
      await settle();
      expect(phone.scheduled.values.single.at, DateTime(2026, 10, 21, 13));

      // Every return to the app cancels what is pending and plans again.
      await scheduler.resync();
      expect(phone.scheduled.values.single.at, DateTime(2026, 10, 21, 13));
    });

    test('a fresh start of the app (after a reboot, an update) schedules it again', () async {
      await service.postpone(reminders.single, DateTime(2026, 10, 21, 13));
      expect(phone.scheduled, isEmpty);

      await scheduler.resync();
      expect(phone.scheduled.values.single.payload, 'reminder:r1');
    });

    test('postponing again moves it; an answer takes it away', () async {
      scheduler.listenTo(store);
      await service.postpone(reminders.single, DateTime(2026, 10, 21, 13));
      await service.postpone(reminders.single, DateTime(2026, 10, 21, 19));
      await settle();
      expect(phone.scheduled.values.single.at, DateTime(2026, 10, 21, 19));

      await service.dismiss(reminders.single);
      await settle();
      expect(phone.scheduled, isEmpty);
    });

    test('signing out empties what was postponed and what was scheduled', () async {
      scheduler.listenTo(store);
      await service.postpone(reminders.single, DateTime(2026, 10, 21, 13));
      await settle();

      await store.clear();
      await scheduler.clearAll();
      await settle();
      expect(phone.scheduled, isEmpty);
    });

    test('without the permission nothing is scheduled; it is once allowed', () async {
      phone.permission = false;
      await service.postpone(reminders.single, DateTime(2026, 10, 21, 13));
      await scheduler.resync();
      expect(phone.scheduled, isEmpty);

      phone.permission = true;
      await scheduler.resync();
      expect(phone.scheduled, hasLength(1));
    });

    test('a store that cannot be read leaves the rest of the plan alone', () async {
      reminders = [_vaccine(due: DateTime(2026, 10, 25, 9))];
      final broken = NotificationScheduler(
        gateway: phone,
        loadReminders: () async => reminders,
        loadPets: () async => [testPet('Moka')],
        isSignedIn: () => true,
        loadPreferences: () async => const NotificationPreferences(),
        loadPostponements: (_) async => throw StateError('disk'),
        now: () => _now,
        debounce: Duration.zero,
      );
      await broken.resync();
      expect(phone.scheduled, hasLength(2));
      broken.stop();
    });
  });

  group('whether it can ring, for the line in the popup', () {
    NotificationAvailability availability({
      PermissionStatus status = PermissionStatus.granted,
      NotificationPreferences preferences = const NotificationPreferences(),
      bool android = true,
    }) =>
        NotificationAvailability(
          readStatus: () async => status,
          loadPreferences: () async => preferences,
          onEnabled: () {},
          isAndroid: android,
        );

    test('yes when allowed and switched on', () async {
      expect(await availability().canRing(NotificationCategory.reminders), isTrue);
    });

    test('no when the permission is missing', () async {
      for (final status in [PermissionStatus.denied, PermissionStatus.permanentlyDenied]) {
        expect(
            await availability(status: status).canRing(NotificationCategory.reminders), isFalse);
      }
    });

    test('no when that kind is switched off, and only that kind', () async {
      final off = availability(preferences: const NotificationPreferences(medicines: false));
      expect(await off.canRing(NotificationCategory.medicines), isFalse);
      expect(await off.canRing(NotificationCategory.reminders), isTrue);
    });

    test('no on web and iOS, where nothing is scheduled', () async {
      expect(await availability(android: false).canRing(NotificationCategory.reminders), isFalse);
    });

    test('no false alarm when it cannot be told', () async {
      final unknown = NotificationAvailability(
        readStatus: () async => throw StateError('no plugin'),
        loadPreferences: () async => const NotificationPreferences(),
        onEnabled: () {},
        isAndroid: true,
      );
      expect(await unknown.canRing(NotificationCategory.reminders), isTrue);
    });
  });
}
