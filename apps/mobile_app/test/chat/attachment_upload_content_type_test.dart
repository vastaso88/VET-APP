import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/chat/data/chat_attachment_remote_data_source.dart';
import 'package:vet_app_mobile/shared/files/attachment_media_type.dart';

Uint8List _bytes(List<int> head) => Uint8List.fromList([...head, ...List<int>.filled(16, 0)]);

final _jpeg = _bytes([0xFF, 0xD8, 0xFF, 0xE0]);
final _png = _bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
final _webp = Uint8List.fromList([
  ...ascii('RIFF'),
  0, 0, 0, 0,
  ...ascii('WEBP'),
  0, 0, 0, 0,
]);
final _pdf = Uint8List.fromList([...ascii('%PDF-1.7\n'), ...List<int>.filled(16, 0)]);

List<int> ascii(String s) => s.codeUnits;

void main() {
  group('attachmentMediaType reads the real type from the bytes', () {
    test('jpeg, png, webp and pdf are detected from their signature', () {
      expect(attachmentMediaType(_jpeg, 'foto.bin').toString(), 'image/jpeg');
      expect(attachmentMediaType(_png, 'foto.bin').toString(), 'image/png');
      expect(attachmentMediaType(_webp, 'foto.bin').toString(), 'image/webp');
      expect(attachmentMediaType(_pdf, 'referto.bin').toString(), 'application/pdf');
    });

    test('the bytes win over a misleading extension', () {
      // A PNG renamed .pdf must be declared as PNG, not as a PDF.
      expect(attachmentMediaType(_png, 'referto.pdf').toString(), 'image/png');
    });

    test('falls back to the extension when there is no known signature', () {
      final unknown = _bytes([0x00, 0x01, 0x02]);
      expect(attachmentMediaType(unknown, 'scan.JPG').toString(), 'image/jpeg');
      expect(attachmentMediaType(unknown, 'referto.pdf').toString(), 'application/pdf');
    });

    test('an unknown type is octet-stream, and no exception is thrown', () {
      final unknown = _bytes([0x00, 0x01]);
      expect(attachmentMediaType(unknown, 'file').toString(), 'application/octet-stream');
      expect(attachmentMediaType(Uint8List(0), 'vuoto.png').toString(), 'image/png');
    });

    test('isPdfBytes recognises the %PDF- header only', () {
      expect(isPdfBytes(_pdf), isTrue);
      expect(isPdfBytes(_png), isFalse);
      expect(isPdfBytes(Uint8List(0)), isFalse);
    });

    test('the attachment limit is 4 MB, as agreed with the backend', () {
      expect(maxAttachmentBytes, 4 * 1024 * 1024);
    });
  });

  test('the chat upload sends the real content type on the file part (the bug we fixed)', () async {
    late String body;
    final client = MockClient((request) async {
      body = utf8.decode(request.bodyBytes, allowMalformed: true);
      return http.Response('{"attachment": {"id": "att-1"}}', 200);
    });

    await HttpChatAttachmentRemoteDataSource(client: client)
        .upload(petId: 'pet-1', imageBytes: _png, fileName: 'foto.png');

    expect(body, contains('name="file"; filename="foto.png"'));
    expect(body, contains('content-type: image/png'));
    expect(body, isNot(contains('application/octet-stream')));
  });

  test('a PDF is declared as application/pdf even when the name says .bin', () async {
    late String body;
    final client = MockClient((request) async {
      body = utf8.decode(request.bodyBytes, allowMalformed: true);
      return http.Response('{"attachment": {"id": "att-2"}}', 200);
    });

    await HttpChatAttachmentRemoteDataSource(client: client)
        .upload(petId: 'pet-1', imageBytes: _pdf, fileName: 'referto.bin');

    expect(body, contains('content-type: application/pdf'));
  });

  group('pre-upload validation', () {
    test('a file over 4 MB is rejected before any request', () {
      final big = Uint8List(maxAttachmentBytes + 1);
      expect(attachmentValidationError(big, 'foto.jpg'), 'Il file è troppo grande (max 4 MB).');
    });

    test('a file exactly at 4 MB is allowed', () {
      final atLimit = Uint8List(maxAttachmentBytes);
      expect(attachmentValidationError(atLimit, 'foto.jpg'), isNull);
    });

    test('a .pdf that is not a PDF is rejected with a clear message', () {
      expect(
        attachmentValidationError(_png, 'referto.pdf'),
        'Questo file non sembra un PDF valido.',
      );
    });

    test('a real PDF passes validation', () {
      expect(attachmentValidationError(_pdf, 'referto.pdf'), isNull);
    });
  });

  group('backend rejections become clear Italian messages', () {
    Future<({String? code, String message})> failureFor(http.Response response) async {
      final client = MockClient((_) async => response);
      final result = await HttpChatAttachmentRemoteDataSource(client: client)
          .upload(petId: 'pet-1', imageBytes: _png, fileName: 'x.png');
      return result.fold(
        onSuccess: (_) => (code: null, message: ''),
        onFailure: (e) => (code: e.code, message: e.message),
      );
    }

    test('pdf_unreadable is reported with its stable code and an Italian message', () async {
      final failure = await failureFor(
        http.Response(
          jsonEncode({'detail': 'pdf_unreadable: file protetto da password'}),
          400,
        ),
      );
      expect(failure.code, 'pdf_unreadable');
      expect(failure.message, contains('protetto da password'));
    });

    test('attachment_too_large maps to the 4 MB message', () async {
      final failure = await failureFor(
        http.Response(jsonEncode({'detail': 'attachment_too_large: 5 MB'}), 400),
      );
      expect(failure.code, 'attachment_too_large');
      expect(failure.message, 'Il file è troppo grande (max 4 MB).');
    });

    test('a 413 from the platform is also a size error', () async {
      final failure = await failureFor(http.Response('Request Entity Too Large', 413));
      expect(failure.message, 'Il file è troppo grande (max 4 MB).');
    });

    test('an unknown 400 falls back to a generic retryable message', () async {
      final failure = await failureFor(http.Response('{"detail": "boh"}', 400));
      expect(failure.code, 'chat_attachment_http_400');
      expect(failure.message, 'Non sono riuscito a caricare il file. Riprova.');
    });

    test('being offline gives the offline message, not a generic error', () async {
      final client = MockClient((_) async => throw http.ClientException('no route to host'));
      final result = await HttpChatAttachmentRemoteDataSource(client: client)
          .upload(petId: 'pet-1', imageBytes: _png, fileName: 'x.png');
      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        'chat_attachment_offline',
      );
    });
  });
}
