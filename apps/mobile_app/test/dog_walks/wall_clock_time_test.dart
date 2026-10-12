import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/data/dog_walks_repository.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/photo_walk_match.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/wall_clock_time.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';

/// These run in whatever zone the machine is in. The point of the helpers is
/// that the wall-clock FIELDS survive the trip through a timestamptz column
/// that treats what it is given as UTC, so every assertion is about fields -
/// which makes them meaningful (and failing without the fix) on any machine
/// not set to UTC, such as a phone in Italy.
void main() {
  group('wallClockToStored / storedToWallClock', () {
    test('the stored string is the wall clock fields marked as UTC', () {
      expect(wallClockToStored(DateTime(2026, 10, 9, 10, 5, 30)), '2026-10-09T10:05:30.000Z');
    });

    test('what Supabase returns for that value reads back as the same wall clock', () {
      final read = storedToWallClock('2026-10-09T10:05:30+00:00')!;

      expect(read.isUtc, isFalse, reason: 'a local time again');
      expect([read.year, read.month, read.day, read.hour, read.minute, read.second],
          [2026, 10, 9, 10, 5, 30]);
    });

    test('the "Z" and "+00:00" spellings are read the same', () {
      expect(storedToWallClock('2026-10-09T10:05:30Z'), storedToWallClock('2026-10-09T10:05:30+00:00'));
    });

    test('a value without a zone (the app own on-device copy) is already local', () {
      expect(storedToWallClock('2026-10-09T10:05:30.000'), DateTime(2026, 10, 9, 10, 5, 30));
    });

    test('round trip keeps the wall clock, including milliseconds and day edges', () {
      for (final time in [
        DateTime(2026, 10, 9, 10, 5, 30, 123),
        DateTime(2026, 1, 1, 0, 0, 0),
        DateTime(2026, 12, 31, 23, 59, 59, 999),
        DateTime(2026, 3, 29, 12, 0), // around a clock change
      ]) {
        expect(storedToWallClock(wallClockToStored(time)), time);
      }
    });

    test('a UTC time is stored as its local wall clock and comes back as the same instant', () {
      final instant = DateTime.utc(2026, 10, 9, 8, 5);

      final back = storedToWallClock(wallClockToStored(instant))!;

      expect(back.isAtSameMomentAs(instant), isTrue);
    });

    test('empty, null and garbage are null', () {
      expect(storedToWallClock(null), isNull);
      expect(storedToWallClock(''), isNull);
      expect(storedToWallClock('   '), isNull);
      expect(storedToWallClock('ieri'), isNull);
    });
  });

  group('dog_walks rows', () {
    WalkSession walk() => WalkSession(
          id: 'w',
          ownerId: 'o',
          petId: 'p',
          status: WalkStatus.completed,
          startedAt: DateTime(2026, 10, 9, 10, 0),
          endedAt: DateTime(2026, 10, 9, 10, 9),
          pausedAt: DateTime(2026, 10, 9, 10, 4),
          distanceMeters: 401,
          durationSeconds: 540,
          route: [
            RoutePoint(
              coordinates: const Coordinates(latitude: 45.46, longitude: 9.19),
              recordedAt: DateTime.utc(2026, 10, 9, 8, 1),
            ),
          ],
        );

    test('what the app writes is read back as the same walk (Supabase turns it into +00:00)', () {
      final row = DogWalksRepository.toRow(walk());
      // Supabase hands timestamptz values back with an explicit offset.
      final fromServer = {
        ...row,
        'started_at': (row['started_at'] as String).replaceFirst('Z', '+00:00'),
        'ended_at': (row['ended_at'] as String).replaceFirst('Z', '+00:00'),
        'paused_at': (row['paused_at'] as String).replaceFirst('Z', '+00:00'),
      };

      final read = DogWalksRepository.fromRow(fromServer)!;

      expect(read.startedAt, DateTime(2026, 10, 9, 10, 0));
      expect(read.endedAt, DateTime(2026, 10, 9, 10, 9));
      expect(read.pausedAt, DateTime(2026, 10, 9, 10, 4));
    });

    test('walks already in the database (written as naive local text) read the same way', () {
      final row = {
        ...DogWalksRepository.toRow(walk()),
        // What builds before this fix stored: the wall clock with no zone,
        // which the column kept as UTC and PostgREST returns as +00:00.
        'started_at': '2026-10-09T10:00:00+00:00',
        'ended_at': '2026-10-09T10:09:00+00:00',
      };

      final read = DogWalksRepository.fromRow(row)!;

      expect(read.startedAt, DateTime(2026, 10, 9, 10, 0));
      expect(read.endedAt, DateTime(2026, 10, 9, 10, 9));
    });

    test('route points keep their real UTC instants', () {
      final row = DogWalksRepository.toRow(walk());

      final point = (row['route'] as List).single as Map<String, dynamic>;
      expect(point['recorded_at'], '2026-10-09T08:01:00.000Z');

      final read = DogWalksRepository.fromRow(row)!;
      expect(read.route.single.recordedAt.isAtSameMomentAs(DateTime.utc(2026, 10, 9, 8, 1)), isTrue);
    });

    test('a walk read from the server contains a photo taken during it', () {
      // The owner report: a photo shot at 10:05 on a 10:00-10:09 walk got no
      // caption once the walk came back from the server, because its window
      // had slid by the zone offset. taken_at is a real instant (UTC).
      final fromServer = DogWalksRepository.fromRow({
        ...DogWalksRepository.toRow(walk()),
        'started_at': '2026-10-09T10:00:00+00:00',
        'ended_at': '2026-10-09T10:09:00+00:00',
      })!;
      final photoInstant = DateTime(2026, 10, 9, 10, 5).toUtc();

      expect(walkForPhoto(photoInstant, [fromServer]), isNotNull);
      expect(walkForPhoto(DateTime(2026, 10, 9, 10, 20).toUtc(), [fromServer]), isNull);
      expect(walkForPhoto(DateTime(2026, 10, 9, 9, 50).toUtc(), [fromServer]), isNull);
    });

    test('the match does not depend on whether the photo time is local or UTC', () {
      final read = WalkSession(
        id: 'w',
        ownerId: 'o',
        petId: 'p',
        status: WalkStatus.completed,
        startedAt: DateTime(2026, 10, 9, 10, 0),
        endedAt: DateTime(2026, 10, 9, 10, 9),
      );
      final local = DateTime(2026, 10, 9, 10, 5);

      expect(walkForPhoto(local, [read]), isNotNull);
      expect(walkForPhoto(local.toUtc(), [read]), isNotNull);
    });
  });
}
