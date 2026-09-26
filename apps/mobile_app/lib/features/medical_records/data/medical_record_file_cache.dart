import 'dart:typed_data';

/// Session-only cache of raw file bytes for records uploaded through the
/// app this session, keyed by record id — there's no real file-storage
/// backend behind this demo, so nothing persists across a reload. Lets
/// "Invia file" share the real picked file via the OS share sheet instead
/// of falling back to a text summary for anything uploaded this session.
class MedicalRecordFileCache {
  MedicalRecordFileCache._();

  static final MedicalRecordFileCache instance = MedicalRecordFileCache._();

  final Map<String, ({Uint8List bytes, String fileName, String? mimeType})> _files = {};

  void put(String recordId, Uint8List bytes, String fileName, {String? mimeType}) {
    _files[recordId] = (bytes: bytes, fileName: fileName, mimeType: mimeType);
  }

  ({Uint8List bytes, String fileName, String? mimeType})? get(String recordId) =>
      _files[recordId];
}
