import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

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
  return FlutterLocalNotificationsGateway();
}

/// Android, through flutter_local_notifications. Inexact alarms on purpose
/// (no SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM, see AndroidManifest.xml):
/// Android may deliver a few minutes late while the phone sleeps.
class FlutterLocalNotificationsGateway implements LocalNotificationsGateway {
  FlutterLocalNotificationsGateway({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initializing;

  Future<void> _ensureInitialized() {
    return _initializing ??= _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
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
  static const _channels = {
    NotificationCategory.reminders: (
      id: 'reminders',
      name: 'Promemoria',
      description: 'Visite, vaccini e altri promemoria',
    ),
    NotificationCategory.medicines: (
      id: 'medicines',
      name: 'Farmaci',
      description: 'Orari dei farmaci',
    ),
    NotificationCategory.birthdays: (
      id: 'birthdays',
      name: 'Compleanni',
      description: 'Compleanni degli animali',
    ),
  };
}
