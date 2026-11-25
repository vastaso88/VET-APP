import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/notification_preferences_store.dart';
import '../domain/notification_plan.dart';
import 'notification_scheduler.dart';

/// Whether the phone lets the app's reminders ring, for the "Le notifiche sono
/// disattivate" banner: on Android the notification permission (13+) or the
/// app's notifications switched off in the system settings. Not applicable on
/// web or iOS, where the app schedules nothing.
class NotificationAvailability {
  NotificationAvailability({
    Future<PermissionStatus> Function()? readStatus,
    Future<PermissionStatus> Function()? requestPermission,
    Future<bool> Function()? openNotificationSettings,
    Future<bool> Function()? openAppSettingsScreen,
    Future<NotificationPreferences> Function()? loadPreferences,
    VoidCallback? onEnabled,
    bool? isAndroid,
  })  : _readStatus = readStatus ?? (() => Permission.notification.status),
        _request = requestPermission ?? (() => Permission.notification.request()),
        _openNotificationSettings = openNotificationSettings ?? _openNativeNotificationSettings,
        _openAppSettings = openAppSettingsScreen ?? openAppSettings,
        _loadPreferences = loadPreferences ?? _storedPreferences,
        _onEnabled = onEnabled,
        _isAndroid = isAndroid;

  static final NotificationAvailability instance = NotificationAvailability();

  static const _channel = MethodChannel('vetapp/app_navigation');

  final Future<PermissionStatus> Function() _readStatus;
  final Future<PermissionStatus> Function() _request;
  final Future<bool> Function() _openNotificationSettings;
  final Future<bool> Function() _openAppSettings;
  final Future<NotificationPreferences> Function() _loadPreferences;
  final VoidCallback? _onEnabled;
  final bool? _isAndroid;

  /// True while reminders cannot ring. Starts false (no banner) until [refresh]
  /// has looked.
  final ValueNotifier<bool> disabled = ValueNotifier<bool>(false);

  bool get _android =>
      _isAndroid ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static Future<NotificationPreferences> _storedPreferences() async {
    await NotificationPreferencesStore.instance.ensureLoaded();
    return NotificationPreferencesStore.instance.preferences;
  }

  /// Whether a notification of [category] would ring on this phone: allowed by
  /// Android and not switched off in Impostazioni. Never on web and iOS, where
  /// the app schedules nothing.
  Future<bool> canRing(NotificationCategory category) async {
    if (!_android) return false;
    try {
      if (!(await _loadPreferences()).allows(category)) return false;
      return (await _readStatus()).isGranted;
    } catch (_) {
      // Cannot tell: no false alarm.
      return true;
    }
  }

  /// Looks at the phone's state again (screen shown, app back from settings).
  Future<void> refresh() async {
    if (!_android) {
      disabled.value = false;
      return;
    }
    final wasDisabled = disabled.value;
    try {
      disabled.value = !(await _readStatus()).isGranted;
    } catch (_) {
      // Cannot tell: no banner rather than a false alarm.
      disabled.value = false;
    }
    if (wasDisabled && !disabled.value) {
      // Allowed from the settings: the plan was empty until now.
      (_onEnabled ?? NotificationScheduler.instance.requestResync)();
    }
  }

  /// The banner's "Attiva": the system's own dialog when Android still shows it,
  /// otherwise the app's notification settings (or, failing that, its general
  /// settings). The banner clears itself when the app is back and allowed
  /// ([refresh]).
  Future<void> activate() async {
    if (!_android) return;
    try {
      final status = await _readStatus();
      if (status.isGranted) {
        await refresh();
        return;
      }
      if (status.isDenied) {
        // Never asked, or refused once: Android shows its dialog (after a second
        // refusal it answers at once, without one, and we go to the settings).
        final result = await _request();
        if (result.isGranted) {
          await refresh();
          return;
        }
      }
      if (!await _openNotificationSettings()) await _openAppSettings();
    } catch (_) {
      // The settings screen could not be opened: nothing more to try.
    }
  }

  static Future<bool> _openNativeNotificationSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ?? false;
    } catch (_) {
      return false;
    }
  }
}
