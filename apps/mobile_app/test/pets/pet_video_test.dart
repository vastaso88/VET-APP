import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:vet_app_mobile/features/pets/data/pet_media_importer.dart';
import 'package:vet_app_mobile/features/pets/data/pet_photo_repository.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_video_rules.dart';
import 'package:vet_app_mobile/features/pets/domain/video_metadata_scrubber.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/gallery_folders_page.dart';

List<int> _u32(int value) => [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];

/// An ISO box: size, 4-char type (or raw bytes), payload.
List<int> _box(Object type, List<int> payload) => [
      ..._u32(8 + payload.length),
      ...(type is String ? type.codeUnits : type as List<int>),
      ...payload,
    ];

const _copyrightXyz = [0xA9, 0x78, 0x79, 0x7A]; // ©xyz

String _text(Uint8List bytes) => String.fromCharCodes(bytes);

bool _contains(Uint8List bytes, List<int> needle) {
  for (var i = 0; i + needle.length <= bytes.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

var _n = 0;

void main() {
  group('checkPetVideo', () {
    test('accepts a short mp4 within the size limit', () {
      final check = checkPetVideo(
        fileName: 'cane.MP4',
        sizeBytes: 20 * 1000 * 1000,
        duration: const Duration(seconds: 12),
      );

      expect(check.isOk, isTrue);
    });

    test('accepts exactly the maximum duration and size', () {
      final check = checkPetVideo(
        fileName: 'a.mov',
        sizeBytes: petVideoMaxBytes,
        duration: const Duration(seconds: petVideoMaxSeconds),
      );

      expect(check.isOk, isTrue);
    });

    test('rejects a video that is too long, naming the limit', () {
      final check = checkPetVideo(
        fileName: 'a.mp4',
        sizeBytes: 1000,
        duration: const Duration(seconds: petVideoMaxSeconds + 1),
      );

      expect(check.rejection, PetVideoRejection.tooLong);
      expect(check.message, contains('$petVideoMaxSeconds secondi'));
    });

    test('rejects a video that is too heavy, naming the limit', () {
      final check = checkPetVideo(
        fileName: 'a.mp4',
        sizeBytes: petVideoMaxBytes + 1,
        duration: const Duration(seconds: 5),
      );

      expect(check.rejection, PetVideoRejection.tooBig);
      expect(check.message, contains('50 MB'));
    });

    test('rejects formats outside mp4/m4v/mov', () {
      final check = checkPetVideo(
        fileName: 'a.avi',
        sizeBytes: 1000,
        duration: const Duration(seconds: 5),
      );

      expect(check.rejection, PetVideoRejection.unsupportedFormat);
    });

    test('an unknown duration is unreadable, never "short enough"', () {
      final check = checkPetVideo(fileName: 'a.mp4', sizeBytes: 1000, duration: null);

      expect(check.rejection, PetVideoRejection.unreadable);
    });
  });

  group('classifyPickedMedia', () {
    test('the MIME type wins when there is one', () {
      expect(classifyPickedMedia(fileName: 'x', mimeType: 'video/mp4'), PetMediaKind.video);
      expect(classifyPickedMedia(fileName: 'a.mp4', mimeType: 'image/jpeg'), PetMediaKind.photo);
    });

    test('without a MIME type the extension decides, case-insensitively', () {
      expect(classifyPickedMedia(fileName: 'clip.MOV'), PetMediaKind.video);
      expect(classifyPickedMedia(fileName: 'clip.webm'), PetMediaKind.video);
      expect(classifyPickedMedia(fileName: 'foto.jpg'), PetMediaKind.photo);
      expect(classifyPickedMedia(fileName: 'senzaestensione'), PetMediaKind.photo);
    });
  });

  test('petVideoDurationLabel formats m:ss', () {
    expect(petVideoDurationLabel(7), '0:07');
    expect(petVideoDurationLabel(30), '0:30');
    expect(petVideoDurationLabel(75), '1:15');
  });

  group('stripVideoLocationMetadata', () {
    test('blanks the Android ©xyz location atom without changing the length', () {
      final location = _box(_copyrightXyz, '+45.4642+009.1900/'.codeUnits);
      final model = _box('mdhd', [1, 2, 3, 4]);
      final moov = _box('moov', _box('udta', [...location, ...model]));
      final file = Uint8List.fromList([..._box('ftyp', 'isom'.codeUnits), ...moov]);
      final lengthBefore = file.length;

      final blanked = stripVideoLocationMetadata(file);

      expect(blanked, 1);
      expect(file.length, lengthBefore);
      expect(_text(file), isNot(contains('+45.4642')));
      expect(_contains(file, _copyrightXyz), isFalse);
      expect(_text(file), contains('free'));
      expect(_text(file), contains('mdhd'), reason: 'other atoms are untouched');
    });

    test('blanks the iOS keyed location metadata and its ilst item only', () {
      String key(String value) => value;
      final keyNames = [
        key('com.apple.quicktime.make'),
        key('com.apple.quicktime.location.ISO6709'),
        key('com.apple.quicktime.software'),
      ];
      final keys = _box('keys', [
        ..._u32(0), // version/flags
        ..._u32(keyNames.length),
        for (final name in keyNames) ..._box('mdta', name.codeUnits),
      ]);
      List<int> item(int index, String value) => _box(_u32(index), _box('data', value.codeUnits));
      final ilst = _box('ilst', [
        ...item(1, 'Apple'),
        ...item(2, '+45.4642+009.1900+120.0/'),
        ...item(3, '17.0'),
      ]);
      final hdlr = _box('hdlr', List.filled(8, 0));
      final meta = _box('meta', [...hdlr, ...keys, ...ilst]);
      final file = Uint8List.fromList([..._box('ftyp', 'qt  '.codeUnits), ..._box('moov', meta)]);

      final blanked = stripVideoLocationMetadata(file);

      expect(blanked, 1);
      expect(_text(file), isNot(contains('+45.4642')));
      expect(_text(file), contains('Apple'));
      expect(_text(file), contains('17.0'));
    });

    test('handles an ISO meta full box (version/flags before the children)', () {
      final keys = _box('keys', [
        ..._u32(0),
        ..._u32(1),
        ..._box('mdta', 'com.apple.quicktime.location.ISO6709'.codeUnits),
      ]);
      final ilst = _box('ilst', _box(_u32(1), _box('data', '+10.0+020.0/'.codeUnits)));
      final meta = _box('meta', [..._u32(0), ..._box('hdlr', List.filled(8, 0)), ...keys, ...ilst]);
      final file = Uint8List.fromList(_box('moov', meta));

      expect(stripVideoLocationMetadata(file), 1);
      expect(_text(file), isNot(contains('+10.0+020.0')));
    });

    test('a file without location data is left byte for byte as it was', () {
      final file = Uint8List.fromList([
        ..._box('ftyp', 'isom'.codeUnits),
        ..._box('moov', _box('udta', _box('name', 'cane'.codeUnits))),
        ..._box('mdat', List.filled(32, 7)),
      ]);
      final copy = Uint8List.fromList(file);

      expect(stripVideoLocationMetadata(file), 0);
      expect(file, copy);
    });

    test('malformed sizes stop the scan without throwing or changing anything', () {
      final broken = Uint8List.fromList([
        ..._u32(9999), // claims far more than exists
        ...'moov'.codeUnits,
        1,
        2,
        3,
      ]);
      final copy = Uint8List.fromList(broken);

      expect(stripVideoLocationMetadata(broken), 0);
      expect(broken, copy);
      expect(stripVideoLocationMetadata(Uint8List(0)), 0);
    });
  });

  group('compressPetPhoto and EXIF', () {
    Uint8List jpegWithGps({int orientation = 1, int width = 64, int height = 32}) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(10, 120, 200));
      image.exif.imageIfd.make = 'TestCam';
      image.exif.imageIfd.orientation = orientation;
      image.exif.gpsIfd.gpsLatitude = 45.4642;
      image.exif.gpsIfd.gpsLongitude = 9.19;
      return Uint8List.fromList(img.encodeJpg(image));
    }

    test('the fixture really carries EXIF (so the next test proves something)', () {
      final input = jpegWithGps();

      expect(_contains(input, 'Exif'.codeUnits), isTrue);
      expect(_contains(input, 'TestCam'.codeUnits), isTrue);
    });

    test('no EXIF - position, device, time - survives compression', () {
      final out = compressPetPhoto(jpegWithGps());

      expect(_contains(out, 'Exif'.codeUnits), isFalse);
      expect(_contains(out, 'TestCam'.codeUnits), isFalse);
      expect(img.decodeJpg(out)!.exif.isEmpty, isTrue);
    });

    test('a rotated shot is turned upright before the orientation tag is dropped', () {
      // 64x32 stored sideways with orientation 6 (rotate 90 CW): upright it is 32x64.
      final out = compressPetPhoto(jpegWithGps(orientation: 6));

      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 32);
      expect(decoded.height, 64);
    });
  });

  group('petPhotoEntryFromRow', () {
    final base = {
      'id': 'a',
      'pet_id': 'p',
      'storage_path': 'o/p/a.jpg',
      'created_at': '2026-10-06T10:00:00Z',
      'is_profile': false,
    };

    test('a row without media_type (written before videos) is a photo', () {
      final entry = petPhotoEntryFromRow(base);

      expect(entry.isVideo, isFalse);
      expect(entry.durationSeconds, isNull);
    });

    test('a video row carries its duration', () {
      final entry = petPhotoEntryFromRow({
        ...base,
        'storage_path': 'o/p/a.mp4',
        'media_type': 'video',
        'duration_seconds': 17,
      });

      expect(entry.isVideo, isTrue);
      expect(entry.durationSeconds, 17);
    });

    test('storage path keeps the video extension', () {
      expect(
        petPhotoStoragePath(ownerId: 'o', petId: 'p', photoId: 'x', extension: 'mp4'),
        'o/p/x.mp4',
      );
    });
  });

  test('galleryCountLabel counts photos and videos separately', () {
    PetPhotoEntry entry(bool video) => PetPhotoEntry(
          id: '${_n++}',
          petId: 'p',
          storagePath: 'x',
          createdAt: DateTime(2026, 1, 1),
          isProfile: false,
          kind: video ? PetMediaKind.video : PetMediaKind.photo,
        );

    expect(galleryCountLabel([entry(false), entry(false)]), '2 foto');
    expect(galleryCountLabel([entry(false), entry(true)]), '1 foto · 1 video');
    expect(galleryCountLabel([entry(true)]), '1 video');
  });

  group('PetMediaImporter', () {
    XFile video(String name, int size) =>
        XFile.fromData(Uint8List(size),
            name: name, path: '/clips/$name', mimeType: 'video/mp4', length: size);

    test('a video over the size limit is refused before the player is even opened', () async {
      var probed = false;
      final importer = PetMediaImporter(probe: (_) async {
        probed = true;
        return const Duration(seconds: 5);
      });

      final result = await importer.importAll(
        petId: 'p',
        files: [video('grande.mp4', petVideoMaxBytes + 1)],
      );

      expect(result.added, 0);
      expect(result.problems.single, contains('troppo pesante'));
      expect(probed, isFalse);
    });

    test('a video longer than the limit is refused', () async {
      final importer = PetMediaImporter(probe: (_) async => const Duration(seconds: 90));

      final result = await importer.importAll(petId: 'p', files: [video('lungo.mp4', 1000)]);

      expect(result.problems.single, contains('troppo lungo'));
    });

    test('an unreadable video is refused', () async {
      final importer = PetMediaImporter(probe: (_) async => null);

      final result = await importer.importAll(petId: 'p', files: [video('rotto.mp4', 1000)]);

      expect(result.problems.single, contains('Non riesco a leggere'));
    });

    test('progress is reported for every file, and one bad file does not stop the rest', () async {
      final importer = PetMediaImporter(probe: (_) async => null);
      final steps = <String>[];

      final result = await importer.importAll(
        petId: 'p',
        files: [video('a.mp4', 10), video('b.mp4', 10), video('c.avi', 10)],
        onProgress: (current, total) => steps.add('$current/$total'),
      );

      expect(steps, ['1/3', '2/3', '3/3']);
      expect(result.problems, hasLength(3));
    });

    test('summary lists what was added and the first problem', () {
      const result = PetMediaImportResult(
        photos: 2,
        videos: 1,
        problems: ['"x.mp4": Video troppo lungo.', 'altro'],
      );

      expect(result.summary(), contains('Caricati: 2 foto e 1 video'));
      expect(result.summary(), contains('troppo lungo'));
      expect(result.summary(), contains('altri 1'));
    });
  });
}
