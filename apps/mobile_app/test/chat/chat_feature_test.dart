import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/chat/data/chat_seed_data.dart';
import 'package:vet_app_mobile/features/chat/chat.dart';

void main() {
  testWidgets('shows seeded chat conversations', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatConversationsPage(),
      ),
    );

    expect(find.text('Le tue conversazioni con l assistente veterinario'),
        findsOneWidget);
    expect(find.text('Cocco - dieta e digestione'), findsOneWidget);
    expect(find.text('Luna - promemoria vaccino'), findsOneWidget);
  });

  testWidgets('renders empty chat state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatConversationsPage(
          state: ChatScreenState.empty,
          conversations: [],
        ),
      ),
    );

    expect(find.text('Nessuna conversazione ancora'), findsOneWidget);
    expect(find.text('Avvia la prima chat'), findsOneWidget);
  });

  testWidgets('renders conversation detail with composer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatConversationDetailPage(
          conversationId: ChatSeedData.detail.id,
        ),
      ),
    );

    expect(find.text('Cocco - dieta e digestione'), findsWidgets);
    expect(find.textContaining('Scrivi una domanda su Cocco'), findsOneWidget);
    expect(
        find.textContaining('Da ieri mangia meno del solito'), findsOneWidget);
  });
}
