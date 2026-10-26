import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/chat/data/chat_attachment_remote_data_source.dart';
import 'package:vet_app_mobile/features/chat/data/chat_remote_data_source.dart';
import 'package:vet_app_mobile/features/chat/data/speech_to_text_remote_data_source.dart';

/// A 429 "quota_exceeded" from the backend (a daily allowance of readings,
/// dictations or summaries used up) carries a sentence written for the user
/// in their language: the app shows that sentence, not its generic error.
const _sentence = 'You have used all 30 dictations available today. You can dictate again '
    'in about 12 hours; meanwhile you can type your message.';

http.Response _quotaResponse(String kind) => http.Response(
      jsonEncode({
        'detail': 'quota_exceeded: $_sentence',
        'code': 'quota_exceeded',
        'kind': kind,
        'limit': 30,
        'retry_after_seconds': 43200,
      }),
      429,
      headers: {'content-type': 'application/json'},
    );

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List<int>.filled(16, 0)]);

void main() {
  test('the quota sentence is read from the detail and nothing else', () {
    expect(quotaExceededMessage(_quotaResponse('dictation').body), _sentence);
    expect(quotaExceededMessage(jsonEncode({'detail': 'attachment_too_large: 20 MB'}), ),
        isNull);
    expect(quotaExceededMessage(jsonEncode({'detail': 'quota_exceeded:'})), isNull);
    expect(quotaExceededMessage('not json'), isNull);
  });

  test('dictation: the sentence replaces the generic transcription error', () async {
    final client = MockClient((request) async => _quotaResponse('dictation'));
    final remote = HttpSpeechToTextRemoteDataSource(client: client);

    final result = await remote.transcribe(
      audioBytes: Uint8List.fromList(List<int>.filled(32, 1)),
      fileName: 'a.wav',
    );

    result.fold(
      onSuccess: (_) => fail('expected a failure'),
      onFailure: (error) {
        expect(error.code, 'quota_exceeded');
        expect(error.message, _sentence);
      },
    );
  });

  test('attachments: the sentence replaces the generic upload error', () async {
    final client = MockClient((request) async => _quotaResponse('vision'));
    final remote = HttpChatAttachmentRemoteDataSource(client: client);

    final result = await remote.upload(petId: 'p1', imageBytes: _jpeg, fileName: 'foto.jpg');

    result.fold(
      onSuccess: (_) => fail('expected a failure'),
      onFailure: (error) {
        expect(error.code, 'quota_exceeded');
        expect(error.message, _sentence);
      },
    );
  });

  test('vet summary: the sentence replaces the generic summary error', () async {
    final client = MockClient((request) async => _quotaResponse('summary'));
    final remote = HttpChatRemoteDataSource(client: client);

    final result = await remote.conversationSummary('c1');

    result.fold(
      onSuccess: (_) => fail('expected a failure'),
      onFailure: (error) {
        expect(error.code, 'quota_exceeded');
        expect(error.message, _sentence);
      },
    );
  });

  test('the upload and dictation requests tell the backend the language', () async {
    final seen = <String?>[];
    final client = MockClient((request) async {
      seen.add(request.headers['Accept-Language'] ?? request.headers['accept-language']);
      return _quotaResponse('vision');
    });

    await HttpChatAttachmentRemoteDataSource(client: client)
        .upload(petId: 'p1', imageBytes: _jpeg, fileName: 'foto.jpg');
    await HttpSpeechToTextRemoteDataSource(client: client).transcribe(
      audioBytes: Uint8List.fromList(List<int>.filled(32, 1)),
      fileName: 'a.wav',
    );

    expect(seen, everyElement(isNotNull));
  });
}
