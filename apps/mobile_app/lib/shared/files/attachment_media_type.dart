import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';

/// Upper bound per attachment, matching the backend and the platform body
/// limit (4 MB — see Chat LLM interna's POST /chat-attachments contract).
const maxAttachmentBytes = 4 * 1024 * 1024;

/// The real media type of an attachment, read from its first bytes (the
/// backend decides from the bytes too). The extension is only a fallback for
/// formats without a recognisable signature. Never throws.
MediaType attachmentMediaType(Uint8List bytes, String fileName) {
  final fromBytes = _fromSignature(bytes);
  if (fromBytes != null) return fromBytes;

  final dot = fileName.lastIndexOf('.');
  final extension = dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'png':
      return MediaType('image', 'png');
    case 'webp':
      return MediaType('image', 'webp');
    case 'pdf':
      return MediaType('application', 'pdf');
  }
  return MediaType('application', 'octet-stream');
}

bool isPdfBytes(Uint8List bytes) => _startsWithAscii(bytes, '%PDF-');

MediaType? _fromSignature(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return MediaType('image', 'jpeg');
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return MediaType('image', 'png');
  }
  if (bytes.length >= 12 &&
      _startsWithAscii(bytes, 'RIFF') &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return MediaType('image', 'webp');
  }
  if (isPdfBytes(bytes)) return MediaType('application', 'pdf');
  return null;
}

bool _startsWithAscii(Uint8List bytes, String prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix.codeUnitAt(i)) return false;
  }
  return true;
}

/// A message for a file the app can reject before any upload, or null when
/// the file may be sent. The backend re-checks everything from the bytes.
String? attachmentValidationError(Uint8List bytes, String fileName) {
  if (bytes.length > maxAttachmentBytes) {
    return 'Il file è troppo grande (max 4 MB).';
  }
  if (isPdfFileName(fileName) && !isPdfBytes(bytes)) {
    return 'Questo file non sembra un PDF valido.';
  }
  return null;
}

bool isPdfFileName(String fileName) => fileName.toLowerCase().endsWith('.pdf');
