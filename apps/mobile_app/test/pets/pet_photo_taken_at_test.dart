import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vet_app_mobile/features/dog_walks/domain/photo_walk_match.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/pets/data/pet_photo_repository.dart';

Uint8List _jpeg({String? dateTimeOriginal, String? dateTime}) {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  if (dateTimeOriginal != null) image.exif.exifIfd['DateTimeOriginal'] = dateTimeOriginal;
  if (dateTime != null) image.exif.imageIfd['DateTime'] = dateTime;
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  group('photoTakenAtFromExif', () {
    test('reads the original shooting time as local time', () {
      expect(
        photoTakenAtFromExif(_jpeg(dateTimeOriginal: '2026:10:07 10:15:30')),
        DateTime(2026, 10, 7, 10, 15, 30),
      );
    });

    test('falls back to the plain DateTime tag', () {
      expect(
        photoTakenAtFromExif(_jpeg(dateTime: '2025:01:02 03:04:05')),
        DateTime(2025, 1, 2, 3, 4, 5),
      );
    });

    test('null without EXIF, with a blank date or for non-JPEG bytes', () {
      expect(photoTakenAtFromExif(_jpeg()), isNull);
      expect(photoTakenAtFromExif(_jpeg(dateTimeOriginal: '0000:00:00 00:00:00')), isNull);
      expect(photoTakenAtFromExif(Uint8List.fromList([1, 2, 3])), isNull);
    });

    test('the uploaded copy still carries no EXIF', () {
      final out = compressPetPhoto(_jpeg(dateTimeOriginal: '2026:10:07 10:15:30'));
      expect(photoTakenAtFromExif(out), isNull);
    });
  });

  test('a row with taken_at keeps it, an older row has none', () {
    final base = {
      'id': 'p1',
      'pet_id': 'pet-1',
      'storage_path': 'o/pet-1/p1.jpg',
      'created_at': '2026-10-07T09:00:00Z',
      'is_profile': false,
    };
    expect(petPhotoEntryFromRow(base).takenAt, isNull);
    expect(
      petPhotoEntryFromRow({...base, 'taken_at': '2026-10-07T08:15:30Z'}).takenAt,
      DateTime.utc(2026, 10, 7, 8, 15, 30),
    );
  });

  group('walkForPhoto', () {
    WalkSession walk(String id, DateTime start, DateTime? end,
            {WalkStatus status = WalkStatus.completed}) =>
        WalkSession(
          id: id,
          ownerId: 'o',
          petId: 'pet-1',
          startedAt: start,
          endedAt: end,
          status: status,
        );
    final morning = walk('m', DateTime(2026, 10, 7, 8), DateTime(2026, 10, 7, 8, 30));
    final evening = walk('e', DateTime(2026, 10, 7, 18), DateTime(2026, 10, 7, 18, 45));

    test('matches the walk the shot falls in, ends included', () {
      expect(walkForPhoto(DateTime(2026, 10, 7, 8, 10), [morning, evening])?.id, 'm');
      expect(walkForPhoto(DateTime(2026, 10, 7, 8), [morning])?.id, 'm');
      expect(walkForPhoto(DateTime(2026, 10, 7, 8, 30), [morning])?.id, 'm');
    });

    test('a shot outside every walk has none', () {
      expect(walkForPhoto(DateTime(2026, 10, 7, 8, 30, 1), [morning, evening]), isNull);
      expect(walkForPhoto(DateTime(2026, 10, 7, 7, 59, 59), [morning]), isNull);
      expect(walkForPhoto(DateTime(2026, 10, 7, 12), const []), isNull);
    });

    test('a walk in progress runs until now, a discarded one never matches', () {
      final live = walk('l', DateTime(2026, 10, 7, 9), null, status: WalkStatus.inProgress);
      expect(
        walkForPhoto(DateTime(2026, 10, 7, 9, 20), [live], now: DateTime(2026, 10, 7, 9, 30))?.id,
        'l',
      );
      expect(
        walkForPhoto(DateTime(2026, 10, 7, 9, 40), [live], now: DateTime(2026, 10, 7, 9, 30)),
        isNull,
      );
      final dropped = walk('d', DateTime(2026, 10, 7, 9), DateTime(2026, 10, 7, 10),
          status: WalkStatus.discarded);
      expect(walkForPhoto(DateTime(2026, 10, 7, 9, 20), [dropped]), isNull);
    });

    test('overlapping walks (stale data): the most recent wins', () {
      final later = walk('later', DateTime(2026, 10, 7, 8, 15), DateTime(2026, 10, 7, 9));
      expect(walkForPhoto(DateTime(2026, 10, 7, 8, 20), [later, morning])?.id, 'later');
      expect(walkForPhoto(DateTime(2026, 10, 7, 8, 20), [morning, later])?.id, 'later');
    });

    test('UTC and local times compare as the same instant', () {
      expect(walkForPhoto(DateTime(2026, 10, 7, 8, 10).toUtc(), [morning])?.id, 'm');
    });
  });

  test('walkPhotoLabel is dated by the walk start', () {
    final walk = WalkSession(
      id: 'w1',
      ownerId: 'o',
      petId: 'pet-1',
      startedAt: DateTime(2026, 10, 7, 23, 50),
      status: WalkStatus.completed,
      endedAt: DateTime(2026, 10, 8, 0, 20),
    );
    expect(walkPhotoLabel(walk), 'Passeggiata del 07/10/26');
  });
}
