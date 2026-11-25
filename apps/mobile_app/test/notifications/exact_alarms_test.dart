import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:vet_app_mobile/features/notifications/application/notification_scheduler.dart';
import 'package:vet_app_mobile/features/notifications/data/exact_alarms.dart';
import 'package:vet_app_mobile/features/notifications/data/local_notifications_gateway.dart';
import 'package:vet_app_mobile/features/notifications/domain/notification_plan.dart';
import 'package:vet_app_mobile/features/notifications/presentation/exact_alarm_permission.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

import 'notification_test_data.dart';

/// The access to exact alarms, in the test's hands.
class _Access extends ExactAlarms {
  _Access({this.on = false, this.afterRequest = false, this.requestThrows = false});

  bool on;
  bool afterRequest;
  bool requestThrows;
  int requests = 0;

  @override
  Future<bool> allowed() async => on;

  @override
  Future<bool> request() async {
    requests++;
    if (requestThrows) throw PlatformException(code: 'no screen');
    on = afterRequest;
    return afterRequest;
  }
}

/// Keeps how each notification was scheduled.
class _Plugin extends Fake implements FlutterLocalNotificationsPlugin {
  final Map<int, AndroidScheduleMode> modes = {};
  final Map<int, String?> titles = {};

  /// The system refuses exact alarms whatever the check said.
  bool refuseExact = false;
  bool refuseAll = false;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async =>
      true;

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async => null;

  @override
  Future<void> cancelAllPendingNotifications() async {
    modes.clear();
    titles.clear();
  }

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
    if (refuseAll) throw PlatformException(code: 'invalid_icon');
    if (refuseExact && androidScheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
      throw PlatformException(code: 'exact_alarms_not_permitted');
    }
    modes[id] = androidScheduleMode;
    titles[id] = title;
  }
}

class _AllowedGateway extends FlutterLocalNotificationsGateway {
  _AllowedGateway({super.plugin, super.exactAlarms});

  @override
  Future<bool> canNotify() async => true;
}

PlannedNotification _notification(NotificationCategory category) => PlannedNotification(
      at: DateTime(2026, 10, 22, 9),
      title: 'Vaccino',
      body: 'Moka',
      category: category,
    );

const _exact = AndroidScheduleMode.exactAllowWhileIdle;
const _inexact = AndroidScheduleMode.inexactAllowWhileIdle;

void main() {
  group('how a notification is scheduled', () {
    Future<AndroidScheduleMode?> mode(
      NotificationCategory category, {
      required bool access,
      bool refuseExact = false,
    }) async {
      final plugin = _Plugin()..refuseExact = refuseExact;
      final gateway =
          FlutterLocalNotificationsGateway(plugin: plugin, exactAlarms: _Access(on: access));
      await gateway.schedule(0, _notification(category));
      return plugin.modes[0];
    }

    test('with the access, what has an hour of the owner\'s is exact', () async {
      expect(await mode(NotificationCategory.reminders, access: true), _exact);
      expect(await mode(NotificationCategory.medicines, access: true), _exact);
    });

    test('birthdays and memories have an hour of the app\'s: never exact', () async {
      expect(await mode(NotificationCategory.birthdays, access: true), _inexact);
      expect(await mode(NotificationCategory.memories, access: true), _inexact);
    });

    test('without the access everything is inexact, nothing fails', () async {
      for (final category in NotificationCategory.values) {
        expect(await mode(category, access: false), _inexact, reason: category.name);
      }
    });

    test('access taken back between the check and the call: inexact, not lost', () async {
      expect(await mode(NotificationCategory.reminders, access: true, refuseExact: true), _inexact);
    });

    test('any other refusal is still reported', () async {
      final gateway = FlutterLocalNotificationsGateway(
        plugin: _Plugin()..refuseAll = true,
        exactAlarms: _Access(on: true),
      );
      await expectLater(
        gateway.schedule(0, _notification(NotificationCategory.reminders)),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'invalid_icon')),
      );
    });

    test('when the access arrives (or goes) what was scheduled is scheduled again', () async {
      final access = _Access();
      final plugin = _Plugin();
      final scheduler = NotificationScheduler(
        gateway: _AllowedGateway(plugin: plugin, exactAlarms: access),
        loadReminders: () async => [
          ReminderEntry(
            id: 'r1',
            petName: 'Moka',
            title: 'Vaccino',
            kind: EventKind.spot,
            dueAt: DateTime(2026, 10, 25, 9),
          ),
        ],
        loadPets: () async => [testPet('Moka', birth: '20 nov 2021')],
        isSignedIn: () => true,
        loadPreferences: () async => const NotificationPreferences(),
        now: () => DateTime(2026, 10, 22, 10),
        debounce: Duration.zero,
      );
      addTearDown(scheduler.stop);
      Map<String?, AndroidScheduleMode> byTitle() =>
          {for (final id in plugin.modes.keys) plugin.titles[id]: plugin.modes[id]!};

      await scheduler.resync();
      expect(byTitle().values.toSet(), {_inexact});

      // Back from the system screen, the app plans again (onResume).
      access.on = true;
      await scheduler.resync();
      expect(byTitle()['Vaccino'], _exact);
      expect(byTitle()['Domani: Vaccino'], _exact);
      expect(byTitle()['Buon compleanno, Moka!'], _inexact);

      access.on = false;
      await scheduler.resync();
      expect(byTitle()['Vaccino'], _inexact);
      expect(scheduler.lastScheduleFailures, 0);
    });
  });

  group('reading and asking for the access (plugin)', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <String>[];

    void phoneAnswers(Object? Function(String method) answer) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return answer(call.method);
      });
    }

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('asks Android, through the plugin', () async {
      phoneAnswers((_) => true);
      expect(await const ExactAlarms().allowed(), isTrue);
      expect(await const ExactAlarms().request(), isTrue);
      expect(calls, ['canScheduleExactNotifications', 'requestExactAlarmsPermission']);
    });

    test('no, no answer and an error all count as no', () async {
      phoneAnswers((_) => false);
      expect(await const ExactAlarms().allowed(), isFalse);
      phoneAnswers((_) => null);
      expect(await const ExactAlarms().allowed(), isFalse);
      expect(await const ExactAlarms().request(), isFalse);
      phoneAnswers((_) => throw PlatformException(code: 'error'));
      expect(await const ExactAlarms().allowed(), isFalse);
      expect(await const ExactAlarms().request(), isFalse);
    });

    test('never on iOS', () async {
      phoneAnswers((_) => true);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await const ExactAlarms().allowed(), isFalse);
      expect(await const ExactAlarms().request(), isFalse);
      expect(calls, isEmpty);
    });
  });

  group('the one question', () {
    const title = "Vuoi gli avvisi all'ora esatta?";
    late BuildContext context;
    late int replans;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      replans = 0;
    });

    void onPhone(
      String name,
      Future<void> Function(WidgetTester tester) body, {
      TargetPlatform platform = TargetPlatform.android,
    }) {
      testWidgets(name, (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('it'),
              home: Builder(builder: (c) {
                context = c;
                return const Scaffold();
              }),
            ),
          );
          await body(tester);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    Future<bool> ask(
      _Access access, {
      PermissionStatus notifications = PermissionStatus.granted,
    }) =>
        maybeAskExactAlarmPermission(
          context,
          exactAlarms: access,
          readNotificationStatus: () async => notifications,
          onGranted: () => replans++,
        );

    onPhone('says why in one sentence, opens the system screen, then plans again', (tester) async {
      final access = _Access(afterRequest: true);
      final answer = ask(access);
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(find.textContaining("esattamente all'ora che scegli"), findsOneWidget);
      expect(find.textContaining('arrivano lo stesso'), findsOneWidget);
      expect(access.requests, 0);

      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();
      expect(await answer, isTrue);
      expect(access.requests, 1);
      expect(replans, 1);
    });

    onPhone('"Non ora": no system screen, and never asked again', (tester) async {
      final access = _Access(afterRequest: true);
      final answer = ask(access);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Non ora'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
      expect(access.requests, 0);

      expect(await ask(access), isFalse);
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
      expect(replans, 0);
    });

    onPhone('closed without an answer counts as asked', (tester) async {
      final access = _Access();
      final answer = ask(access);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);

      expect(await ask(access), isFalse);
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
    });

    onPhone('refused in the system screen: no error, nothing planned again, not asked again',
        (tester) async {
      final access = _Access();
      final answer = ask(access);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
      expect(replans, 0);

      expect(await ask(access), isFalse);
      await tester.pumpAndSettle();
      expect(access.requests, 1);
    });

    onPhone('a phone without that screen is no error', (tester) async {
      final answer = ask(_Access(requestThrows: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
      expect(tester.takeException(), isNull);
    });

    onPhone('quiet when the access is there already (Android 13 and before)', (tester) async {
      expect(await ask(_Access(on: true)), isTrue);
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
    });

    onPhone('waits while notifications are off, without using up the question', (tester) async {
      final access = _Access();
      expect(await ask(access, notifications: PermissionStatus.denied), isFalse);
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);

      final answer = ask(access);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text('Non ora'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
    });

    onPhone('after signing out the next account gets its own explanation', (tester) async {
      final access = _Access();
      var answer = ask(access);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Non ora'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);

      await forgetExactAlarmAsk();
      answer = ask(access);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text('Non ora'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
    });

    onPhone('never on iOS', (tester) async {
      final access = _Access(on: false, afterRequest: true);
      expect(await ask(access), isFalse);
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
      expect(access.requests, 0);
    }, platform: TargetPlatform.iOS);

    test('a reminder with an hour: all but a course without dose times', () {
      ReminderEntry of(EventKind kind, {List<String> doses = const []}) => ReminderEntry(
            id: 'r',
            petName: 'Moka',
            title: 'Vaccino',
            kind: kind,
            dueAt: DateTime(2026, 10, 25, 9),
            doseTimes: doses,
          );
      expect(reminderHasChosenTime(of(EventKind.spot)), isTrue);
      expect(reminderHasChosenTime(of(EventKind.recurring)), isTrue);
      expect(reminderHasChosenTime(of(EventKind.course, doses: ['08:00'])), isTrue);
      expect(reminderHasChosenTime(of(EventKind.course)), isFalse);
    });
  });

  test('the manifest asks for SCHEDULE_EXACT_ALARM, not the one reserved to alarm clocks', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest,
        contains('<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />'));
    expect(manifest, isNot(contains('android.permission.USE_EXACT_ALARM')));
  });
}
