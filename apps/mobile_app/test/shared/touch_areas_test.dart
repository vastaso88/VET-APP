import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/features/chat/data/chat_demo_store.dart';
import 'package:vet_app_mobile/features/chat/presentation/pages/chat_conversation_detail_page.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pets_list_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/widgets/min_tap_target.dart';

import '../features/chat/widgets/fake_dictation.dart';

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

/// The commands of the chat and the filters of Animali answer on 48 px, however
/// small they are drawn (test round, card X04).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChatDemoStore.instance.reset();
    PetDemoStore.instance.reset();
  });
  tearDown(() => ChatDemoStore.instance.reset());

  testWidgets('a filter of Animali answers 6 px under its drawn edge', (tester) async {
    await tester.pumpWidget(_app(const PetsListPage()));
    await tester.pump();

    final pill = find.ancestor(of: find.text('Gatto'), matching: find.byType(InkWell)).first;
    final target = find.ancestor(of: find.text('Gatto'), matching: find.byType(MinTapTarget));
    expect(tester.getSize(target).height, 48);
    expect(tester.getSize(pill).height, lessThan(44), reason: 'the pill keeps its look');

    Color? ground() {
      final box = tester.widget<Container>(
        find.ancestor(of: find.text('Gatto'), matching: find.byType(Container)).first,
      );
      return (box.decoration! as BoxDecoration).color;
    }

    final before = ground();
    final rect = tester.getRect(pill);
    await tester.tapAt(Offset(rect.center.dx, rect.bottom + 6));
    await tester.pump();
    expect(ground(), isNot(before), reason: 'now it is the chosen one');
  });

  testWidgets('"+", microphone and send of the chat: 48 px to touch', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ChatComposer(
            hintText: 'Scrivi',
            petName: 'Rex',
            dictation: FakeDictation(),
            onSend: (text, {attachmentId, attachmentImageBytes}) {},
          ),
        ),
      ),
    );
    await tester.pump();

    for (final icon in [
      Icons.add_rounded,
      Icons.mic_none_rounded,
      Icons.arrow_upward_rounded,
    ]) {
      final button = find.widgetWithIcon(IconButton, icon);
      expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(48), reason: '$icon');
    }
  });

  testWidgets('the back arrow of the chat: 48 px to touch', (tester) async {
    final conversation =
        ChatDemoStore.instance.startConversation(petId: 'rex', petName: 'Rex');
    await tester.pumpWidget(
      _app(
        ChatConversationDetailPage(
          conversationId: conversation.id,
          initialConversation: conversation,
          noticeGate: (_) async => true,
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final back = find.widgetWithIcon(IconButton, Icons.arrow_back_rounded);
    expect(tester.getSize(back).shortestSide, greaterThanOrEqualTo(48));
  });
}
