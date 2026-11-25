import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/app_text_scaler.dart';
import 'package:vet_app_mobile/design_system/responsive.dart';
import 'package:vet_app_mobile/design_system/tokens/app_colors.dart';
import 'package:vet_app_mobile/features/activities/presentation/pages/activities_page.dart';
import 'package:vet_app_mobile/features/chat/data/chat_demo_store.dart';
import 'package:vet_app_mobile/features/chat/presentation/pages/chat_conversation_detail_page.dart';
import 'package:vet_app_mobile/features/home/presentation/pages/home_dashboard_page.dart';
import 'package:vet_app_mobile/features/home/presentation/widgets/home_ask_quokka_band.dart';
import 'package:vet_app_mobile/features/home/presentation/widgets/home_news_section.dart';
import 'package:vet_app_mobile/features/pet_news/data/pet_news_repository.dart';
import 'package:vet_app_mobile/features/pet_news/domain/pet_news_item.dart';
import 'package:vet_app_mobile/features/pet_news/presentation/pages/news_feed_page.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_create_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_detail_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/pet_avatar.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/species_figure.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/features/reminders/presentation/pages/reminders_pages.dart';
import 'package:vet_app_mobile/features/settings/data/layout_settings_store.dart';
import 'package:vet_app_mobile/features/travel_guide/data/travel_cards_repository.dart';
import 'package:vet_app_mobile/features/travel_guide/domain/travel_card.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/widgets/pet_loader.dart';
import 'package:vet_app_mobile/shared/widgets/quokka_logo.dart';

/// Wednesday 25 November 2026, at lunch time: the day of the approved draft.
final _now = DateTime(2026, 11, 25, 12, 30);

PetProfile _pet(
  String id,
  String name, {
  String species = 'Gatto',
  String breed = '',
  Color identityColor = AppIdentityColors.amber,
  bool isMemorial = false,
}) =>
    PetProfile(
      id: id,
      name: name,
      species: species,
      breed: breed,
      birthDateLabel: '',
      sex: 'Sconosciuto',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: name[0],
      accentColor: PetDemoStore.optionForSpecies(species).accentColor,
      identityColor: identityColor,
      isMemorial: isMemorial,
    );

final _lilla = _pet('lilla', 'Lilla');
final _ciuffo = _pet(
  'ciuffo',
  'Ciuffo',
  species: 'Piccoli mammiferi',
  breed: 'Coniglio nano',
  identityColor: AppIdentityColors.violet,
);

ReminderEntry _reminder(String id, String title, PetProfile pet, DateTime dueAt) => ReminderEntry(
      id: id,
      petName: pet.name,
      petId: pet.id,
      title: title,
      kind: EventKind.spot,
      dueAt: dueAt,
    );

final _draftReminders = [
  _reminder('1', 'Visita di controllo', _ciuffo, DateTime(2026, 11, 25, 17, 30)),
  _reminder('2', 'Spazzolata', _lilla, DateTime(2026, 11, 25, 11)),
  _reminder('3', 'Antiparassitario', _lilla, DateTime(2026, 11, 26, 9)),
  _reminder('4', 'Pesata', _ciuffo, DateTime(2026, 11, 28)),
  _reminder('5', 'Vaccino', _lilla, DateTime(2026, 11, 30, 10)),
];

PetNewsItem _story(String species, String title, {String source = 'Fonte di esempio', DateTime? at}) =>
    PetNewsItem(
      species: species,
      title: title,
      extract: source,
      sourceUrl: 'https://example.com/$title',
      publishedAt: at ?? DateTime(2026, 11, 25, 9),
    );

final _news = {
  'Gatto': [_story('Gatto', 'Il gatto anziano che cambia abitudini')],
  'Piccoli mammiferi': [
    _story('Piccoli mammiferi', 'Conigli e inverno', at: DateTime(2026, 11, 24, 9)),
  ],
  'Generale': [
    _story('Generale', 'Adozioni in aumento nei rifugi', at: DateTime(2026, 11, 23, 9)),
    _story('Generale', 'Il giorno dedicato agli animali', at: DateTime(2026, 11, 22, 9)),
  ],
};

class _NewsRepository implements PetNewsRepository {
  _NewsRepository(this.byCategory);

  Map<String, List<PetNewsItem>> byCategory;
  Object? error;

  @override
  Future<List<PetNewsItem>> fetchForSpecies(String species, {int limit = 2}) async {
    final failure = error;
    if (failure != null) throw failure;
    return (byCategory[species] ?? const <PetNewsItem>[]).take(limit).toList();
  }
}

class _Reminders extends RemindersRepository {
  _Reminders(this.load);

  Future<List<ReminderEntry>> Function() load;

  @override
  Future<List<ReminderEntry>> loadActiveReminders() => load();
}

class _NoTravelCards implements TravelCardsRepository {
  @override
  Future<List<TravelCard>> fetchAll() async => const [];
}

/// Puts [pets] in the shared store, as read from the server.
void _seedPets(List<PetProfile> pets) {
  final store = PetDemoStore.instance;
  store.debugOwnerId = () => 'owner';
  store.debugFetchRows = (_) async => [for (final pet in pets) store.petToRow(pet, 'owner')];
}

Widget _app(Widget page, {Locale locale = const Locale('it')}) => MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // The same text scaling the app applies in app.dart.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final factor = (mq.size.width / referenceScreenWidth).clamp(0.85, 1.35);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: AppTextScaler(system: mq.textScaler, appFactor: factor),
          ),
          child: child!,
        );
      },
      home: page,
    );

Widget _home({
  _NewsRepository? news,
  _Reminders? reminders,
  Future<bool> Function(BuildContext)? noticeGate,
  ValueChanged<PetNewsItem>? onOpenNews,
  Locale locale = const Locale('it'),
}) =>
    _app(
      locale: locale,
      Scaffold(
        body: HomeDashboardPage(
          petNewsRepository: news ?? _NewsRepository(_news),
          remindersRepository: reminders ?? _Reminders(() async => _draftReminders),
          noticeGate: noticeGate ?? (_) async => true,
          onOpenNews: onOpenNews,
          clock: () => _now,
        ),
      ),
    );

void _size(WidgetTester tester, Size size, {double text = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// Lets the pets, the news and the reminders land. Never settles: the app's
/// loader turns for ever.
Future<void> _load(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _tall = Size(390, 2400);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppLocaleHolder.current = const Locale('it');
    PetDemoStore.instance.reset();
    ChatDemoStore.instance.reset();
    await LayoutSettingsStore.instance.update(const LayoutSettings());
  });

  tearDown(() {
    PetDemoStore.instance
      ..debugOwnerId = null
      ..debugFetchRows = null
      ..reset();
    ChatDemoStore.instance.reset();
  });

  group('sections', () {
    testWidgets('greeting, animals, Chiedi a Quokka, calendar, news: in this order', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla, _ciuffo]);
      await tester.pumpWidget(_home());
      await _load(tester);

      final tops = [
        for (final text in [
          'Buongiorno',
          'I tuoi animali',
          'Chiedi a Quokka',
          'Il tuo calendario',
          'Curiosità per i tuoi animali',
          'Scopri altre notizie',
        ])
          tester.getTopLeft(find.text(text)).dy,
      ];
      expect(tops, List.of(tops)..sort());
      expect(tops.toSet(), hasLength(tops.length));
    });

    testWidgets('"Vicino a me" is not on Home any more; it is in Attività', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla]);
      await tester.pumpWidget(_home());
      await _load(tester);
      expect(find.text('Vicino a me'), findsNothing);

      await tester.pumpWidget(_app(ActivitiesPage(travelCardsRepository: _NoTravelCards())));
      await tester.pump();
      expect(find.text('Vicino a me'), findsOneWidget);
    });
  });

  group('I tuoi animali', () {
    testWidgets('a card per animal and "Aggiungi"; those in Ricordi are not here', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla, _ciuffo, _pet('nuvola', 'Nuvola', isMemorial: true)]);
      await tester.pumpWidget(_home());
      await _load(tester);

      expect(find.byKey(const ValueKey('home-pet-lilla')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-pet-ciuffo')), findsOneWidget);
      expect(find.text('Nuvola'), findsNothing);
      expect(find.text('Gatto'), findsOneWidget, reason: 'no breed: the kind of animal');
      expect(find.text('Coniglio nano'), findsOneWidget);
      expect(find.text('Aggiungi'), findsOneWidget);
    });

    testWidgets('without a photo: the figure of the species in a ring of the pet\'s colour',
        (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla, _ciuffo]);
      await tester.pumpWidget(_home());
      await _load(tester);

      final card = find.byKey(const ValueKey('home-pet-ciuffo'));
      expect(find.descendant(of: card, matching: find.byType(SpeciesFigure)), findsOneWidget);
      final ring = tester.widget<Container>(
        find
            .descendant(
              of: find.descendant(of: card, matching: find.byType(PetRingAvatar)),
              matching: find.byType(Container),
            )
            .first,
      );
      final border = (ring.decoration! as BoxDecoration).border! as Border;
      expect(border.top.color, AppIdentityColors.violet);
    });

    testWidgets('a tap opens the animal\'s page', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla, _ciuffo]);
      await tester.pumpWidget(_home());
      await _load(tester);

      await _tap(tester, find.byKey(const ValueKey('home-pet-ciuffo')));

      final page = tester.widget<PetDetailPage>(find.byType(PetDetailPage));
      expect(page.pet?.id, 'ciuffo');
    });

    testWidgets('"Aggiungi" opens the creation of an animal', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla]);
      await tester.pumpWidget(_home());
      await _load(tester);

      await _tap(tester, find.byKey(const ValueKey('home-add-pet')));

      expect(find.byType(PetCreatePage), findsOneWidget);
    });

    testWidgets('every card is read as one button and is at least 48 px', (tester) async {
      final handle = tester.ensureSemantics();
      _size(tester, const Size(320, 2400));
      _seedPets([_lilla, _ciuffo]);
      await tester.pumpWidget(_home());
      await _load(tester);

      expect(find.bySemanticsLabel('Lilla, Gatto'), findsOneWidget);
      expect(find.bySemanticsLabel('Ciuffo, Coniglio nano'), findsOneWidget);
      expect(find.bySemanticsLabel('Aggiungi un animale'), findsOneWidget);
      for (final key in ['home-pet-lilla', 'home-add-pet', 'home-ask-quokka', 'home-news-more']) {
        final box = tester.getSize(find.byKey(ValueKey(key)));
        expect(box.shortestSide, greaterThanOrEqualTo(48), reason: key);
      }
      handle.dispose();
    });

    testWidgets('a new animal shows up without reopening Home', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla]);
      await tester.pumpWidget(_home());
      await _load(tester);
      expect(find.text('Ciuffo'), findsNothing);

      await PetDemoStore.instance.upsert(_ciuffo);
      await _load(tester);

      expect(find.byKey(const ValueKey('home-pet-ciuffo')), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('no animal: the invitation, no chat band', (tester) async {
      _size(tester, _tall);
      _seedPets(const []);
      await tester.pumpWidget(_home());
      await _load(tester);

      expect(find.text('Nessun pet ancora'), findsOneWidget);
      expect(find.text('Aggiungi un animale'), findsOneWidget);
      expect(find.byType(HomeAskQuokkaBand), findsNothing);

      await _tap(tester, find.byKey(const ValueKey('home-add-pet')));
      expect(find.byType(PetCreatePage), findsOneWidget);
    });

    testWidgets('only animals in Ricordi: the soft wording, no push', (tester) async {
      _size(tester, _tall);
      _seedPets([_pet('nuvola', 'Nuvola', isMemorial: true)]);
      await tester.pumpWidget(_home());
      await _load(tester);

      expect(find.text('Quando vorrai, potrai aggiungere un nuovo profilo.'), findsOneWidget);
      expect(find.text('Nessun pet ancora'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(HomeAskQuokkaBand), findsNothing);
    });

    testWidgets('while the animals are read: the spinning animal, not "nessun pet"', (tester) async {
      _size(tester, _tall);
      final answer = Completer<List<dynamic>>();
      PetDemoStore.instance
        ..debugOwnerId = (() => 'owner')
        ..debugFetchRows = (_) => answer.future;
      await tester.pumpWidget(_home(reminders: _Reminders(() async => const [])));
      await tester.pump();

      expect(find.byType(PetLoader), findsWidgets);
      expect(find.text('Nessun pet ancora'), findsNothing);

      answer.complete([PetDemoStore.instance.petToRow(_lilla, 'owner')]);
      await _load(tester);
      expect(find.byKey(const ValueKey('home-pet-lilla')), findsOneWidget);
    });

    testWidgets('the animals cannot be read: it says so and "Riprova" asks again', (tester) async {
      _size(tester, _tall);
      var fail = true;
      PetDemoStore.instance
        ..debugOwnerId = (() => 'owner')
        ..debugFetchRows = (_) async {
          if (fail) throw Exception('offline');
          return [PetDemoStore.instance.petToRow(_lilla, 'owner')];
        };
      await tester.pumpWidget(_home());
      await _load(tester);

      expect(find.text('Al momento non riesco a caricare i profili pet.'), findsOneWidget);
      expect(find.text('Nessun pet ancora'), findsNothing);

      fail = false;
      await _tap(tester, find.byKey(const ValueKey('home-pets-retry')));
      expect(find.byKey(const ValueKey('home-pet-lilla')), findsOneWidget);
    });

    testWidgets('news: loading, unavailable with "Riprova", then the stories', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla]);
      final news = _NewsRepository(const {})..error = Exception('down');
      await tester.pumpWidget(_home(news: news));
      await _load(tester);

      expect(
        find.text('Curiosità non disponibili al momento. Riprova più tardi.'),
        findsOneWidget,
      );
      expect(find.byType(HomeNewsRow), findsNothing);

      news
        ..error = null
        ..byCategory = _news;
      await _tap(tester, find.byKey(const ValueKey('home-news-retry')));
      expect(find.byType(HomeNewsRow), findsNWidgets(3));
    });

    testWidgets('the calendar cannot be read: it says so and "Riprova" asks again', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla, _ciuffo]);
      var fail = true;
      await tester.pumpWidget(_home(reminders: _Reminders(() async {
        if (fail) throw Exception('offline');
        return _draftReminders;
      })));
      await _load(tester);
      expect(find.text('Sincronizzazione promemoria fallita.'), findsOneWidget);

      fail = false;
      await _tap(tester, find.byKey(const ValueKey('home-calendar-retry')));
      expect(find.text('Spazzolata · Lilla'), findsOneWidget);
    });
  });

  group('Chiedi a Quokka', () {
    testWidgets('the quokka is the app\'s own, light on petrol, in a light frame', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla, _ciuffo]);
      await tester.pumpWidget(_home());
      await _load(tester);

      final round = find.byType(QuokkaHeadRound);
      expect(round, findsOneWidget);
      final circle = tester.widget<Container>(
        find.descendant(of: round, matching: find.byType(Container)).first,
      );
      final decoration = circle.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.brandDeep);
      expect(decoration.shape, BoxShape.circle);
      expect((decoration.border! as Border).top.color, AppColors.brandPaper);

      final image = tester.widget<Image>(find.descendant(of: round, matching: find.byType(Image)));
      expect((image.image as AssetImage).assetName, 'assets/brand/quokka_head_paper.png');
      expect(image.color, isNull, reason: 'never recoloured');
      expect(
        find.descendant(of: round, matching: find.byType(ColorFiltered)),
        findsNothing,
      );
    });

    testWidgets('one animal: a tap opens a new chat with it, with no question', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla]);
      await tester.pumpWidget(_home());
      await _load(tester);
      expect(find.text('Scrivi una domanda su Lilla'), findsOneWidget);
      expect(find.text('Per quale animale?'), findsNothing);

      await _tap(tester, find.byKey(const ValueKey('home-ask-quokka')));

      expect(find.byType(SimpleDialog), findsNothing);
      final page = tester.widget<ChatConversationDetailPage>(
        find.byType(ChatConversationDetailPage),
      );
      expect(page.initialConversation?.petId, 'lilla');
      expect(ChatDemoStore.instance.countForPet('lilla'), 1);
    });

    testWidgets('more animals: it asks which one, and the chat is about that one', (tester) async {
      _size(tester, _tall);
      // The same name twice: the choice goes by animal, not by name.
      _seedPets([_lilla, _pet('lilla-2', 'Lilla', species: 'Cane')]);
      await tester.pumpWidget(_home());
      await _load(tester);
      expect(find.text('Per quale animale?'), findsOneWidget);

      await _tap(tester, find.byKey(const ValueKey('home-ask-quokka')));
      expect(find.byType(SimpleDialog), findsOneWidget);
      expect(find.byType(ChatConversationDetailPage), findsNothing);

      await _tap(tester, find.byKey(const ValueKey('pick-pet-lilla-2')));
      final page = tester.widget<ChatConversationDetailPage>(
        find.byType(ChatConversationDetailPage),
      );
      expect(page.initialConversation?.petId, 'lilla-2');
    });

    testWidgets('leaving the question opens nothing and creates nothing', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla, _ciuffo]);
      await tester.pumpWidget(_home());
      await _load(tester);
      final before = ChatDemoStore.instance.conversations.length;

      await _tap(tester, find.byKey(const ValueKey('home-ask-quokka')));
      await tester.tapAt(const Offset(5, 5));
      await _load(tester);

      expect(find.byType(SimpleDialog), findsNothing);
      expect(find.byType(ChatConversationDetailPage), findsNothing);
      expect(ChatDemoStore.instance.conversations.length, before);
    });

    testWidgets('the notice declined: no chat is left behind', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla]);
      var asked = 0;
      await tester.pumpWidget(_home(noticeGate: (_) async {
        asked++;
        return false;
      }));
      await _load(tester);

      await _tap(tester, find.byKey(const ValueKey('home-ask-quokka')));

      expect(asked, 1);
      expect(find.byType(ChatConversationDetailPage), findsNothing);
      expect(ChatDemoStore.instance.countForPet('lilla'), 0);
      // And the band can be tapped again.
      await _tap(tester, find.byKey(const ValueKey('home-ask-quokka')));
      expect(asked, 2);
    });

    testWidgets('the limit of chats per animal is the one of the Chat tab', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla]);
      await tester.pumpWidget(_home());
      await _load(tester);
      for (var i = 0; i < ChatDemoStore.maxConversationsPerPet; i++) {
        ChatDemoStore.instance.startConversation(petId: 'lilla', petName: 'Lilla');
      }

      await _tap(tester, find.byKey(const ValueKey('home-ask-quokka')));

      expect(find.text('Limite chat raggiunto'), findsOneWidget);
      expect(find.byType(ChatConversationDetailPage), findsNothing);
      expect(
        ChatDemoStore.instance.countForPet('lilla'),
        ChatDemoStore.maxConversationsPerPet,
      );
    });

    testWidgets('two quick taps open one chat', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla]);
      final gate = Completer<bool>();
      await tester.pumpWidget(_home(noticeGate: (_) => gate.future));
      await _load(tester);

      final band = find.byKey(const ValueKey('home-ask-quokka'));
      await tester.tap(band);
      await tester.tap(band);
      await tester.pump();
      gate.complete(true);
      await _load(tester);

      expect(ChatDemoStore.instance.countForPet('lilla'), 1);
    });
  });

  group('Il tuo calendario', () {
    Finder chip(int day) => find.byWidgetPredicate(
          (widget) => widget is HomeDayChip && widget.day == DateTime(2026, 11, day),
        );
    Finder inChip(int day, String text) =>
        find.descendant(of: chip(day), matching: find.text(text));

    testWidgets('one activity: the animal\'s initial; more: how many', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla, _ciuffo]);
      await tester.pumpWidget(_home());
      await _load(tester);

      expect(inChip(25, '2'), findsOneWidget);
      expect(inChip(26, 'L'), findsOneWidget);
      expect(inChip(28, 'C'), findsOneWidget);
      expect(inChip(30, 'L'), findsOneWidget);
      expect(find.text('5 attività nei prossimi 10 giorni'), findsOneWidget);

      final ring = tester.widgetList<Container>(
        find.descendant(of: chip(28), matching: find.byType(Container)),
      );
      expect(
        ring.any((box) {
          final border = (box.decoration as BoxDecoration?)?.border as Border?;
          return border?.top.color == AppIdentityColors.violet;
        }),
        isTrue,
        reason: 'the ring of the initial is the pet\'s colour',
      );
    });

    testWidgets('today: its activities by time, with the animal', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla, _ciuffo]);
      await tester.pumpWidget(_home());
      await _load(tester);

      final panel = find.byKey(const ValueKey('home-today'));
      expect(find.descendant(of: panel, matching: find.text('Oggi')), findsOneWidget);
      final first = find.descendant(of: panel, matching: find.text('Spazzolata · Lilla'));
      final second = find.descendant(of: panel, matching: find.text('Visita di controllo · Ciuffo'));
      expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
      expect(find.descendant(of: panel, matching: find.text('11:00')), findsOneWidget);
      expect(find.descendant(of: panel, matching: find.text('17:30')), findsOneWidget);
      expect(find.text('Antiparassitario · Lilla'), findsNothing, reason: 'that is tomorrow');
    });

    testWidgets('a day without activities today says so', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla]);
      await tester.pumpWidget(_home(reminders: _Reminders(() async => const [])));
      await _load(tester);
      expect(find.text('Nessuna attività in questo giorno.'), findsOneWidget);
    });

    testWidgets('the weeks and the first day follow the settings', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla]);
      await tester.pumpWidget(_home());
      await _load(tester);
      expect(find.byType(HomeDayChip), findsNWidgets(14));
      expect(
        tester.widget<HomeDayChip>(find.byType(HomeDayChip).first).day,
        DateTime(2026, 11, 23),
      );

      await LayoutSettingsStore.instance.update(
        const LayoutSettings(weeksShown: 1, weekStartDay: WeekStartDay.sunday),
      );
      await _load(tester);
      expect(find.byType(HomeDayChip), findsNWidgets(7));
      expect(
        tester.widget<HomeDayChip>(find.byType(HomeDayChip).first).day,
        DateTime(2026, 11, 22),
      );
    });

    testWidgets('an animal moved to Ricordi takes its activities away at once', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla, _ciuffo]);
      await tester.pumpWidget(_home());
      await _load(tester);
      expect(find.text('Visita di controllo · Ciuffo'), findsOneWidget);

      await PetDemoStore.instance.upsert(_ciuffo.copyWith(isMemorial: true));
      await _load(tester);

      expect(find.text('Visita di controllo · Ciuffo'), findsNothing);
      expect(inChip(25, 'L'), findsOneWidget);
    });

    testWidgets('a tap opens the reminders', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla]);
      await tester.pumpWidget(_home());
      await _load(tester);

      await _tap(tester, find.byKey(const ValueKey('home-calendar')));

      expect(find.byType(RemindersListPage), findsOneWidget);
    });
  });

  group('Curiosità', () {
    testWidgets('four white rows: figure, bold title, source and date, "opens outside"',
        (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla, _ciuffo]);
      await tester.pumpWidget(_home());
      await _load(tester);

      expect(find.byType(HomeNewsRow), findsNWidgets(4));
      final row = find.ancestor(
        of: find.text('Il gatto anziano che cambia abitudini'),
        matching: find.byType(HomeNewsRow),
      );
      expect(find.descendant(of: row, matching: find.byType(SpeciesFigure)), findsOneWidget);
      expect(
        find.descendant(
          of: row,
          matching: find.text('Fonte di esempio · 25 nov'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.open_in_new_rounded)),
        findsOneWidget,
      );
      final title = tester.widget<Text>(find.text('Il gatto anziano che cambia abitudini'));
      expect(title.style?.color, AppColors.text);
      expect(title.style?.fontWeight, FontWeight.w600);

      // The ground of the rows is white, whole: no tint under or over the text.
      final ground = tester.widget<Material>(
        find.ancestor(of: row, matching: find.byType(Material)).first,
      );
      expect(ground.color, AppColors.surfaceElevated);
    });

    testWidgets('a tap opens that story; "Scopri altre notizie" opens the news', (tester) async {
      _size(tester, _tall);
      _seedPets([_lilla, _ciuffo]);
      final opened = <String>[];
      await tester.pumpWidget(_home(onOpenNews: (item) => opened.add(item.title)));
      await _load(tester);

      await _tap(tester, find.text('Conigli e inverno'));
      expect(opened, ['Conigli e inverno']);

      await _tap(tester, find.byKey(const ValueKey('home-news-more')));
      expect(find.byType(NewsFeedPage), findsOneWidget);
    });
  });

  group('no overflow', () {
    final long = [
      _pet('a', 'Principessa Serafina della Valle', species: 'Cane', breed: 'Norvegese delle foreste'),
      _ciuffo,
      _pet('c', 'Re', species: 'Rettili e anfibi', breed: 'Riccio africano (Atelerix albiventris)'),
      _pet('d', 'Pico', species: 'Uccello'),
      _pet('e', 'Moka', species: 'Altro', breed: 'Cavallo'),
    ];
    final busy = [
      for (var i = 0; i < 7; i++)
        _reminder(
          'b$i',
          'Controllo annuale del peso e della dentatura con visita completa',
          long.first,
          DateTime(2026, 11, 25, 8 + i),
        ),
      ReminderEntry(
        id: 'course',
        petName: 'Ciuffo',
        petId: 'ciuffo',
        title: 'Terapia',
        kind: EventKind.course,
        dueAt: DateTime(2026, 11, 20),
        courseDurationDays: 20,
        doseTimes: const ['06:00', '12:00', '18:00', '23:00'],
      ),
    ];
    final longNews = {
      for (final category in _news.keys)
        category: [
          for (var i = 0; i < 4; i++)
            _story(
              category,
              '$i Il giorno dedicato agli animali di famiglia arriva nelle scuole con incontri e giochi',
              source: 'Fonte di esempio con un nome molto lungo che non sta in una riga',
            ),
        ],
    };

    for (final width in [320.0, 360.0, 390.0, 900.0]) {
      for (final text in [1.0, 1.3]) {
        for (final locale in ['it', 'de', 'fr']) {
          testWidgets('$width px, text $text, $locale', (tester) async {
            _size(tester, Size(width, 900), text: text);
            AppLocaleHolder.current = Locale(locale);
            for (final pets in [
              const <PetProfile>[],
              [_ciuffo],
              [_lilla, _ciuffo],
              long,
            ]) {
              PetDemoStore.instance.reset();
              _seedPets(pets);
              await tester.pumpWidget(_home(
                locale: Locale(locale),
                reminders: _Reminders(() async => busy),
                news: _NewsRepository(longNews),
              ));
              await _load(tester);
              expect(tester.takeException(), isNull, reason: '${pets.length} animals');
              // The whole page: what is below is laid out too, and it does not
              // scroll sideways.
              await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
              await tester.pump();
              expect(tester.takeException(), isNull, reason: '${pets.length} animals');
              await tester.pumpWidget(const SizedBox());
            }
          });
        }
      }
    }
  });
}
