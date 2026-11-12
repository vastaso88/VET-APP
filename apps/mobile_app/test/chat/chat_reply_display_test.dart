import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/chat/data/chat_demo_store.dart';
import 'package:vet_app_mobile/features/chat/data/chat_seed_data.dart';
import 'package:vet_app_mobile/features/chat/presentation/pages/chat_conversation_detail_page.dart';

/// Build 26: the answer appears in one go (no letter-by-letter reveal), the
/// list keeps its start in view, and a slow answer says so instead of
/// leaving the owner wondering.
void main() {
  group('chatReplyScrollOffset', () {
    test('a long reply starts a third of the way down the screen', () {
      final offset = chatReplyScrollOffset(
        replyTop: 1200,
        viewportExtent: 600,
        minScrollExtent: 0,
        maxScrollExtent: 2400,
      );

      expect(offset, 1000);
    });

    test('a reply that fits below that point just ends at the bottom', () {
      final offset = chatReplyScrollOffset(
        replyTop: 1200,
        viewportExtent: 600,
        minScrollExtent: 0,
        maxScrollExtent: 900,
      );

      expect(offset, 900);
    });

    test('never scrolls above the start of the list', () {
      final offset = chatReplyScrollOffset(
        replyTop: 100,
        viewportExtent: 600,
        minScrollExtent: 0,
        maxScrollExtent: 2400,
      );

      expect(offset, 0);
    });
  });

  testWidgets('a slow answer is announced, not left as a silent wait', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatTypingBubble(slowAfter: Duration(seconds: 12))),
      ),
    );

    expect(find.text(ChatTypingBubble.typingText), findsOneWidget);

    await tester.pump(const Duration(seconds: 13));

    expect(find.text(ChatTypingBubble.slowText), findsOneWidget);
  });

  testWidgets('the reply appears in full as soon as it arrives', (tester) async {
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

    await tester.enterText(find.byType(TextField), "com'è l'appetito?");
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    expect(find.text(ChatTypingBubble.typingText), findsOneWidget);
    // The demo backend answers after 650 ms.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    // The bubble renders a RichText; the whole sentence is there in a single
    // frame, not revealed a few letters at a time.
    expect(
      find.textContaining(
        'per le prossime 24 ore. Se peggiora, meglio sentire il veterinario.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text(ChatTypingBubble.typingText), findsNothing);
  });
}
