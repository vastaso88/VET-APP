import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/permissions/permission_explainer.dart';
import '../application/notification_scheduler.dart';

const _asksKey = 'vet_app.reminder_notification_permission_asks';

/// How many times the app asks for the notification permission on its own
/// because of reminders. Android itself stops showing its dialog after two
/// refusals; this keeps the app from nagging before that.
const maxReminderPermissionAsks = 2;

/// Reminders only notify if the phone allows it (Android 13+), and the only
/// places that asked were registration, the first walk and Impostazioni: an
/// owner who signs in on a fresh install - another build of the app, a new
/// phone - saved reminders that never rang and was never asked.
///
/// So this asks, after saying why, when a reminder is saved and when the app
/// opens with reminders waiting. Quiet when the permission is already granted,
/// refused for good, or asked [maxReminderPermissionAsks] times; never on web
/// or iOS. Returns true when notifications are allowed afterwards.
Future<bool> maybeAskReminderNotificationPermission(
  BuildContext? context, {
  Future<PermissionStatus> Function()? readStatus,
  Future<PermissionStatus> Function()? request,
  VoidCallback? onGranted,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    final status = await (readStatus ?? () => Permission.notification.status)();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied || status.isRestricted) return false;

    final preferences = await SharedPreferences.getInstance();
    final asks = preferences.getInt(_asksKey) ?? 0;
    if (asks >= maxReminderPermissionAsks) return false;
    if (context == null || !context.mounted) return false;

    await preferences.setInt(_asksKey, asks + 1);
    if (!context.mounted) return false;
    final allow = await explainPermission(context, PermissionPurpose.notifications);
    if (!allow) return false;

    final result = await (request ?? () => Permission.notification.request())();
    if (!result.isGranted) return false;
    // The plan was not scheduled while the permission was missing.
    (onGranted ?? NotificationScheduler.instance.requestResync)();
    return true;
  } catch (_) {
    // A platform without the prompt (or a storage hiccup): nothing to ask.
    return false;
  }
}
