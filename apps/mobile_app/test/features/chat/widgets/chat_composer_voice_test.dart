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

  bool requestedPermission = false;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    if (request) requestedPermission = true;
    return permission;
  }

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

  testWidgets('senza permesso prima si spiega a cosa serve; rifiutato dal sistema: messaggio',
      (tester) async {
    final recorder = _FakeRecorder(permission: false);
    await _pump(tester, recorder);

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pumpAndSettle();

    // Prima della richiesta di sistema: perché, e cosa succede se si rifiuta.
    expect(find.text('Usare il microfono?'), findsOneWidget);
    expect(find.textContaining('dettare i messaggi nella chat'), findsOneWidget);
    expect(find.textContaining('scrivere i messaggi con la tastiera'), findsOneWidget);
    expect(recorder.requestedPermission, isFalse);

    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();

    expect(recorder.requestedPermission, isTrue);
    expect(find.text('Serve il permesso per usare il microfono.'), findsOneWidget);
    expect(recorder.startedPath, isNull);
  });

  testWidgets('"Non ora" non fa partire nessuna richiesta di sistema', (tester) async {
    final recorder = _FakeRecorder(permission: false);
    await _pump(tester, recorder);

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non ora'));
    await tester.pumpAndSettle();

    expect(recorder.requestedPermission, isFalse);
    expect(recorder.startedPath, isNull);
    // Si può riprovare: il microfono torna disponibile.
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });

  testWidgets('con il permesso già dato non compare nessuna spiegazione', (tester) async {
    final recorder = _FakeRecorder();
    await _pump(tester, recorder);

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();

    expect(find.text('Usare il microfono?'), findsNothing);
    expect(recorder.startedPath, isNotNull);
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
