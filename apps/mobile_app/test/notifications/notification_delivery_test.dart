import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:vet_app_mobile/features/notifications/application/notification_scheduler.dart';
import 'package:vet_app_mobile/features/notifications/data/local_notifications_gateway.dart';
import 'package:vet_app_mobile/features/notifications/domain/notification_plan.dart';
import 'package:vet_app_mobile/features/notifications/presentation/reminder_notification_permission.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

import 'notification_test_data.dart';

/// A plugin whose start-up and scheduling can be made to fail.
class _FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  int initializeFailures = 0;
  bool launchDetailsThrow = false;
  int initializeCalls = 0;
  final List<int> scheduledIds = [];
  final List<String?> payloads = [];
  Set<int> refusedIds = {};

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializeCalls++;
    if (initializeFailures > 0) {
      initializeFailures--;
      throw PlatformException(code: 'invalid_icon');
    }
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async {
    if (launchDetailsThrow) throw PlatformException(code: 'boom');
    return null;
  }

  @override
  Future<void> cancelAllPendingNotifications() async => scheduledIds.clear();

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (refusedIds.contains(id)) throw PlatformException(code: 'exact_alarms_not_permitted');
    scheduledIds.add(id);
    payloads.add(payload);
  }
}

class _FakeGateway implements LocalNotificationsGateway {
  final Set<int> refused = {};
  final List<int> scheduled = [];

  @override
  Future<bool> canNotify() async => true;

  @override
  Future<void> cancelPending() async => scheduled.clear();

  @override
  Future<void> cancelAll() async => scheduled.clear();

  @override
  Future<void> schedule(int id, PlannedNotification notification) async {
    if (refused.contains(id)) throw PlatformException(code: 'refused');
    scheduled.add(id);
  }
}

void main() {
  PlannedNotification notification({String? payload}) => PlannedNotification(
        at: DateTime(2026, 10, 22, 9),
        title: 'Vaccino',
        body: 'Moka',
        category: NotificationCategory.reminders,
        payload: payload,
      );

  group('the gateway', () {
    test('a failed start-up is retried by the next call, not remembered for the whole run',
        () async {
      final plugin = _FakePlugin()..initializeFailures = 1;
      final gateway = FlutterLocalNotificationsGateway(plugin: plugin);

      await expectLater(gateway.schedule(0, notification()), throwsA(isA<PlatformException>()));
      await gateway.schedule(1, notification(payload: 'reminder:abc'));

      expect(plugin.initializeCalls, 2);
      expect(plugin.scheduledIds, [1]);
      expect(plugin.payloads, ['reminder:abc']);
    });

    test('not being able to read the launching notification never stops scheduling', () async {
      final plugin = _FakePlugin()..launchDetailsThrow = true;
      final gateway = FlutterLocalNotificationsGateway(plugin: plugin);

      await gateway.schedule(0, notification());

      expect(plugin.scheduledIds, [0]);
    });
  });

  group('the scheduler', () {
    test('one notification the system refuses does not drop the rest', () async {
      final gateway = _FakeGateway()..refused.add(1);
      final scheduler = NotificationScheduler(
        gateway: gateway,
        loadReminders: () async => [
          for (var i = 0; i < 3; i++)
            ReminderEntry(
              id: 'r$i',
              petName: 'Moka',
              title: 'Visita $i',
              kind: EventKind.spot,
              dueAt: DateTime(2026, 10, 25 + i, 9),
            ),
        ],
        loadPets: () async => <PetProfile>[testPet('Moka')],
        isSignedIn: () => true,
        loadPreferences: () async => const NotificationPreferences(),
        now: () => DateTime(2026, 10, 22, 10),
        debounce: Duration.zero,
      );

      await scheduler.resync();

      // Two notifications per reminder: all but the refused one were scheduled.
      expect(gateway.scheduled.length, 5);
      expect(gateway.scheduled, isNot(contains(1)));
      expect(scheduler.lastScheduleFailures, 1);
      expect(scheduler.lastScheduleError, isA<PlatformException>());
      scheduler.stop();
    });
  });

  group('asking for the permission', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    /// Runs as Android; the override is lifted inside the test body, before the
    /// framework checks that no debug variable was left changed.
    void androidTest(String name, Future<void> Function(WidgetTester tester) body) {
      testWidgets(name, (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await body(tester);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    Future<BuildContext> pump(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            captured = context;
            return const Scaffold();
          }),
        ),
      );
      return captured;
    }

    androidTest('a phone that has not allowed notifications is asked, once the owner agrees',
        (tester) async {
      final context = await pump(tester);
      var requested = 0;
      var resynced = 0;

      final result = maybeAskReminderNotificationPermission(
        context,
        readStatus: () async => PermissionStatus.denied,
        request: () async {
          requested++;
          return PermissionStatus.granted;
        },
        onGranted: () => resynced++,
      );
      await tester.pumpAndSettle();
      expect(find.text('Vuoi ricevere gli avvisi?'), findsOneWidget);
      await tester.tap(find.text('Consenti'));
      await tester.pumpAndSettle();

      expect(await result, isTrue);
      expect(requested, 1);
      // The plan that could not be scheduled without the permission is rebuilt.
      expect(resynced, 1);
    });

    androidTest('"Non ora" does not trigger the system dialog', (tester) async {
      final context = await pump(tester);
      var requested = 0;

      final result = maybeAskReminderNotificationPermission(
        context,
        readStatus: () async => PermissionStatus.denied,
        request: () async {
          requested++;
          return PermissionStatus.granted;
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Non ora'));
      await tester.pumpAndSettle();

      expect(await result, isFalse);
      expect(requested, 0);
    });

    androidTest('already allowed, refused for good, or asked twice already: stays quiet',
        (tester) async {
      final context = await pump(tester);

      expect(
        await maybeAskReminderNotificationPermission(context,
            readStatus: () async => PermissionStatus.granted),
        isTrue,
      );
      expect(
        await maybeAskReminderNotificationPermission(context,
            readStatus: () async => PermissionStatus.permanentlyDenied),
        isFalse,
      );

      SharedPreferences.setMockInitialValues({
        'vet_app.reminder_notification_permission_asks': maxReminderPermissionAsks,
      });
      expect(
        await maybeAskReminderNotificationPermission(context,
            readStatus: () async => PermissionStatus.denied),
        isFalse,
      );
      await tester.pumpAndSettle();
      expect(find.text('Vuoi ricevere gli avvisi?'), findsNothing);
    });
  });
}
