import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/design_system/tokens/app_colors.dart';
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
  const line = "Risponde un'IA e può sbagliare. Non sostituisce il veterinario e non gestisce "
      'le urgenze: nel dubbio, chiamalo. Non scrivere dati sulla tua salute.';

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

    // Still there while the owner types: not about the person's own health (Anthropic's rules
    // for products minors may use, docs/compliance/08 point 57).
    await tester.enterText(find.byType(TextField), 'ho mal di testa');
    await tester.pump();
    expect(find.textContaining('dati sulla tua salute'), findsOneWidget);
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

    // The empty state has a button, not a writing field: the line appears with the field.
    expect(find.byType(ChatComposer), findsNothing);
    expect(find.byType(ChatFixedLine), findsNothing);
  });

  testWidgets('it is the only notice of the screen, readable and never cut', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ChatDemoStore.instance.reset();

    for (final locale in ['it', 'de', 'fr']) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: ChatConversationDetailPage(
            conversationId: ChatSeedData.detail.id,
            initialConversation: ChatSeedData.detail,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: locale);
      final text = tester.widget<Text>(find.byKey(const ValueKey('chat-fixed-line')));
      expect(text.style!.fontSize, greaterThanOrEqualTo(12));
      expect(text.style!.color, AppColors.secondaryText);
      expect(text.maxLines, isNull);
      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
    }
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
