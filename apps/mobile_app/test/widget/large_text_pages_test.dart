import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/app_text_scaler.dart';
import 'package:vet_app_mobile/design_system/responsive.dart';
import 'package:vet_app_mobile/features/account/presentation/pages/change_email_page.dart';
import 'package:vet_app_mobile/features/account/presentation/pages/change_password_page.dart';
import 'package:vet_app_mobile/features/account/presentation/pages/export_data_page.dart';
import 'package:vet_app_mobile/features/activities/presentation/pages/activities_page.dart';
import 'package:vet_app_mobile/features/chat/data/chat_seed_data.dart';
import 'package:vet_app_mobile/features/chat/presentation/pages/chat_conversation_detail_page.dart';
import 'package:vet_app_mobile/features/events/data/events_repository.dart';
import 'package:vet_app_mobile/features/events/domain/event_entry.dart';
import 'package:vet_app_mobile/features/events/presentation/pages/events_page.dart';
import 'package:vet_app_mobile/features/events/presentation/pages/submit_event_page.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_repository.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/create_listing_page.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/listing_detail_page.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/marketplace_page.dart';
import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';
import 'package:vet_app_mobile/features/medical_records/domain/record_category.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/pages/medical_record_upload_page.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/pages/pet_condition_form_page.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/pages/pet_conditions_page.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/pages/record_category_page.dart';
import 'package:vet_app_mobile/features/pet_news/presentation/pages/news_feed_page.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/gallery_folders_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_create_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_data_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_detail_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_edit_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_memories_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pets_list_page.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/features/reminders/presentation/pages/reminders_pages.dart';
import 'package:vet_app_mobile/features/travel_guide/data/travel_cards_repository.dart';
import 'package:vet_app_mobile/features/travel_guide/domain/travel_card.dart';
import 'package:vet_app_mobile/features/travel_guide/presentation/pages/travel_guide_page.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

/// The pages that text_scale_overflow_test.dart and language_qa_test.dart do not
/// open, at the ceiling of the large text (card A04): the smallest phone and an
/// ordinary one, with the real Roboto (the test font is wider than any font).

PetProfile _pet(String id, String name, String species, String breed) => PetProfile(
      id: id,
      name: name,
      species: species,
      breed: breed,
      birthDateLabel: '12 mar 2020',
      sex: 'Maschio',
      weightLabel: '4,2 kg',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: name[0],
      accentColor: PetDemoStore.optionForSpecies(species).accentColor,
      identityColor: Colors.teal,
    );

final _dog = _pet('pet-dog', 'Thor', 'Cane', 'Labrador Retriever');
final _cat = _pet('pet-cat', 'Nonno Gigi', 'Gatto', 'Europeo');

final _listing = MarketplaceListing(
  id: 'listing',
  ownerId: 'seller',
  title: 'Trasportino per gatto quasi nuovo',
  category: ListingCategory.toys,
  condition: ListingCondition.good,
  priceCents: 1000,
  species: const [ListingSpecies.dog],
  country: 'IT',
  location: const Coordinates(latitude: 45.46, longitude: 9.19),
  createdAt: DateTime(2026, 10, 7),
  updatedAt: DateTime(2026, 10, 7),
);

class _Events extends EventsRepository {
  @override
  Future<EventsLoadResult> loadEvents({
    required DateTime from,
    required DateTime to,
    String? country,
  }) async =>
      EventsLoadResult(events: [
        EventEntry(
          id: 'e',
          title: 'Fiera degli animali da compagnia',
          eventType: 'pet_fair',
          level: EventLevel.national,
          startsOn: from.add(const Duration(days: 3)),
          endsOn: from.add(const Duration(days: 4)),
          city: 'Cremona',
          provinceCode: 'CR',
          region: 'Lombardia',
          status: EventStatus.published,
        ),
      ]);
}

class _NoTravelCards implements TravelCardsRepository {
  @override
  Future<List<TravelCard>> fetchAll() async => const [];
}

Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final files = [
    for (final weight in ['light', 'regular', 'medium', 'bold', 'black'])
      File('$dir/roboto-$weight.ttf'),
  ].where((file) => file.existsSync()).toList();
  if (files.isEmpty) return;
  // The names google_fonts gives to the app's own faces, so that the pages are
  // measured with a phone's proportions and not with the test font's squares.
  for (final family in [
    'Roboto',
    'Fraunces_600',
    for (final weight in ['regular', '500', '600', '700', '800']) 'Figtree_$weight',
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }
}

Widget _app(Widget page) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final factor = (mq.size.width / referenceScreenWidth).clamp(0.85, 1.35);
        return MediaQuery(
          data: mq.copyWith(textScaler: AppTextScaler(system: mq.textScaler, appFactor: factor)),
          child: child!,
        );
      },
      home: page,
    );

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    await _loadRoboto();
    await initializeDateFormatting('it_IT');
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({'vet_app.short_notice.marketplace': true});
    AppLocaleHolder.current = const Locale('it');
    PetDemoStore.instance.reset();
  });

  final reminder = ReminderEntry(
    id: 'r',
    petName: 'Nonno Gigi',
    title: 'Richiamo del vaccino e controllo generale',
    kind: EventKind.recurring,
    dueAt: DateTime.now().add(const Duration(days: 2)),
    note: 'Portare il libretto sanitario e la lista delle domande.',
    intervalUnit: IntervalUnit.months,
    intervalValue: 12,
  );
  final records = MedicalRecordsRepository();

  final pages = <String, Widget Function()>{
    'chat': () => ChatConversationDetailPage(
          conversationId: ChatSeedData.conversations.first.id,
          initialConversation: ChatSeedData.detailForSummary(ChatSeedData.conversations.first),
          noticeGate: (_) async => true,
        ),
    'attività': () => ActivitiesPage(travelCardsRepository: _NoTravelCards()),
    'animali': () => const PetsListPage(),
    'nuovo animale': () => const PetCreatePage(),
    'scheda del cane': () => PetDetailPage(pet: _dog),
    'scheda del gatto, chat': () => PetDetailPage(pet: _cat, initialTab: 1),
    'scheda del gatto, referti': () => PetDetailPage(pet: _cat, initialTab: 2),
    'scheda del gatto, monitoraggio': () => PetDetailPage(pet: _cat, initialTab: 3),
    'dati animale': () => PetDataPage(petId: _cat.id, initialPet: _cat),
    'modifica animale': () => PetEditPage(pet: _cat),
    'ricordi': () => const PetMemoriesPage(),
    'galleria': () => const GalleryFoldersPage(),
    'promemoria, dettaglio': () => ReminderDetailPage(reminder: reminder),
    'promemoria, nuovo': () => const ReminderCreatePage(petName: 'Nonno Gigi'),
    'promemoria, modifica': () => ReminderEditPage(reminder: reminder),
    'referti, categoria': () => RecordCategoryPage(
          pet: _cat,
          category: RecordCategory.exam,
          repository: records,
        ),
    'referti, nuovo': () => const MedicalRecordUploadPage(petName: 'Nonno Gigi'),
    'malattie': () => PetConditionsPage(pet: _cat),
    'malattia': () => PetConditionFormPage(pet: _cat),
    'eventi': () => EventsPage(repository: _Events()),
    'evento, suggerisci': () => const SubmitEventPage(),
    'mercatino': () => MarketplacePage(
          repository: MarketplaceRepository.inMemory([_listing]),
          referenceLoader: () async => _listing.location,
        ),
    'annuncio': () => ListingDetailPage(
          listing: _listing,
          repository: MarketplaceRepository.inMemory([_listing]),
          currentOwnerId: 'seller',
        ),
    'annuncio, nuovo': () => const CreateListingPage(),
    'notizie': () => const NewsFeedPage(),
    'intorno al mondo': () => TravelGuidePage(repository: _NoTravelCards()),
    'e-mail': () => const ChangeEmailPage(),
    'password': () => const ChangePasswordPage(),
    'esporta i dati': () => const ExportDataPage(),
  };

  const sizes = {
    '320x568': Size(320, 568),
    '411x731': Size(411, 731),
  };
  for (final size in sizes.entries) {
    for (final page in pages.entries) {
      testWidgets('${page.key}: no overflow at the ceiling, ${size.key}', (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        // More than the app lets through (maxSystemTextScale).
        tester.platformDispatcher.textScaleFactorTestValue = 2.4;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await tester.pumpWidget(_app(page.value()));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        // Down the page too: what is built while scrolling must hold as well.
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          for (var i = 0; i < 8; i++) {
            await tester.drag(scrollables.last, const Offset(0, -300), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 60));
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
