import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/notifications/application/notification_scheduler.dart';
import 'package:vet_app_mobile/features/notifications/data/local_notifications_gateway.dart';
import 'package:vet_app_mobile/features/notifications/domain/notification_plan.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';

import 'notification_test_data.dart';

/// Stands in for the phone: keeps what is currently scheduled.
class FakeNotificationsGateway implements LocalNotificationsGateway {
  bool permission = true;
  final Map<int, PlannedNotification> scheduled = {};
  int cancelAllCalls = 0;

  @override
  Future<bool> canNotify() async => permission;

  @override
  Future<void> cancelPending() async => scheduled.clear();

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    scheduled.clear();
  }

  @override
  Future<void> schedule(int id, PlannedNotification notification) async {
    scheduled[id] = notification;
  }

  List<String> get titles => [for (final n in scheduled.values) n.title];
}

void main() {
  late FakeNotificationsGateway gateway;
  late List<ReminderEntry> reminders;
  late List<PetProfile> pets;
  late bool signedIn;
  late NotificationPreferences preferences;
  late NotificationScheduler scheduler;

  ReminderEntry visit(String id, String title, DateTime at) =>
      ReminderEntry(id: id, petName: 'Moka', title: title, kind: EventKind.spot, dueAt: at);

  setUp(() {
    gateway = FakeNotificationsGateway();
    reminders = [visit('r1', 'Vaccino', DateTime(2026, 10, 9, 9))];
    pets = [testPet('Moka', birth: '20 ott 2021')];
    signedIn = true;
    preferences = const NotificationPreferences();
    scheduler = NotificationScheduler(
      gateway: gateway,
      loadReminders: () async => reminders,
      loadPets: () async => pets,
      isSignedIn: () => signedIn,
      loadPreferences: () async => preferences,
      now: () => DateTime(2026, 10, 7, 10),
      debounce: Duration.zero,
    );
  });

  tearDown(() => scheduler.stop());

  test('schedules the whole plan', () async {
    await scheduler.resync();
    expect(gateway.titles, [
      'Domani: Vaccino',
      'Vaccino',
      'Compleanno in arrivo',
      'Buon compleanno, Moka!',
    ]);
  });

  test('an edited reminder replaces the old notifications', () async {
    await scheduler.resync();
    reminders = [visit('r1', 'Vaccino annuale', DateTime(2026, 10, 10, 11))];
    await scheduler.resync();
    expect(gateway.titles, contains('Vaccino annuale'));
    expect(gateway.titles, isNot(contains('Vaccino')));
    expect(gateway.scheduled.length, 4);
  });

  test('a deleted reminder or pet leaves nothing behind', () async {
    await scheduler.resync();
    reminders = [];
    pets = [];
    await scheduler.resync();
    expect(gateway.scheduled, isEmpty);
  });

  test('a change notifier tick re-plans on its own', () async {
    final changes = ValueNotifier<int>(0);
    scheduler.listenTo(changes);
    reminders = [visit('r2', 'Controllo peso', DateTime(2026, 10, 8, 17))];
    changes.value++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await scheduler.resync();
    expect(gateway.titles, contains('Controllo peso'));
  });

  test('switched-off category and missing permission', () async {
    preferences = const NotificationPreferences(birthdays: false);
    await scheduler.resync();
    expect(gateway.titles, ['Domani: Vaccino', 'Vaccino']);

    gateway.permission = false;
    await scheduler.resync();
    expect(gateway.scheduled, isEmpty);
  });

  test('logout clears everything; signed out schedules nothing', () async {
    await scheduler.resync();
    await scheduler.clearAll();
    expect(gateway.scheduled, isEmpty);
    expect(gateway.cancelAllCalls, 1);

    signedIn = false;
    await scheduler.resync();
    expect(gateway.scheduled, isEmpty);
  });

  test('web: the no-op gateway accepts every call silently', () async {
    const noop = NoopNotificationsGateway();
    expect(await noop.canNotify(), isFalse);
    await noop.cancelAll();
  });
}
