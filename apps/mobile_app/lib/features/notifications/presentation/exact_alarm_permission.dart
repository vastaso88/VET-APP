import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/permissions/permission_explainer.dart';
import '../../reminders/data/reminders_repository.dart';
import '../application/notification_scheduler.dart';
import '../data/exact_alarms.dart';
import 'reminder_notification_permission.dart';

const _askedKey = 'vet_app.exact_alarm_permission_asked';

/// Whether the owner gave [reminder] an hour: always, except a course with no
/// dose times (a notification a day, at the app's own hour).
bool reminderHasChosenTime(ReminderEntry reminder) =>
    reminder.kind != EventKind.course || reminder.doseTimes.isNotEmpty;

/// A reminder must ring exactly at the hour the owner chose, but from Android 14
/// the access to exact alarms is off until they give it. So the first time they
/// choose an hour this says why, in one sentence, and opens the system screen.
///
/// Asked ONCE (until sign-out), whatever the answer: "no" leaves the reminders
/// inexact, nothing is blocked and nothing is asked at every reminder. Quiet when
/// the access is there already, and when notifications are off (an alarm nobody
/// sees). Never on web or iOS. Returns true when exact alarms are allowed
/// afterwards.
Future<bool> maybeAskExactAlarmPermission(
  BuildContext? context, {
  ExactAlarms exactAlarms = const ExactAlarms(),
  Future<PermissionStatus> Function()? readNotificationStatus,
  VoidCallback? onGranted,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    if (await exactAlarms.allowed()) return true;
    final notifications =
        await (readNotificationStatus ?? () => Permission.notification.status)();
    if (!notifications.isGranted) return false;

    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_askedKey) ?? false) return false;
    if (context == null || !context.mounted) return false;

    // Before the window, not after: however it is closed, it is not shown again.
    await preferences.setBool(_askedKey, true);
    if (!context.mounted) return false;
    if (!await explainPermission(context, PermissionPurpose.exactAlarms)) return false;

    if (!await exactAlarms.request()) return false;
    // What was scheduled inexact until now is scheduled again, exact.
    (onGranted ?? NotificationScheduler.instance.requestResync)();
    return true;
  } catch (_) {
    // A phone without the screen (or a storage hiccup): the reminders stay
    // inexact, which is what happens without the access anyway.
    return false;
  }
}

/// Sign-out: the next account on this phone gets its own explanation.
Future<void> forgetExactAlarmAsk() async {
  try {
    await (await SharedPreferences.getInstance()).remove(_askedKey);
  } catch (_) {}
}

/// After a reminder is saved: first the permission to notify, then (if it can
/// notify and has an hour of its own) the access to exact alarms. One after the
/// other, so the two windows never stack.
Future<void> askReminderPermissions(ReminderEntry reminder) async {
  BuildContext? context() => AppRouter.navigatorKey.currentContext;
  final canNotify = await maybeAskReminderNotificationPermission(context());
  if (!canNotify || !reminderHasChosenTime(reminder)) return;
  await maybeAskExactAlarmPermission(context());
}
