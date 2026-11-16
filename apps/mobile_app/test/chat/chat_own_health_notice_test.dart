import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_composer.dart';

/// Next to the text field, always: the chat is about the animal, not the
/// person's own health (Anthropic's rules for products minors may use,
/// docs/compliance/08 point 57).
void main() {
  testWidgets('the composer says not to write about your own health', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatComposer(hintText: 'Scrivi', petName: 'Rex')),
      ),
    );

    expect(find.byKey(const ValueKey('chat-own-health-notice')), findsOneWidget);
    expect(find.textContaining('dati sulla tua salute'), findsOneWidget);

    // Still there while the owner types.
    await tester.enterText(find.byType(TextField), 'ho mal di testa');
    await tester.pump();
    expect(find.textContaining('dati sulla tua salute'), findsOneWidget);
  });
}
