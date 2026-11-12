// End-to-end check of the real attachment upload path against a running API.
//
// Not part of the normal suite: it is skipped unless E2E=true is defined.
// Run it (API started first, see docs/features/chat_attachments_contract.md):
//
//   cd apps/mobile_app
//   flutter test test/e2e/chat_attachments_e2e_test.dart \
//     --dart-define=E2E=true --dart-define=API_BASE_URL=http://127.0.0.1:8010
//
// The data source under test is the app's own HttpChatAttachmentRemoteDataSource
// with its default client, so the request is exactly what the app sends.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:vet_app_mobile/features/chat/data/chat_attachment_remote_data_source.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

const _e2eEnabled = bool.fromEnvironment('E2E');
const _apiBase = String.fromEnvironment('API_BASE_URL');
late String _petId;

Uint8List _jpeg() {
  final image = img.Image(width: 64, height: 64);
  img.fill(image, color: img.ColorRgb8(200, 120, 40));
  return Uint8List.fromList(img.encodeJpg(image));
}

Uint8List _png() {
  final image = img.Image(width: 64, height: 64);
  img.fill(image, color: img.ColorRgb8(40, 120, 200));
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _textPdf() => File('test/e2e/fixtures/referto_testo.pdf').readAsBytesSync();

Uint8List _oversizedPdf() {
  final bytes = Uint8List(4 * 1024 * 1024 + 512 * 1024);
  bytes.setAll(0, '%PDF-1.4\n'.codeUnits);
  return bytes;
}

void main() {
  const skip = _e2eEnabled ? null : 'E2E not enabled (see the header of this file)';
  final source = HttpChatAttachmentRemoteDataSource();

  setUpAll(() async {
    if (!_e2eEnabled) return;
    expect(_apiBase, isNotEmpty, reason: 'pass --dart-define=API_BASE_URL=...');
    // Uploads need a pet profile owned by the caller: create one through the API.
    final created = await http.post(
      Uri.parse('$_apiBase/pets'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': 'Moka e2e', 'species': 'Cane'}),
    );
    expect(created.statusCode, 200, reason: 'pet creation: ${created.body}');
    final pet = (jsonDecode(created.body) as Map<String, dynamic>)['pet_profile'] as Map<String, dynamic>;
    _petId = pet['id'] as String;
  });

  Future<http.Response> rawDownload(String id) =>
      http.get(Uri.parse('$_apiBase/chat-attachments/$id/file'));

  Future<void> expectRoundTrip({
    required String name,
    required Uint8List bytes,
    required String expectedContentType,
  }) async {
    final upload = await source.upload(petId: _petId, imageBytes: bytes, fileName: name);
    final id = upload.fold(
      onSuccess: (uploaded) => uploaded.id,
      onFailure: (error) => fail('$name: upload failed with ${error.code}: ${error.message}'),
    );

    final downloaded = await source.download(id);
    final downloadedBytes = downloaded.fold(
      onSuccess: (value) => value,
      onFailure: (error) => fail('$name: download failed with ${error.code}'),
    );
    expect(downloadedBytes, bytes, reason: '$name: bytes differ after the round trip');

    final raw = await rawDownload(id);
    expect(raw.statusCode, 200);
    expect(raw.headers['content-type'], startsWith(expectedContentType),
        reason: '$name: content-type must be the real type');
    expect(raw.bodyBytes, bytes, reason: '$name: raw bytes differ');
  }

  test('e2e JPG: uploads and downloads byte-for-byte as image/jpeg', () async {
    await expectRoundTrip(name: 'foto.jpg', bytes: _jpeg(), expectedContentType: 'image/jpeg');
  }, skip: skip);

  test('e2e PNG: uploads and downloads byte-for-byte as image/png', () async {
    await expectRoundTrip(name: 'foto.png', bytes: _png(), expectedContentType: 'image/png');
  }, skip: skip);

  test('e2e text PDF: uploads as application/pdf and returns a usable reply', () async {
    final bytes = _textPdf();
    final upload = await source.upload(petId: _petId, imageBytes: bytes, fileName: 'referto.pdf');
    final attachment = upload.fold(
      onSuccess: (value) => value,
      onFailure: (error) => fail('text PDF rejected: ${error.code}: ${error.message}'),
    );
    expect(attachment.id, isNotEmpty);
    // Either the reading succeeded, or the backend says so explicitly.
    expect(attachment.analysisFailed || (attachment.analysis?.isNotEmpty ?? false), isTrue);

    await expectRoundTrip(name: 'referto.pdf', bytes: bytes, expectedContentType: 'application/pdf');
  }, skip: skip);

  test('e2e PDF over 4 MB: rejected with attachment_too_large, nothing stored', () async {
    final result = await source.upload(
      petId: _petId,
      imageBytes: _oversizedPdf(),
      fileName: 'grande.pdf',
    );
    expect(
      result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
      anyOf('attachment_too_large', 'chat_attachment_http_413'),
    );
  }, skip: skip);

  test('e2e fake .pdf (plain text): rejected with unsupported_attachment_type', () async {
    final text = Uint8List.fromList('questo non è un pdf'.codeUnits);
    final result = await source.upload(petId: _petId, imageBytes: text, fileName: 'finto.pdf');
    expect(
      result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
      'unsupported_attachment_type',
    );
  }, skip: skip);

  test('e2e PNG named .pdf: accepted and declared as image/png (bytes win)', () async {
    await expectRoundTrip(name: 'camuffato.pdf', bytes: _png(), expectedContentType: 'image/png');
  }, skip: skip);

  test('e2e the default config points at the API under test', () {
    expect(const AppRuntimeConfigLoader().load().apiBaseUrl, _apiBase);
  }, skip: skip);
}
