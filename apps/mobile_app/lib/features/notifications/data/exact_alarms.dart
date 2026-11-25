import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android's "Alarms & reminders" access (SCHEDULE_EXACT_ALARM): without it the
/// system may deliver a notification up to an hour late. Always allowed below
/// Android 12; given by default on 12 and 13; the owner gives it in a system
/// screen from 14. Never throws: whatever cannot be read counts as "no", and the
/// notification is scheduled inexact.
class ExactAlarms {
  const ExactAlarms();

  Future<bool> allowed() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system screen and answers once the owner is back.
  Future<bool> request() async {
    try {
      return await _android?.requestExactAlarmsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    return FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  }
}
