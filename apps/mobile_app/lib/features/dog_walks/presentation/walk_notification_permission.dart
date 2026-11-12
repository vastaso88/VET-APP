import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/permissions/permission_explainer.dart';

const _askedKey = 'vet_app.walk_notification_permission_asked';

/// Asks once, at the first walk, for the notification permission (Android
/// 13+), after saying what it's for. Without it the walk still tracks in the
/// background - Android just keeps its notification out of the shade, so
/// the owner can't see or end the walk from there.
///
/// Never blocks the walk: "Non ora", a denial, an older Android (granted by
/// default) or a permission already refused for good all simply return.
/// Asked once only - the first-run tutorial and Impostazioni have their own
/// prompts, and nagging at every walk would be worse than a hidden
/// notification.
Future<void> maybeAskWalkNotificationPermission(
  BuildContext context, {
  Future<PermissionStatus> Function()? readStatus,
  Future<PermissionStatus> Function()? request,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  try {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_askedKey) ?? false) return;

    final status = await (readStatus ?? () => Permission.notification.status)();
    if (status.isGranted || status.isPermanentlyDenied || status.isRestricted) return;

    await preferences.setBool(_askedKey, true);
    if (!context.mounted) return;
    final allow = await explainPermission(context, PermissionPurpose.walkNotifications);
    if (allow) {
      await (request ?? () => Permission.notification.request())();
    }
  } catch (_) {
    // A platform without the prompt (or a storage hiccup): start the walk anyway.
  }
}
