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

/// Set when the phone's zone has no name the database knows (or cannot be read): the reminders
/// then follow the phone's own hours-and-minutes offset from UTC instead of jumping to Rome
/// time (collaudo N01). It does not follow a summer-time switch on its own: it is read again at
/// every start and whenever [initNotificationTimeZone] is called.
tz.Location? _fixedOffsetLocation;

/// The name of the zone notifications are currently scheduled in.
String get notificationTimeZoneName =>
    _fixedOffsetLocation == null ? _zoneName : _fixedOffsetLocation!.name;

/// True while the reminders follow the phone's fixed offset (its zone was not recognised).
bool get notificationUsesDeviceOffset => _fixedOffsetLocation != null;

/// Reads the phone's time zone (IANA name such as "Europe/London"). Safe to
/// call again, e.g. after the owner travels. Never throws.
///
/// A zone the database does not know, or one that cannot be read, no longer means Rome: the
/// phone's own offset from UTC is used ([deviceOffset], by default the phone's current one).
Future<void> initNotificationTimeZone({
  Future<String> Function()? readZoneName,
  Duration? deviceOffset,
}) async {
  _ensureDatabase();
  if (kIsWeb && readZoneName == null) return;
  try {
    final name = readZoneName != null
        ? await readZoneName()
        : (await FlutterTimezone.getLocalTimezone()).identifier;
    if (!setNotificationTimeZone(name)) {
      useFixedNotificationOffset(deviceOffset ?? DateTime.now().timeZoneOffset);
    }
  } catch (_) {
    useFixedNotificationOffset(deviceOffset ?? DateTime.now().timeZoneOffset);
  }
}

/// Schedules in a fixed [offset] from UTC (the phone's own), with no zone name.
@visibleForTesting
void useFixedNotificationOffset(Duration offset) {
  _fixedOffsetLocation = tz.Location(
    'UTC${offset.isNegative ? '-' : '+'}'
    '${offset.abs().inHours.toString().padLeft(2, '0')}:'
    '${(offset.abs().inMinutes % 60).toString().padLeft(2, '0')}',
    [-8640000000000000],
    [0],
    [tz.TimeZone(offset, isDst: false, abbreviation: '')],
  );
}

/// Selects the zone by IANA name. False (nothing changes) when the database does not know it.
@visibleForTesting
bool setNotificationTimeZone(String name) {
  _ensureDatabase();
  try {
    tz.getLocation(name);
    _zoneName = name;
    _fixedOffsetLocation = null;
    return true;
  } catch (_) {
    return false;
  }
}

tz.Location notificationLocation() {
  _ensureDatabase();
  return _fixedOffsetLocation ?? tz.getLocation(_zoneName);
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
  return DateTime(
      now.year, now.month, now.day, now.hour, now.minute, now.second);
}
