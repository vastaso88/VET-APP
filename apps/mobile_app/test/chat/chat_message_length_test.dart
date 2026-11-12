import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/chat/data/chat_remote_data_source.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_composer.dart';

/// The chat accepts messages up to [chatMaxMessageLength] characters: the
/// field stops there and says so, and a refusal from the backend reads as a
/// clear message, not as "could not reach the assistant".
void main() {
  testWidgets('the field stops at the limit and says why', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatComposer(hintText: 'Scrivi', petName: 'Rex')),
      ),
    );

    await tester.enterText(find.byType(TextField), 'a' * (chatMaxMessageLength + 500));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, chatMaxMessageLength);
    expect(find.textContaining('Hai raggiunto il limite di'), findsOneWidget);
  });

  testWidgets('below the limit there is no warning', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatComposer(hintText: 'Scrivi', petName: 'Rex')),
      ),
    );

    await tester.enterText(find.byType(TextField), 'ciao');
    await tester.pump();

    expect(find.textContaining('Hai raggiunto il limite di'), findsNothing);
  });

  test("the backend's length refusal becomes a clear, non-retryable error", () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'detail': [
            {
              'type': 'string_too_long',
              'loc': ['body', 'user_message'],
              'msg': 'String should have at most 8000 characters',
            },
          ],
        }),
        422,
      ),
    );
    final remote = HttpChatRemoteDataSource(client: client);

    final result = await remote.sendMessage(petId: 'p1', userMessage: 'x');

    result.fold(
      onSuccess: (_) => fail('expected a failure'),
      onFailure: (error) {
        expect(error.code, 'chat_message_too_long');
        expect(error.message, contains('troppo lungo'));
        expect(error.message, contains('$chatMaxMessageLength'));
      },
    );
  });

  test('any other 422 keeps the generic error', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'detail': [
            {'type': 'missing', 'loc': ['body', 'pet_id']},
          ],
        }),
        422,
      ),
    );
    final remote = HttpChatRemoteDataSource(client: client);

    final result = await remote.sendMessage(petId: 'p1', userMessage: 'x');

    result.fold(
      onSuccess: (_) => fail('expected a failure'),
      onFailure: (error) => expect(error.code, 'chat_http_422'),
    );
  });
}
