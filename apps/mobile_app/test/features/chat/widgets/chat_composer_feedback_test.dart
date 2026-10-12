import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import 'package:vet_app_mobile/features/chat/data/speech_to_text_remote_data_source.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

/// Build 28: while recording it must be obvious the app is listening, and
/// while transcribing that it is working.
class _FakeRecorder extends Fake implements AudioRecorder {
  _FakeRecorder({this.returnsFile = false});

  /// Whether stop() hands back the recording (then the composer goes on
  /// to transcribe it) or nothing (straight back to idle).
  final bool returnsFile;
  String? startedPath;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startedPath = path;
  }

  @override
  Future<String?> stop() async => returnsFile ? startedPath : null;

  @override
  Future<void> dispose() async {}
}

class _PendingSpeechToText implements SpeechToTextRemoteDataSource {
  final completer = Completer<Result<String>>();

  @override
  Future<Result<String>> transcribe({required Uint8List audioBytes, required String fileName}) =>
      completer.future;
}

Future<void> _pump(
  WidgetTester tester, {
  String? editingText,
  VoidCallback? onCancel,
  bool recorderReturnsFile = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChatComposer(
          hintText: 'Scrivi',
          petName: 'Rex',
          recorder: _FakeRecorder(returnsFile: recorderReturnsFile),
          speechToText: _PendingSpeechToText(),
          recordingPathProvider: () async => '/tmp/chat-voice-test.m4a',
          editingText: editingText,
          onCancelEditing: onCancel,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('while recording it says it is listening and counts the time', (tester) async {
    await _pump(tester);

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();

    expect(find.text(ChatComposer.listeningText), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    expect(find.text('0:07'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    expect(find.text('1:07'), findsOneWidget);
  });

  testWidgets('tapping the listening banner stops the recording', (tester) async {
    await _pump(tester);
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();

    await tester.tap(find.text(ChatComposer.listeningText));
    await tester.pump();

    expect(find.text(ChatComposer.listeningText), findsNothing);
    // The fake recorder returns no file: straight back to idle.
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });

  testWidgets('after stopping it says it is transcribing, and the timer stops', (tester) async {
    await _pump(tester, recorderReturnsFile: true);
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byIcon(Icons.stop_circle_rounded));
    await tester.pump();

    // Reading the clip is real file I/O, which never completes under the
    // test clock: the composer stays in "transcribing", which is the point.
    expect(find.text(ChatComposer.transcribingText), findsOneWidget);
    expect(find.text(ChatComposer.listeningText), findsNothing);
    expect(find.text('0:03'), findsNothing);
  });

  testWidgets('editing puts the text in the field and can be cancelled', (tester) async {
    var cancelled = false;
    await _pump(tester);

    await _pump(tester, editingText: 'mastica le scarpe', onCancel: () => cancelled = true);
    await tester.pump();

    expect(find.text(ChatComposer.editingLabel), findsOneWidget);
    expect(find.text('mastica le scarpe'), findsOneWidget);

    await tester.tap(find.byTooltip('Annulla modifica'));
    await tester.pump();

    expect(cancelled, isTrue);
    expect(find.text('mastica le scarpe'), findsNothing);
  });
}
