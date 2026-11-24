import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/notifications/domain/notification_time_zone.dart';

/// Collaudo N01: a phone whose zone the database does not know used to be scheduled on Rome
/// time, so every reminder moved. Now the phone's own offset is used.
void main() {
  tearDown(() => setNotificationTimeZone(kFallbackNotificationTimeZone));

  test('a zone name the database knows is used', () async {
    await initNotificationTimeZone(readZoneName: () async => 'Asia/Tokyo');

    expect(notificationUsesDeviceOffset, isFalse);
    expect(notificationTimeZoneName, 'Asia/Tokyo');
    // 08:00 in Tokyo is 23:00 UTC of the day before.
    expect(notificationInstant(DateTime(2026, 12, 1, 8)).toUtc(),
        DateTime.utc(2026, 11, 30, 23));
  });

  test('an unknown zone name follows the phone offset, not Rome', () async {
    await initNotificationTimeZone(
      readZoneName: () async => 'Mars/Olympus_Mons',
      deviceOffset: const Duration(hours: 5, minutes: 30),
    );

    expect(notificationUsesDeviceOffset, isTrue);
    expect(notificationTimeZoneName, 'UTC+05:30');
    // 08:00 at +05:30 is 02:30 UTC the same day (Rome would give 07:00 UTC).
    expect(notificationInstant(DateTime(2026, 7, 1, 8)).toUtc(),
        DateTime.utc(2026, 7, 1, 2, 30));
  });

  test(
      'a zone that cannot be read follows the phone offset too, a negative one included',
      () async {
    await initNotificationTimeZone(
      readZoneName: () async => throw StateError('no zone'),
      deviceOffset: const Duration(hours: -3, minutes: -30),
    );

    expect(notificationTimeZoneName, 'UTC-03:30');
    expect(notificationInstant(DateTime(2026, 12, 1, 8)).toUtc(),
        DateTime.utc(2026, 12, 1, 11, 30));
  });

  test('a known zone read later replaces the fixed offset', () async {
    await initNotificationTimeZone(
      readZoneName: () async => 'Nowhere/Land',
      deviceOffset: const Duration(hours: 2),
    );
    await initNotificationTimeZone(readZoneName: () async => 'Europe/London');

    expect(notificationUsesDeviceOffset, isFalse);
    expect(notificationTimeZoneName, 'Europe/London');
  });
}
