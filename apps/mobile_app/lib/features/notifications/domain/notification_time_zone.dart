import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Reminders are entered and read as Italian clock times, so notifications
/// are scheduled in this zone whatever the phone's own setting.
const kNotificationTimeZone = 'Europe/Rome';

bool _initialized = false;

tz.Location notificationLocation() {
  if (!_initialized) {
    tz_data.initializeTimeZones();
    _initialized = true;
  }
  return tz.getLocation(kNotificationTimeZone);
}

/// The instant at which Italian clocks show [wallClock]'s date and time —
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

/// "Now" as an Italian wall-clock time, the reference planNotifications
/// compares wall-clock times against.
DateTime notificationNow() {
  final now = tz.TZDateTime.now(notificationLocation());
  return DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);
}
