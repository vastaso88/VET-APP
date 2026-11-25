import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/chat/data/chat_seed_data.dart';
import 'package:vet_app_mobile/features/chat/presentation/pages/chat_conversation_detail_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

Future<void> _open(WidgetTester tester, {required bool serverConfigured}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const ValueKey('open'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChatConversationDetailPage(
                  conversationId: 'a-deleted-chat',
                  serverConfigured: serverConfigured,
                ),
              ),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('with a server, an unknown conversation is "not found", with the way back',
      (tester) async {
    await _open(tester, serverConfigured: true);

    expect(find.text('Conversazione non trovata'), findsOneWidget);
    // Not the sample conversation of the demo.
    expect(find.text(ChatSeedData.detail.petName), findsNothing);
    expect(find.text(ChatSeedData.detail.title), findsNothing);

    await tester.tap(find.byKey(const ValueKey('chat-conversation-not-found-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
  });

  testWidgets('without a server (the demo) the sample conversation stands in', (tester) async {
    await _open(tester, serverConfigured: false);

    expect(find.text('Conversazione non trovata'), findsNothing);
    expect(find.textContaining(ChatSeedData.detail.petName), findsWidgets);
  });
}
