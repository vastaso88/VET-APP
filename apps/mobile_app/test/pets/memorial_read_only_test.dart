import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/launch/restorable_pages.dart';
import 'package:vet_app_mobile/app/launch/route_restoration.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/features/chat/data/chat_demo_store.dart';
import 'package:vet_app_mobile/features/chat/data/chat_seed_data.dart';
import 'package:vet_app_mobile/features/chat/presentation/pages/chat_conversation_detail_page.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/medical_record_consent_card.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/pages/pet_condition_form_page.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/pages/pet_conditions_page.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/pet_medical_records_tab.dart';
import 'package:vet_app_mobile/features/medical_records/domain/pet_condition.dart';
import 'package:vet_app_mobile/features/pets/application/memorial_service.dart';
import 'package:vet_app_mobile/features/pets/data/memorial_moments.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_data_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_detail_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_gallery_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_memorial_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

/// Ricordi in sola lettura (owner's request after build 39): a pet in Ricordi
/// is looked at, sent and exported, never changed. Synthetic data only.
Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

PetProfile _moka({required bool memorial}) =>
    samplePets.firstWhere((pet) => pet.name == 'Moka').copyWith(isMemorial: memorial);

Future<void> _pumpRecords(WidgetTester tester, PetProfile pet) async {
  await tester.pumpWidget(_app(Scaffold(
    body: PetMedicalRecordsTab(pet: pet, repository: MedicalRecordsRepository()),
  )));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(PetDemoStore.instance.reset);

  group('profile kept as it was (same rule as the database)', () {
    test('a memory keeps everything but the loss date and its reminders', () async {
      final stored = await PetDemoStore.instance.upsert(
        _moka(memorial: true).copyWith(memorialDate: DateTime(2026, 11, 14)),
      );
      final saved = await PetDemoStore.instance.upsert(stored.copyWith(
        name: 'Altro nome',
        weightLabel: '30 kg',
        memorialDate: DateTime(2026, 11, 13),
        memorialBirthdayReminder: true,
      ));

      expect(saved.name, 'Moka');
      expect(saved.weightLabel, stored.weightLabel);
      expect(saved.memorialDate, DateTime(2026, 11, 13));
      expect(saved.memorialBirthdayReminder, isTrue);
      expect(PetDemoStore.instance.byId(stored.id)?.name, 'Moka');
    });

    test('moving in, bringing back and active pets are untouched', () async {
      final active = await PetDemoStore.instance.upsert(_moka(memorial: false));
      expect((await PetDemoStore.instance.upsert(active.copyWith(name: 'Moka II'))).name, 'Moka II');

      final moved = await PetDemoStore.instance.upsert(
        active.copyWith(isMemorial: true, name: 'Moka III'),
      );
      expect(moved.isMemorial, isTrue);
      expect(moved.name, 'Moka III');

      final back = await PetDemoStore.instance.upsert(moved.copyWith(isMemorial: false));
      expect(back.isMemorial, isFalse);
    });
  });

  group('after a restart', () {
    testWidgets('a pet moved to Ricordi reopens on its memorial page', (tester) async {
      final pet = await PetDemoStore.instance.upsert(_moka(memorial: true));
      final registry = RestorablePages();
      registerRestorablePages(registry);

      final page = await registry.build('pet_detail', {'petId': pet.id, 'tab': 1});
      expect(page, isA<PetMemorialPage>());

      await PetDemoStore.instance.upsert(_moka(memorial: false));
      expect(await registry.build('pet_detail', {'petId': pet.id}), isA<PetDetailPage>());
    });
  });

  group('records', () {
    testWidgets('readable and exportable, nothing to add, no consent card', (tester) async {
      _phone(tester);
      await _pumpRecords(tester, _moka(memorial: true));

      expect(find.text('Visite'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Aggiungi'), findsNothing);
      expect(find.byType(MedicalRecordConsentCard), findsNothing);

      await tester.tap(find.text('Invia'));
      await tester.pumpAndSettle();
      expect(find.text('Tutto lo storico (PDF)'), findsOneWidget);
    });

    testWidgets('an active pet still has both', (tester) async {
      _phone(tester);
      await _pumpRecords(tester, _moka(memorial: false));

      expect(find.widgetWithText(FilledButton, 'Aggiungi'), findsOneWidget);
      expect(find.byType(MedicalRecordConsentCard), findsOneWidget);
    });

    testWidgets('a category: no add button, an entry can only be opened or sent', (tester) async {
      _phone(tester);
      await _pumpRecords(tester, _moka(memorial: true));

      await tester.tap(find.text('Terapie'));
      await tester.pumpAndSettle();
      expect(find.text('Nessuna terapia registrata'), findsOneWidget);
      expect(find.text('Aggiungi la prima terapia'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await _pumpRecords(tester, _moka(memorial: true));
      await tester.tap(find.text('Esami'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Esame ematico di Moka'));
      await tester.pumpAndSettle();
      expect(find.text('Rinomina'), findsNothing);
      expect(find.text('Elimina'), findsNothing);
      expect(find.text('Modifica dettagli'), findsNothing);
    });

    testWidgets('illnesses: no add button, the form opens without saving', (tester) async {
      _phone(tester);
      final pet = _moka(memorial: true);
      await tester.pumpWidget(_app(PetConditionsPage(pet: pet)));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.pumpWidget(_app(PetConditionFormPage(
        pet: pet,
        existing: PetConditionEntry(id: 'c1', petId: pet.id, name: 'Otite', ongoing: false),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Otite'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Salva'), findsNothing);
      expect(find.byTooltip('Elimina'), findsNothing);
      final name = tester.widget<EditableText>(find.byType(EditableText).first);
      expect(name.readOnly, isTrue);
    });
  });

  group('gallery and profile', () {
    testWidgets('gallery: look only, no add button', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(PetGalleryPage(pet: _moka(memorial: true))));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.pumpWidget(_app(PetGalleryPage(pet: _moka(memorial: false))));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('profile: no edit button, no "add the microchip" nudge', (tester) async {
      _phone(tester);
      final pet = _moka(memorial: true).copyWith(clearMicrochipNumber: true);
      await tester.pumpWidget(_app(PetDataPage(petId: pet.id, initialPet: pet)));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Modifica'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });
  });

  group('memorial page', () {
    testWidgets('"moved by mistake?" is right under the dates, delete stays at the bottom',
        (tester) async {
      _phone(tester);
      final pet = await PetDemoStore.instance.upsert(_moka(memorial: true));
      await tester.pumpWidget(_app(PetMemorialPage(
        pet: pet,
        service: MemorialService(
          store: PetDemoStore.instance,
          stopWalkOf: (_) async {},
          revokeRecordsConsent: (_) async {},
          onMoved: (_) {},
          onRestored: () {},
        ),
        loadMoments: (_) async => const MemorialMoments(),
        today: DateTime(2026, 11, 16),
      )));
      await tester.pumpAndSettle();

      // On screen without scrolling.
      final restore = find.byKey(const ValueKey('memorial-restore'));
      expect(restore.hitTestable(), findsOneWidget);
      expect(find.text('Spostata per errore? Riporta tra gli animali'), findsOneWidget);
      expect(find.textContaining('Qui tutto resta com'), findsOneWidget);
      final delete = find.byKey(const ValueKey('memorial-delete'), skipOffstage: false);
      expect(delete, findsOneWidget);
      expect(
        tester.getTopLeft(restore).dy,
        lessThan(tester.getTopLeft(delete).dy),
      );
    });
  });

  group('chat', () {
    testWidgets('a past chat of a pet in Ricordi is read only', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      ChatDemoStore.instance.reset();
      expect(ChatSeedData.detail.petName, 'Moka');
      await PetDemoStore.instance.upsert(_moka(memorial: true));

      await tester.pumpWidget(_app(ChatConversationDetailPage(
        conversationId: ChatSeedData.detail.id,
        initialConversation: ChatSeedData.detail,
      )));
      await tester.pump();

      expect(find.byType(ChatComposer), findsNothing);
      expect(find.byKey(const ValueKey('chat-memorial-read-only')), findsOneWidget);
    });
  });
}
