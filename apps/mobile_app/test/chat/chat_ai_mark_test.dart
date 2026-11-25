import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/chat/domain/chat_models.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

Future<void> _show(WidgetTester tester, ChatMessageAuthor author, {bool ai = false}) =>
    tester.pumpWidget(MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChatMessageBubble(
          message: ChatMessage(
            id: 'm-1',
            author: author,
            text: 'Testo del messaggio',
            timeLabel: 'ieri',
            aiGenerated: ai,
          ),
        ),
      ),
    ));

void main() {
  testWidgets('a reply carries only "Generato da IA": no date, no time', (tester) async {
    await _show(tester, ChatMessageAuthor.assistant, ai: true);
    expect(find.text('Generato da IA'), findsOneWidget);
    expect(find.text('ieri'), findsNothing);
  });

  testWidgets('the owner keeps the time of their own messages', (tester) async {
    await _show(tester, ChatMessageAuthor.user);
    expect(find.text('ieri'), findsOneWidget);
    expect(find.text('Generato da IA'), findsNothing);
  });
}
