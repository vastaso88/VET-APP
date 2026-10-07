import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import 'package:vet_app_mobile/features/chat/data/speech_to_text_remote_data_source.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

class _FakeRecorder extends Fake implements AudioRecorder {
  _FakeRecorder({this.permission = true, this.startError, this.stopError});

  final bool permission;
  final Object? startError;
  final Object? stopError;
  String? startedPath;
  RecordConfig? startedConfig;

  @override
  Future<bool> hasPermission({bool request = true}) async => permission;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    if (startError != null) throw startError!;
    startedConfig = config;
    startedPath = path;
  }

  @override
  Future<String?> stop() async {
    if (stopError != null) throw stopError!;
    return startedPath;
  }

  @override
  Future<void> dispose() async {}
}

class _NeverCalledSpeechToText implements SpeechToTextRemoteDataSource {
  @override
  Future<Result<String>> transcribe({required Uint8List audioBytes, required String fileName}) {
    throw StateError('should not be reached');
  }
}

Future<void> _pump(WidgetTester tester, _FakeRecorder recorder) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChatComposer(
          hintText: 'Scrivi',
          petName: 'Rex',
          recorder: recorder,
          speechToText: _NeverCalledSpeechToText(),
          recordingPathProvider: () async => '/tmp/chat-voice-test.m4a',
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('il microfono parte con un percorso assoluto e il registratore non va in crash',
      (tester) async {
    final recorder = _FakeRecorder();
    await _pump(tester, recorder);

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();

    expect(recorder.startedPath, '/tmp/chat-voice-test.m4a');
    expect(find.byIcon(Icons.stop_circle_rounded), findsOneWidget);
  });

  testWidgets('se il registratore non parte mostra un messaggio invece di rompere l\'app',
      (tester) async {
    final recorder = _FakeRecorder(startError: Exception('prepare failed'));
    await _pump(tester, recorder);

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();

    expect(find.text('Non riesco ad avviare il microfono. Riprova.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Back to idle: the mic can be tapped again.
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });

  testWidgets('permesso negato: messaggio dedicato, nessun avvio', (tester) async {
    final recorder = _FakeRecorder(permission: false);
    await _pump(tester, recorder);

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();

    expect(find.text('Serve il permesso per usare il microfono.'), findsOneWidget);
    expect(recorder.startedPath, isNull);
  });

  testWidgets('se lo stop fallisce torna a riposo con un messaggio', (tester) async {
    final recorder = _FakeRecorder(stopError: Exception('stop failed'));
    await _pump(tester, recorder);

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.stop_circle_rounded));
    await tester.pump();

    expect(find.text('La registrazione non è andata a buon fine. Riprova.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });
}
