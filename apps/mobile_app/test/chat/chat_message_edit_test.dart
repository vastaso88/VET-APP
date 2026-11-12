import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/chat/data/chat_demo_store.dart';
import 'package:vet_app_mobile/features/chat/data/chat_seed_data.dart';
import 'package:vet_app_mobile/features/chat/presentation/pages/chat_conversation_detail_page.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_composer.dart';

/// Build 28: a sent message can be edited; the conversation is cut there
/// and the assistant answers the edited text.
void main() {
  Future<void> openChat(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ChatDemoStore.instance.reset();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatConversationDetailPage(
          conversationId: ChatSeedData.detail.id,
          initialConversation: ChatSeedData.detail,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    // The demo backend answers after 650 ms.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
  }

  testWidgets('editing a message replaces it and its answer', (tester) async {
    await openChat(tester);
    await send(tester, "com'è l'appetito?");
    expect(find.textContaining('per le prossime 24 ore', findRichText: true), findsOneWidget);

    await tester.longPress(find.text("com'è l'appetito?"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifica messaggio'));
    await tester.pumpAndSettle();

    expect(find.text(ChatComposer.editingLabel), findsOneWidget);
    // The text is back in the field (and still in the bubble until sent).
    expect(find.text("com'è l'appetito?"), findsNWidgets(2));

    await send(tester, 'sta perdendo peso?');

    expect(find.text("com'è l'appetito?"), findsNothing);
    expect(find.textContaining('per le prossime 24 ore', findRichText: true), findsNothing);
    expect(find.text('sta perdendo peso?'), findsOneWidget);
    expect(find.textContaining('Sul peso di', findRichText: true), findsOneWidget);
    expect(find.text(ChatComposer.editingLabel), findsNothing);
  });

  testWidgets("the assistant's messages have no edit action", (tester) async {
    await openChat(tester);
    await send(tester, "com'è l'appetito?");

    await tester.longPress(find.textContaining('per le prossime 24 ore', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('Modifica messaggio'), findsNothing);
  });
}
