import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../l10n/l10n.dart';
import '../application/notification_taps.dart';
import '../domain/notification_plan.dart';
import '../domain/notification_time_zone.dart';

/// What the scheduler needs from the phone's notification system — a seam
/// so tests can use a fake and the web build a no-op.
abstract class LocalNotificationsGateway {
  /// Whether notifications can be shown at all (OS permission granted).
  Future<bool> canNotify();

  /// Removes scheduled notifications not shown yet.
  Future<void> cancelPending();

  /// Removes scheduled ones and those already in the notification shade
  /// (logout: no pet names left on the screen).
  Future<void> cancelAll();

  Future<void> schedule(int id, PlannedNotification notification);
}

/// Web (and any platform without local notifications): nothing to schedule.
class NoopNotificationsGateway implements LocalNotificationsGateway {
  const NoopNotificationsGateway();

  @override
  Future<bool> canNotify() async => false;

  @override
  Future<void> cancelPending() async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule(int id, PlannedNotification notification) async {}
}

LocalNotificationsGateway createPlatformNotificationsGateway() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const NoopNotificationsGateway();
  }
  // Initialised at once, not at the first schedule: a tap on a notification
  // that launched the app must be seen even if nothing gets scheduled.
  return FlutterLocalNotificationsGateway()..ensureInitialized();
}

/// Android, through flutter_local_notifications. Inexact alarms on purpose
/// (no SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM, see AndroidManifest.xml):
/// Android may deliver a few minutes late while the phone sleeps.
class FlutterLocalNotificationsGateway implements LocalNotificationsGateway {
  FlutterLocalNotificationsGateway({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initializing;

  Future<void> ensureInitialized() => _ensureInitialized();

  Future<void> _ensureInitialized() {
    // A failed start-up is not kept: the next call tries again, instead of every
    // later schedule() reusing the same failure for the rest of the run.
    return _initializing ??= _initialize().catchError((Object error) {
      _initializing = null;
      throw error;
    });
  }

  Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          NotificationTaps.instance.add(response.payload),
    );
    // The tap that started the app (it was closed): the callback above only
    // covers taps while it runs. Best-effort: not being able to read it must
    // never stop notifications from being scheduled.
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        NotificationTaps.instance.add(launch!.notificationResponse?.payload);
      }
    } catch (error) {
      debugPrint('Notification launch details unavailable: $error');
    }
  }

  @override
  Future<bool> canNotify() async {
    try {
      return (await Permission.notification.status).isGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> cancelPending() async {
    await _ensureInitialized();
    await _plugin.cancelAllPendingNotifications();
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  @override
  Future<void> schedule(int id, PlannedNotification notification) async {
    await _ensureInitialized();
    final channel = _channels[notification.category]!;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: notificationInstant(notification.at),
      title: notification.title,
      body: notification.body,
      payload: notification.payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// One Android channel per category, so the owner can also silence one
  /// kind from the phone's own settings.
  static Map<NotificationCategory, ({String id, String name, String description})>
      get _channels {
    final l10n = appL10n;
    return {
      NotificationCategory.reminders: (
        id: 'reminders',
        name: l10n.notificationsChannelRemindersName,
        description: l10n.notificationsChannelRemindersDescription,
      ),
      NotificationCategory.medicines: (
        id: 'medicines',
        name: l10n.notificationsChannelMedicinesName,
        description: l10n.notificationsCategoryMedicines,
      ),
      NotificationCategory.birthdays: (
        id: 'birthdays',
        name: l10n.notificationsCategoryBirthdays,
        description: l10n.notificationsChannelBirthdaysDescription,
      ),
    };
  }
}
