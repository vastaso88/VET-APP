import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/chat/data/chat_demo_store.dart';
import 'package:vet_app_mobile/features/chat/data/chat_seed_data.dart';
import 'package:vet_app_mobile/features/chat/domain/chat_models.dart';
import 'package:vet_app_mobile/features/chat/presentation/pages/chat_conversation_detail_page.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_ai_notice.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

/// AI Act, art. 50: the owner is told they talk to an artificial intelligence.
/// The notice sits under the title in every state of the chat screen, so it
/// is there on a conversation already under way as well as on a new one.
void main() {
  const notice = "Rispondo con un'intelligenza artificiale: non sostituisco il veterinario. "
      'In emergenza chiama subito una clinica.';

  testWidgets('the notice is on screen for a conversation already under way', (tester) async {
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

    expect(find.byType(ChatAiNotice), findsOneWidget);
    expect(find.text(notice), findsOneWidget);
  });

  testWidgets('the notice is on screen before the first message too', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ChatDemoStore.instance.reset();

    await tester.pumpWidget(
      MaterialApp(
        home: ChatConversationDetailPage(
          conversationId: ChatSeedData.detail.id,
          initialConversation: ChatSeedData.detail,
          state: ChatScreenState.empty,
        ),
      ),
    );
    await tester.pump();

    expect(find.text(notice), findsOneWidget);
  });

  testWidgets('the notice follows the language of the app', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ChatAiNotice()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('künstlichen Intelligenz'), findsOneWidget);
    expect(find.textContaining('Rufen Sie'), findsOneWidget);
  });
}
