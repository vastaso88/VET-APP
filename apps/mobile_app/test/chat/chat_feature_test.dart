import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/chat/data/chat_seed_data.dart';
import 'package:vet_app_mobile/features/chat/chat.dart';

/// The empty state illustration overflows a too-short viewport, and some
/// content needs more vertical room than the default 800x600 test surface.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
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
