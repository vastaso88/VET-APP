import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Zone used until the phone's own zone is known (and when it cannot be read,
/// e.g. on the web or in tests): the app started Italian-only.
const kFallbackNotificationTimeZone = 'Europe/Rome';

/// Reminders are entered and read as clock times of the phone's own zone, so
/// notifications are scheduled in it. [initNotificationTimeZone] resolves it
/// once at start-up (no permission needed); [kFallbackNotificationTimeZone]
/// applies before that and whenever it fails.
String _zoneName = kFallbackNotificationTimeZone;

bool _initialized = false;

void _ensureDatabase() {
  if (!_initialized) {
    tz_data.initializeTimeZones();
    _initialized = true;
  }
}

/// The name of the zone notifications are currently scheduled in.
String get notificationTimeZoneName => _zoneName;

/// Reads the phone's time zone (IANA name such as "Europe/London"). Safe to
/// call again, e.g. after the owner travels. Never throws.
Future<void> initNotificationTimeZone() async {
  _ensureDatabase();
  if (kIsWeb) return;
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    setNotificationTimeZone(info.identifier);
  } catch (_) {
    // Keep the current (fallback) zone.
  }
}

/// Selects the zone by IANA name; an unknown name keeps the current one.
@visibleForTesting
void setNotificationTimeZone(String name) {
  _ensureDatabase();
  try {
    tz.getLocation(name);
    _zoneName = name;
  } catch (_) {
    // Unknown to the timezone database: keep the current zone.
  }
}

tz.Location notificationLocation() {
  _ensureDatabase();
  return tz.getLocation(_zoneName);
}

/// The instant at which the phone's clocks show [wallClock]'s date and time —
/// built from the fields, so 08:00 stays 08:00 across the summer-time switch.
tz.TZDateTime notificationInstant(DateTime wallClock) {
  return tz.TZDateTime(
    notificationLocation(),
    wallClock.year,
    wallClock.month,
    wallClock.day,
    wallClock.hour,
    wallClock.minute,
  );
}

/// "Now" as a wall-clock time of the phone's zone, the reference
/// planNotifications compares wall-clock times against.
DateTime notificationNow() {
  final now = tz.TZDateTime.now(notificationLocation());
  return DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);
}
