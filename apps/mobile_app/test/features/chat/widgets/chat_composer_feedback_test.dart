import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_composer.dart';

import 'fake_dictation.dart';

/// Build 28: while listening it must be obvious that the app is listening, and
/// after that that it is working.
Future<FakeDictation> _pump(
  WidgetTester tester, {
  String? editingText,
  VoidCallback? onCancel,
}) async {
  final dictation = FakeDictation();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChatComposer(
          hintText: 'Scrivi',
          petName: 'Rex',
          dictation: dictation,
          editingText: editingText,
          onCancelEditing: onCancel,
        ),
      ),
    ),
  );
  await tester.pump();
  return dictation;
}

Future<void> _tapMic(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.mic_none_rounded));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('while listening it says so and counts the time', (tester) async {
    await _pump(tester);
    await _tapMic(tester);

    expect(find.text(ChatComposer.listeningText), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    expect(find.text('0:07'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    expect(find.text('1:07'), findsOneWidget);
  });

  testWidgets('tapping the listening banner stops the dictation', (tester) async {
    final dictation = await _pump(tester);
    await _tapMic(tester);

    await tester.tap(find.text(ChatComposer.listeningText));
    await tester.pump();

    expect(dictation.stopped, isTrue);
    expect(find.text(ChatComposer.listeningText), findsNothing);
    dictation.hear('ciao');
    await tester.pump();
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });

  testWidgets('after stopping it says it is transcribing, and the timer stops', (tester) async {
    await _pump(tester);
    await _tapMic(tester);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byIcon(Icons.stop_circle_rounded));
    await tester.pump();

    expect(find.text(ChatComposer.transcribingText), findsOneWidget);
    expect(find.text(ChatComposer.listeningText), findsNothing);
    expect(find.text('0:03'), findsNothing);
  });

  testWidgets('a silence the phone decided ends the listening on screen too', (tester) async {
    final dictation = await _pump(tester);
    await _tapMic(tester);

    dictation.close();
    await tester.pump();

    expect(find.text(ChatComposer.listeningText), findsNothing);
    expect(find.text(ChatComposer.transcribingText), findsOneWidget);
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
