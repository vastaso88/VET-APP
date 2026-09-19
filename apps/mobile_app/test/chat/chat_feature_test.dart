import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/chat/data/chat_seed_data.dart';
import 'package:vet_app_mobile/features/chat/chat.dart';

/// The conversation list and the empty state both need more vertical room
/// than the default 800x600 test surface: ListView only materializes
/// widgets within its viewport (+ cache extent), so anything below the
/// fold simply isn't in the widget tree yet, and the empty-state
/// illustration overflows a too-short viewport. A taller surface avoids
/// both without coupling the test to scrolling mechanics.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('shows seeded chat conversations', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatConversationsPage(),
      ),
    );

    expect(find.text('Moka e le sue conversazioni'), findsOneWidget);
    expect(find.text('Moka - appetito e controllo'), findsOneWidget);
    expect(find.text('Moka - promemoria vaccino'), findsOneWidget);
    expect(find.text('Moka - referto visita'), findsOneWidget);
  });

  testWidgets('renders empty chat state', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatConversationsPage(
          state: ChatScreenState.empty,
          conversations: [],
        ),
      ),
    );

    expect(find.text('Nessuna conversazione ancora'), findsOneWidget);
    expect(find.text('Apri la prima chat'), findsOneWidget);
  });

  testWidgets('renders conversation detail with composer', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatConversationDetailPage(
          conversationId: ChatSeedData.detail.id,
          initialConversation: ChatSeedData.detail,
        ),
      ),
    );

    expect(find.text('Moka - appetito e controllo'), findsWidgets);
    expect(find.textContaining('Scrivi una domanda su Moka'), findsOneWidget);
    expect(
        find.textContaining('Da ieri mangia meno del solito'), findsOneWidget);
  });
}
