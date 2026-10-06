import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vet_app_mobile/shared/files/image_metadata.dart';

/// A landscape-stored JPEG (32 wide, 16 high) whose EXIF says it must be
/// rotated 90 degrees (Orientation 6), with a GPS latitude in the same block.
Uint8List _rotatedJpegWithGps({int orientation = 6}) {
  final plain = img.encodeJpg(img.fill(img.Image(width: 32, height: 16), color: img.ColorRgb8(90, 90, 90)));
  final tiff = <int>[
    0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, // big-endian header, IFD0 at 8
    0x00, 0x02, // IFD0: two entries
    0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, orientation >> 8, orientation & 0xFF, 0x00, 0x00, // Orientation
    0x88, 0x25, 0x00, 0x04, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x26, // GPSInfo -> 38
    0x00, 0x00, 0x00, 0x00, // no next IFD
    0x00, 0x01, // GPS IFD: one entry
    0x00, 0x01, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, 0x4E, 0x00, 0x00, 0x00, // GPSLatitudeRef = N
    0x00, 0x00, 0x00, 0x00,
  ];
  final payload = [...'Exif'.codeUnits, 0, 0, ...tiff];
  final length = payload.length + 2;
  return Uint8List.fromList([
    0xFF, 0xD8,
    0xFF, 0xE1, length >> 8, length & 0xFF, ...payload,
    ...plain.sublist(2),
  ]);
}

void main() {
  test('a portrait photo stored sideways is rotated upright: width and height swap', () {
    final sideways = _rotatedJpegWithGps();
    final stripped = stripImageMetadata(sideways);

    final after = img.decodeJpg(stripped)!;
    expect(after.width, 16, reason: 'rotated by 90 degrees');
    expect(after.height, 32, reason: 'rotated by 90 degrees');
  });

  test('the rotated result carries no EXIF block, so no GPS data', () {
    final stripped = stripImageMetadata(_rotatedJpegWithGps());

    expect(String.fromCharCodes(stripped).contains('Exif'), isFalse);
    expect(img.decodeJpg(stripped)!.exif.isEmpty, isTrue);
  });

  test('an upright photo (Orientation 1) keeps its pixels as they are', () {
    final upright = stripImageMetadata(_rotatedJpegWithGps(orientation: 1));

    final decoded = img.decodeJpg(upright)!;
    expect(decoded.width, 32);
    expect(decoded.height, 16);
  });
}
