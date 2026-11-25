import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/tokens/app_colors.dart';
import 'package:vet_app_mobile/features/chat/data/chat_demo_store.dart';
import 'package:vet_app_mobile/features/chat/presentation/example_questions.dart';
import 'package:vet_app_mobile/features/chat/presentation/pages/chat_conversation_detail_page.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

const _languages = ['it', 'en', 'es', 'de', 'fr'];

/// Every kind of animal the app knows (species, breed).
const _animals = <(String, String)>[
  ('Cane', 'Labrador Retriever'),
  ('Gatto', ''),
  ('Piccoli mammiferi', 'Coniglio nano'),
  ('Piccoli mammiferi', 'Criceto dorato'),
  ('Uccello', 'Cocorita'),
  ('Altro', 'Gallina'),
  ('Rettili e anfibi', 'Drago barbuto'),
  ('Rettili e anfibi', 'Axolotl'),
  ('Pesce', 'Guppy'),
  ('Altro', 'Capra'),
  ('Altro', 'Tarantola'),
  ('Altro', ''),
];

PetProfile _pet({
  String species = 'Gatto',
  String breed = '',
  bool memorial = false,
}) =>
    PetProfile(
      id: 'tobia',
      name: 'Tobia',
      species: species,
      breed: breed,
      birthDateLabel: '',
      sex: 'Maschio',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'T',
      accentColor: AppIdentityColors.tintAmber,
      identityColor: AppIdentityColors.amber,
      isMemorial: memorial,
    );

/// Opens a new chat and gives back its id.
Future<String> _openNewChat(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double text = 1,
  String species = 'Gatto',
  bool memorial = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final pets = PetDemoStore.instance..reset();
  pets.debugOwnerId = () => 'owner';
  pets.debugFetchRows = (_) async => [
        pets.petToRow(_pet(species: species, memorial: memorial), 'owner'),
      ];
  addTearDown(() {
    pets
      ..debugOwnerId = null
      ..debugFetchRows = null
      ..reset();
  });
  await pets.ensureHydrated();

  final conversation =
      ChatDemoStore.instance.startConversation(petId: 'tobia', petName: 'Tobia');
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: ChatConversationDetailPage(
        conversationId: conversation.id,
        initialConversation: conversation,
        noticeGate: (_) async => true,
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return conversation.id;
}

String _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChatDemoStore.instance.reset();
  });
  tearDown(() => ChatDemoStore.instance.reset());

  group('the questions', () {
    for (final language in _languages) {
      test('$language: three for every animal, all different, no horse, no urgency, no doses', () {
        final l10n = lookupAppLocalizations(Locale(language));
        final banned = RegExp(
          'cavall|horse|caball|pferd|cheval|urgen|emerg|notfall|veter|tierarzt|'
          'farmac|medic|arznei|médic|dose|dosi|dosis|mg\\b',
          caseSensitive: false,
        );
        for (final (species, breed) in _animals) {
          final questions = exampleQuestionsFor(
            l10n,
            petName: 'Tobia',
            pet: _pet(species: species, breed: breed),
          );
          expect(questions.toSet(), hasLength(3), reason: '$species $breed');
          for (final question in questions) {
            expect(question, endsWith('?'));
            expect(question, isNot(contains(banned)));
            expect(question, isNot(contains('{')));
          }
        }
        // A chat whose animal is no longer there.
        expect(exampleQuestionsFor(l10n, petName: 'Tobia'), hasLength(3));
      });
    }

    test('French: a non-breaking space before the question mark', () {
      final l10n = lookupAppLocalizations(const Locale('fr'));
      for (final (species, breed) in _animals) {
        for (final question in exampleQuestionsFor(
          l10n,
          petName: 'Tobia',
          pet: _pet(species: species, breed: breed),
        )) {
          expect(question, endsWith(' ?'));
        }
      }
    });

    test('they change with the kind of animal', () {
      final l10n = lookupAppLocalizations(const Locale('it'));
      List<String> of(String species) =>
          exampleQuestionsFor(l10n, petName: 'Tobia', pet: _pet(species: species));
      expect(of('Cane').first, contains('guinzaglio'));
      expect(of('Gatto').last, contains('lettiera'));
      expect(of('Pesce').first, contains('acquario'));
    });
  });

  testWidgets('a tap writes the question in the field and sends nothing', (tester) async {
    final id = await _openNewChat(tester);
    final l10n = lookupAppLocalizations(const Locale('it'));
    final question = l10n.chatExampleScratching('Tobia');

    expect(_field(tester), '');
    await tester.tap(find.text(question));
    await tester.pump();

    expect(_field(tester), question);
    expect(
      ChatDemoStore.instance.conversationById(id)!.messages,
      isEmpty,
      reason: 'the owner sends it',
    );
    // Another one can be picked instead.
    await tester.tap(find.text(l10n.chatExampleLitterBox));
    await tester.pump();
    expect(_field(tester), l10n.chatExampleLitterBox);
    // The draft is saved a moment later.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('they step aside when the owner writes, and come back with an empty field',
      (tester) async {
    await _openNewChat(tester);
    final question =
        lookupAppLocalizations(const Locale('it')).chatExampleScratching('Tobia');

    await tester.enterText(find.byType(TextField), 'Perché dorme tanto?');
    await tester.pump();
    expect(find.text(question), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text(question), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an animal in Ricordi: no question to write, there is no field', (tester) async {
    await _openNewChat(tester, memorial: true);
    expect(find.byKey(const ValueKey('chat-memorial-read-only')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.north_west_rounded), findsNothing);
  });

  for (final (size, text) in const [(Size(320, 780), 1.3), (Size(360, 640), 1.0)]) {
    testWidgets('${size.width.round()} px, text $text: no overflow, 48 px to touch, all reachable',
        (tester) async {
      await _openNewChat(tester, size: size, text: text, species: 'Cane');
      expect(tester.takeException(), isNull);
      final l10n = lookupAppLocalizations(const Locale('it'));
      for (final question in [
        l10n.chatExampleLeash('Tobia'),
        l10n.chatExampleBored('Tobia'),
        l10n.chatExampleDuties('Tobia'),
      ]) {
        await tester.ensureVisible(find.text(question));
        await tester.pump();
        final row = find.ancestor(of: find.text(question), matching: find.byType(InkWell)).first;
        expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      }
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
