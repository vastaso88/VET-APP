import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/features/billing/presentation/pages/paywall_page.dart';
import 'package:vet_app_mobile/features/pets/application/memorial_service.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/memorial_choose_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/memorial_move_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

/// Without a plan the app shows only the paywall (export, delete the account,
/// emergency guidance). Moving a pet to Ricordi stays possible there (owner
/// decision 2026-11-16): a calm entry, with the list of the active pets, that
/// leads to the usual two-step move. Synthetic data only.
PetProfile _pet(String id, {bool memorial = false, String name = 'Moka'}) => PetProfile(
      id: id,
      name: name,
      species: 'Cane',
      breed: '',
      birthDateLabel: '',
      sex: 'Femmina',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'M',
      accentColor: Colors.white,
      identityColor: Colors.green,
      isMemorial: memorial,
    );

Widget _app(Widget home, {Locale locale = const Locale('it')}) => MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 15000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

MemorialService _service({int? cap, List<String>? moved}) => MemorialService(
      store: PetDemoStore.instance,
      stopWalkOf: (_) async {},
      revokeRecordsConsent: (_) async {},
      onMoved: (id) => moved?.add(id),
      onRestored: () {},
      planLimit: () => (limit: null, upgradePlan: null),
      memorialLimit: () => cap,
    );

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(PetDemoStore.instance.reset);
  tearDown(() => PetDemoStore.instance.debugUpsertRow = null);

  group('the paywall entry', () {
    testWidgets('a pet to move: the entry is there, calm, with no plan or payment in it',
        (tester) async {
      _phone(tester);
      await PetDemoStore.instance.upsert(_pet('a', name: 'Rex'));
      await tester.pumpWidget(_app(const PaywallPage()));
      await tester.pump();

      final entry = find.byKey(const ValueKey('paywall-move-to-memories'));
      await tester.ensureVisible(entry);
      expect(entry, findsOneWidget);
      expect(find.text('Un animale non c\'è più? Spostalo nei Ricordi'), findsOneWidget);
      // It sits with the owner's own data, after the plans, never among them.
      final label = tester.widget<Text>(find.text('Un animale non c\'è più? Spostalo nei Ricordi'));
      expect(label.data, isNot(contains('piano')));
      expect(label.data, isNot(contains('€')));
    });

    testWidgets('no pet, no entry (nothing would be shown on the list)', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const PaywallPage()));
      await tester.pump();

      // The data section itself is built (so its absence below means something).
      expect(find.text(lookupAppLocalizations(const Locale('it')).settingsAccountExport),
          findsOneWidget);
      expect(find.byKey(const ValueKey('paywall-move-to-memories')), findsNothing);
    });

    testWidgets('pets already in Ricordi are not offered again', (tester) async {
      _phone(tester);
      await PetDemoStore.instance.upsert(_pet('m', memorial: true));
      await tester.pumpWidget(_app(const PaywallPage()));
      await tester.pump();

      // The data section itself is built (so its absence below means something).
      expect(find.text(lookupAppLocalizations(const Locale('it')).settingsAccountExport),
          findsOneWidget);
      expect(find.byKey(const ValueKey('paywall-move-to-memories')), findsNothing);
    });

    testWidgets('the entry opens the list of the active pets', (tester) async {
      _phone(tester);
      await PetDemoStore.instance.upsert(_pet('a', name: 'Rex'));
      await PetDemoStore.instance.upsert(_pet('b', name: 'Luna'));
      await PetDemoStore.instance.upsert(_pet('m', memorial: true, name: 'Ricordo'));
      await tester.pumpWidget(_app(const PaywallPage()));
      await tester.pump();

      final entry = find.byKey(const ValueKey('paywall-move-to-memories'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.byType(MemorialChoosePage), findsOneWidget);
      expect(find.text('Quale animale non c\'è più?'), findsOneWidget);
      expect(find.text('Rex'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Ricordo'), findsNothing, reason: 'already in Ricordi');
    });
  });

  group('the list of pets', () {
    testWidgets('a pet leads to the usual move window, and after it the list is shorter',
        (tester) async {
      _phone(tester);
      final moved = <String>[];
      final store = PetDemoStore.instance;
      await store.upsert(_pet('a', name: 'Rex'));
      await store.upsert(_pet('b', name: 'Luna'));
      await tester.pumpWidget(_app(MemorialChoosePage(service: _service(moved: moved))));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('memorial-choose-a')));
      await tester.pumpAndSettle();
      expect(find.byType(MemorialMovePage), findsOneWidget);

      await tester.ensureVisible(find.text('Continua'));
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();

      expect(find.byType(MemorialChoosePage), findsOneWidget, reason: 'back to the list');
      expect(moved, ['a']);
      expect(find.text('Rex è ora nei Ricordi.'), findsOneWidget);
      expect(find.byKey(const ValueKey('memorial-choose-a')), findsNothing);
      expect(find.byKey(const ValueKey('memorial-choose-b')), findsOneWidget);
      expect(store.memorialPets().single.id, 'a');
    });

    testWidgets('no "undo" is offered: bringing a pet back needs a plan', (tester) async {
      _phone(tester);
      await PetDemoStore.instance.upsert(_pet('a', name: 'Rex'));
      await tester.pumpWidget(_app(MemorialChoosePage(service: _service())));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('memorial-choose-a')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continua'));
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBarAction), findsNothing);
    });

    testWidgets('nothing to move: a calm line instead of an empty page', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(MemorialChoosePage(service: _service())));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('memorial-choose-empty')), findsOneWidget);
      expect(find.text('Non ci sono animali da spostare nei Ricordi.'), findsOneWidget);
    });

    testWidgets('with Ricordi full: the kind dialog, and the move window never opens',
        (tester) async {
      _phone(tester);
      final store = PetDemoStore.instance;
      await store.upsert(_pet('m1', memorial: true, name: 'Uno'));
      await store.upsert(_pet('m2', memorial: true, name: 'Due'));
      await store.upsert(_pet('a', name: 'Rex'));
      await tester.pumpWidget(_app(MemorialChoosePage(service: _service(cap: 2))));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('memorial-choose-a')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('memorial-move-blocked')), findsOneWidget);
      expect(find.byType(MemorialMovePage), findsNothing);
      expect(store.list().single.id, 'a');
    });
  });

  for (final language in ['it', 'en', 'es', 'de', 'fr']) {
    test('the new texts exist in $language and carry no plan or price', () {
      final l10n = lookupAppLocalizations(Locale(language));

      for (final text in [
        l10n.billingPaywallMoveToMemories,
        l10n.memorialChoosePrompt,
        l10n.memorialChooseEmpty,
      ]) {
        expect(text, isNotEmpty);
        expect(text, isNot(contains('{')));
        expect(text, isNot(contains('€')));
      }
      // The reminders sentence of the "Ricordi full" dialog names the section as the
      // app does, and the pet.
      final blocked = l10n.memorialMoveBlockedFull('Moka', 30);
      expect(blocked, contains(l10n.remindersTitle));
      expect('Moka'.allMatches(blocked).length, 2, reason: 'once for the pet, once for its reminders');
    });
  }
}
