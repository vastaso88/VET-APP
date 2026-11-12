import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/app/launch/warm_start_store.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_composer.dart';

class _FakeRecorder extends Fake implements AudioRecorder {
  @override
  Future<void> dispose() async {}
}

Future<void> _pump(WidgetTester tester, {String? draftKey, void Function(String, {String? attachmentId, dynamic attachmentImageBytes})? onSend}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChatComposer(
          hintText: 'Scrivi',
          petName: 'Rex',
          recorder: _FakeRecorder(),
          draftKey: draftKey,
          onSend: onSend == null ? null : (text, {attachmentId, attachmentImageBytes}) => onSend(text),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('typed text is saved for the conversation and comes back after a restart',
      (tester) async {
    await _pump(tester, draftKey: 'conv-1');
    await tester.enterText(find.byType(TextField), 'ha vomitato due volte');
    await tester.pump(const Duration(milliseconds: 500));

    expect(await const WarmStartStore().loadDraft('conv-1'), 'ha vomitato due volte');

    // The process dies; a new run opens the same conversation.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, draftKey: 'conv-1');
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('ha vomitato due volte'), findsOneWidget);
  });

  testWidgets('another conversation does not get the draft', (tester) async {
    await const WarmStartStore().saveDraft('conv-1', 'bozza');
    await _pump(tester, draftKey: 'conv-2');
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('bozza'), findsNothing);
  });

  testWidgets('sending clears the draft', (tester) async {
    final sent = <String>[];
    await _pump(tester, draftKey: 'conv-1', onSend: (text, {attachmentId, attachmentImageBytes}) => sent.add(text));
    await tester.enterText(find.byType(TextField), 'ciao');
    await tester.pump(const Duration(milliseconds: 500));
    expect(await const WarmStartStore().loadDraft('conv-1'), 'ciao');

    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump(const Duration(milliseconds: 500));

    expect(sent, ['ciao']);
    expect(await const WarmStartStore().loadDraft('conv-1'), isNull);
  });

  testWidgets('without a key nothing is saved', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'ciao');
    await tester.pump(const Duration(milliseconds: 500));

    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
}
