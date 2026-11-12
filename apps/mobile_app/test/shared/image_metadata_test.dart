import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vet_app_mobile/shared/files/image_metadata.dart';

/// A JPEG with an EXIF APP1 segment that holds a GPS latitude reference, the
/// same kind of block a phone camera writes.
Uint8List _jpegWithGps() {
  final plain = img.encodeJpg(img.fill(img.Image(width: 32, height: 32), color: img.ColorRgb8(10, 20, 30)));
  final tiff = <int>[
    0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, // big-endian TIFF header, IFD at 8
    0x00, 0x01, 0x88, 0x25, 0x00, 0x04, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x1A, 0x00, 0x00, 0x00, 0x00, // GPSInfo -> 26
    0x00, 0x01, 0x00, 0x01, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, 0x4E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // GPSLatitudeRef = N
  ];
  final payload = [...'Exif'.codeUnits, 0, 0, ...tiff];
  final length = payload.length + 2;
  return Uint8List.fromList([
    0xFF, 0xD8,
    0xFF, 0xE1, length >> 8, length & 0xFF, ...payload,
    ...plain.sublist(2),
  ]);
}

/// A PNG with a tEXt chunk, which is where text metadata lives.
Uint8List _pngWithText() {
  final plain = img.encodePng(img.fill(img.Image(width: 8, height: 8), color: img.ColorRgb8(1, 2, 3)));
  final text = [...'Comment'.codeUnits, 0, ...'posizione 45.46,9.19'.codeUnits];
  final chunk = [
    0, 0, 0, text.length,
    ...'tEXt'.codeUnits,
    ...text,
    0, 0, 0, 0, // CRC is not checked by the reader
  ];
  final iend = plain.length - 12; // IEND chunk starts here
  return Uint8List.fromList([...plain.sublist(0, iend), ...chunk, ...plain.sublist(iend)]);
}

void main() {
  test('a JPEG with a GPS EXIF block loses it and keeps its picture', () {
    final withGps = _jpegWithGps();
    expect(String.fromCharCodes(withGps).contains('Exif'), isTrue, reason: 'fixture carries EXIF');

    final stripped = stripImageMetadata(withGps);

    expect(String.fromCharCodes(stripped).contains('Exif'), isFalse);
    expect(stripped.length, lessThan(withGps.length));
    final decoded = img.decodeJpg(stripped);
    expect(decoded, isNotNull);
    expect(decoded!.width, 32);
    expect(decoded.height, 32);
  });

  test('a PNG text chunk is removed and the image still decodes', () {
    final withText = _pngWithText();
    expect(String.fromCharCodes(withText).contains('tEXt'), isTrue);

    final stripped = stripImageMetadata(withText);

    expect(String.fromCharCodes(stripped).contains('tEXt'), isFalse);
    expect(img.decodePng(stripped)!.width, 8);
  });

  test('bytes that are neither JPEG nor PNG are returned unchanged', () {
    final pdf = Uint8List.fromList('%PDF-1.4 testo'.codeUnits);
    expect(stripImageMetadata(pdf), pdf);
  });
}
