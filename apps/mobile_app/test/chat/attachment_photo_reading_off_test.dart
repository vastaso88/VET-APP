import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/chat/data/chat_attachment_remote_data_source.dart';

/// Photos saved but not read (server `photo_reading: false`, docs/compliance/19):
/// the app tells it apart from a reading that failed.
void main() {
  final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]);

  Future<ChatAttachmentUploadResult> upload(Map<String, Object?> body) async {
    final client = MockClient((request) async => http.Response(jsonEncode(body), 200));
    final result = await HttpChatAttachmentRemoteDataSource(client: client)
        .upload(petId: 'pet-1', imageBytes: png, fileName: 'foto.png');
    return result.fold(onSuccess: (value) => value, onFailure: (error) => throw error);
  }

  test('photo_reading false means photos are off, not a failure', () async {
    final result = await upload({
      'attachment': {'id': 'a1', 'analysis': null, 'analysis_failed': true},
      'photo_reading': false,
    });
    expect(result.analysisFailed, isTrue);
    expect(result.photoReadingOff, isTrue);
  });

  test('an older server without the field reads as photos on', () async {
    final result = await upload({
      'attachment': {'id': 'a1', 'analysis': 'ok', 'analysis_failed': false},
    });
    expect(result.photoReadingOff, isFalse);
  });
}
