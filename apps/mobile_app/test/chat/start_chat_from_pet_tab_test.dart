import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/design_system/tokens/app_colors.dart';
import 'package:vet_app_mobile/features/chat/data/chat_demo_store.dart';
import 'package:vet_app_mobile/features/chat/presentation/pages/chat_conversation_detail_page.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_detail_page.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

const _pet = PetProfile(
  id: 'tobia',
  name: 'Tobia',
  species: 'Gatto',
  breed: '',
  birthDateLabel: '',
  sex: 'Maschio',
  weightLabel: '',
  medicalNote: '',
  healthBadge: '',
  nextVisitLabel: '',
  avatarEmoji: 'T',
  accentColor: AppIdentityColors.tintAmber,
  identityColor: AppIdentityColors.amber,
);

/// The pet's Chat tab goes through the same way in as "Chiedi a Quokka" of Home
/// (start_chat.dart): what it did before must not change.
Future<void> _openChatTab(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale('it'),
    home: PetDetailPage(pet: _pet, initialTab: 1),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tapNewChat(WidgetTester tester) async {
  await tester.tap(find.text('Nuova chat'));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChatDemoStore.instance.reset();
  });
  tearDown(() => ChatDemoStore.instance.reset());

  testWidgets('"Nuova chat" opens a new chat about that animal', (tester) async {
    await _openChatTab(tester);
    await _tapNewChat(tester);

    final page = tester.widget<ChatConversationDetailPage>(
      find.byType(ChatConversationDetailPage),
    );
    expect(page.initialConversation?.petId, 'tobia');
    expect(ChatDemoStore.instance.countForPet('tobia'), 1);
  });

  testWidgets('at the limit it says so and opens nothing', (tester) async {
    for (var i = 0; i < ChatDemoStore.maxConversationsPerPet; i++) {
      ChatDemoStore.instance.startConversation(petId: 'tobia', petName: 'Tobia');
    }
    await _openChatTab(tester);
    await _tapNewChat(tester);

    expect(find.text('Limite chat raggiunto'), findsOneWidget);
    expect(find.byType(ChatConversationDetailPage), findsNothing);
    expect(
      ChatDemoStore.instance.countForPet('tobia'),
      ChatDemoStore.maxConversationsPerPet,
    );
  });
}
