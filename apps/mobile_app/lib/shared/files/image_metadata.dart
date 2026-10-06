import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Removes the metadata segments (EXIF with GPS position and device, XMP,
/// comments, text chunks) from a JPEG or PNG, byte for byte, without
/// re-encoding the pixels. Any other content, including WebP and PDF, is
/// returned unchanged.
Uint8List stripImageMetadata(Uint8List bytes) {
  if (_isJpeg(bytes)) {
    final orientation = _jpegOrientation(bytes);
    if (orientation != null && orientation != 1) return _uprightJpeg(bytes);
    return _stripJpeg(bytes);
  }
  if (_isPng(bytes)) return _stripPng(bytes);
  return bytes;
}

bool _isJpeg(Uint8List b) => b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

bool _isPng(Uint8List b) =>
    b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;

/// APP1 (EXIF and XMP), APP13 (IPTC), COM (comment).
const _jpegMetadataMarkers = {0xE1, 0xED, 0xFE};

Uint8List _stripJpeg(Uint8List bytes) {
  final out = BytesBuilder(copy: false)..add([0xFF, 0xD8]);
  var i = 2;
  while (i + 3 < bytes.length) {
    if (bytes[i] != 0xFF) break;
    final marker = bytes[i + 1];
    // Markers without a length: standalone (TEM, RSTn) and SOI/EOI.
    if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      out.add([0xFF, marker]);
      i += 2;
      continue;
    }
    // Start of scan: the entropy-coded image data runs to the end.
    if (marker == 0xDA) {
      out.add(bytes.sublist(i));
      return out.takeBytes();
    }
    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    final end = i + 2 + length;
    if (end > bytes.length) break;
    if (!_jpegMetadataMarkers.contains(marker)) {
      out.add(bytes.sublist(i, end));
    }
    i = end;
  }
  return out.takeBytes();
}

/// eXIf, tEXt, zTXt and iTXt chunks carry metadata.
const _pngMetadataChunks = {'eXIf', 'tEXt', 'zTXt', 'iTXt'};

Uint8List _stripPng(Uint8List bytes) {
  final out = BytesBuilder(copy: false)..add(bytes.sublist(0, 8));
  var i = 8;
  while (i + 8 <= bytes.length) {
    final length = (bytes[i] << 24) | (bytes[i + 1] << 16) | (bytes[i + 2] << 8) | bytes[i + 3];
    final type = String.fromCharCodes(bytes.sublist(i + 4, i + 8));
    final end = i + 12 + length;
    if (end > bytes.length) break;
    if (!_pngMetadataChunks.contains(type)) {
      out.add(bytes.sublist(i, end));
    }
    i = end;
  }
  return out.takeBytes();
}

/// Pixels are rotated to their upright position before the metadata goes, so
/// a photo shot in portrait keeps its orientation. Re-encoded at high quality,
/// because this path only runs for photos that really are rotated.
Uint8List _uprightJpeg(Uint8List bytes) {
  final decoded = img.decodeJpg(bytes);
  if (decoded == null) return _stripJpeg(bytes);
  final upright = img.bakeOrientation(decoded);
  upright.exif = img.ExifData();
  return Uint8List.fromList(img.encodeJpg(upright, quality: 95));
}

const _orientationTag = 0x0112;

/// The EXIF Orientation value (1 to 8) from the JPEG's APP1 block, or null.
int? _jpegOrientation(Uint8List bytes) {
  var i = 2;
  while (i + 3 < bytes.length) {
    if (bytes[i] != 0xFF) return null;
    final marker = bytes[i + 1];
    if (marker == 0xDA || marker == 0xD9) return null;
    if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    final end = i + 2 + length;
    if (end > bytes.length) return null;
    if (marker == 0xE1 && _startsWithExif(bytes, i + 4)) {
      return _orientationInTiff(bytes, i + 4 + 6, end);
    }
    i = end;
  }
  return null;
}

bool _startsWithExif(Uint8List b, int at) =>
    at + 6 <= b.length && String.fromCharCodes(b.sublist(at, at + 4)) == 'Exif';

int? _orientationInTiff(Uint8List b, int tiff, int end) {
  if (tiff + 8 > end) return null;
  final bigEndian = b[tiff] == 0x4D && b[tiff + 1] == 0x4D;
  int u16(int at) => bigEndian ? (b[at] << 8) | b[at + 1] : (b[at + 1] << 8) | b[at];
  int u32(int at) => bigEndian
      ? (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3]
      : (b[at + 3] << 24) | (b[at + 2] << 16) | (b[at + 1] << 8) | b[at];

  final ifd = tiff + u32(tiff + 4);
  if (ifd + 2 > end) return null;
  final count = u16(ifd);
  for (var entry = 0; entry < count; entry++) {
    final at = ifd + 2 + entry * 12;
    if (at + 12 > end) return null;
    if (u16(at) == _orientationTag) {
      final value = u16(at + 8);
      return value >= 1 && value <= 8 ? value : null;
    }
  }
  return null;
}
