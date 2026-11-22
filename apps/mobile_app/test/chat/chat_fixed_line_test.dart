import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/chat/data/chat_demo_store.dart';
import 'package:vet_app_mobile/features/chat/data/chat_seed_data.dart';
import 'package:vet_app_mobile/features/chat/domain/chat_models.dart';
import 'package:vet_app_mobile/features/chat/presentation/pages/chat_conversation_detail_page.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_fixed_line.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

/// docs/compliance/22 §2: under the writing field, always, the line that says an AI
/// answers and can be wrong and that the app does not handle emergencies.
void main() {
  const line =
      "Risponde un'IA e può sbagliare. Non gestisce le urgenze: nel dubbio, chiama il veterinario.";

  testWidgets('the fixed line sits under the writing field', (tester) async {
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

    expect(find.byType(ChatFixedLine), findsOneWidget);
    expect(find.text(line), findsOneWidget);
    final composerBottom = tester.getBottomLeft(find.byType(ChatComposer)).dy;
    final lineTop = tester.getTopLeft(find.byType(ChatFixedLine)).dy;
    expect(lineTop, greaterThanOrEqualTo(composerBottom));
  });

  testWidgets('where there is no writing field there is no line under it', (tester) async {
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

    // The empty state has a button, not a writing field: the top notice stays, the
    // line under the field appears with the field.
    expect(find.byType(ChatComposer), findsNothing);
    expect(find.byType(ChatFixedLine), findsNothing);
  });

  testWidgets('it follows the language of the app', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ChatFixedLine()),
      ),
    );

    expect(find.textContaining('nicht für Notfälle zuständig'), findsOneWidget);
    expect(find.text(line), findsNothing);
  });
}
