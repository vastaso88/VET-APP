import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/pets/data/medical_record_consent_remote_data_source.dart';

void main() {
  test('PUTs the decision to the per-pet endpoint with a JSON body', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('{"ok": true}', 200);
    });

    final result = await MedicalRecordConsentRemoteDataSource(client: client)
        .setGranted(petId: 'pet-1', granted: true);

    expect(captured.method, 'PUT');
    expect(captured.url.path, endsWith('/pets/pet-1/medical-record-consent'));
    expect(jsonDecode(captured.body), {'granted': true});
    expect(captured.headers['Content-Type'], 'application/json');
    expect(result.fold(onSuccess: (v) => v, onFailure: (_) => null), isTrue);
  });

  test('a declined decision is sent as granted=false and echoed back', () async {
    final client = MockClient((_) async => http.Response('{}', 200));

    final result = await MedicalRecordConsentRemoteDataSource(client: client)
        .setGranted(petId: 'pet-1', granted: false);

    expect(result.fold(onSuccess: (v) => v, onFailure: (_) => null), isFalse);
  });

  test('a server error becomes a failure and is not reported as saved', () async {
    final client = MockClient((_) async => http.Response('boom', 500));

    final result = await MedicalRecordConsentRemoteDataSource(client: client)
        .setGranted(petId: 'pet-1', granted: true);

    expect(
      result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
      'medical_record_consent_http_500',
    );
  });

  test('being offline becomes a failure with a clear offline code', () async {
    final client = MockClient((_) async => throw const SocketLikeException());

    final result = await MedicalRecordConsentRemoteDataSource(client: client)
        .setGranted(petId: 'pet-1', granted: true);

    expect(
      result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
      'medical_record_consent_offline',
    );
  });

  testWidgets('a timeout becomes a failure with a timeout code', (tester) async {
    final client = MockClient((_) => Completer<http.Response>().future);

    final pending = MedicalRecordConsentRemoteDataSource(client: client)
        .setGranted(petId: 'pet-1', granted: true);
    await tester.pump(const Duration(seconds: 16));
    final result = await pending;

    expect(
      result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
      'medical_record_consent_timeout',
    );
  });
}

class SocketLikeException implements Exception {
  const SocketLikeException();
}
