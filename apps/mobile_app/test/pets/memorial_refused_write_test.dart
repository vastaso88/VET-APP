import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/features/billing/data/plan_access_refusal.dart';
import 'package:vet_app_mobile/features/chat/data/chat_attachment_remote_data_source.dart';
import 'package:vet_app_mobile/features/pets/application/memorial_service.dart';
import 'package:vet_app_mobile/features/pets/data/memorial_moments.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_memorial_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

/// A move to / return from Ricordi the server refuses is undone here and the
/// real reason is shown; a pet in Ricordi says plainly that it is read-only
/// and where the way back is. Synthetic data only.
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

const _noPlan = PostgrestException(message: 'subscription_required', code: 'PT402');
const _inMemories = PostgrestException(message: 'pet_in_memories', code: 'PT409');

MemorialService _service() => MemorialService(
      store: PetDemoStore.instance,
      stopWalkOf: (_) async {},
      revokeRecordsConsent: (_) async {},
      onMoved: (_) {},
      onRestored: () {},
      planLimit: () => (limit: null, upgradePlan: null),
    );

class _FakeConfigLoader extends AppRuntimeConfigLoader {
  const _FakeConfigLoader();

  @override
  AppRuntimeConfig load() => const AppRuntimeConfig(
        environment: AppEnvironment.development,
        appName: 'test',
        apiBaseUrl: 'http://api.test',
        supabaseUrl: '',
        supabaseAnonKey: '',
        logLevel: 'INFO',
        enableTelemetry: false,
      );
}

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  setUp(PetDemoStore.instance.reset);
  tearDown(() => PetDemoStore.instance.debugUpsertRow = null);

  group('the pet in Ricordi refusal is recognised', () {
    test('from the database', () {
      expect(planRefusalFromError(_inMemories)?.kind, PlanRefusalKind.petInMemories);
      expect(planRefusalFromError(_noPlan)?.kind, PlanRefusalKind.subscriptionRequired);
    });

    test('from the backend 409, and only with its code', () {
      expect(
        planRefusalFromHttp(409, jsonEncode({'detail': 'pet_in_memories', 'code': 'pet_in_memories'}))
            ?.kind,
        PlanRefusalKind.petInMemories,
      );
      expect(planRefusalFromHttp(409, jsonEncode({'code': 'something_else'})), isNull);
    });

    test('its message says Ricordi are read-only and how to come back', () {
      const refusal = PlanAccessRefusal(PlanRefusalKind.petInMemories);

      expect(refusal.message, contains('Ricordi'));
      expect(refusal.message, contains('sola lettura'));
      expect(refusal.message, contains('riportalo tra gli animali'));
    });
  });

  group('a refused return or move is undone here', () {
    test('the return the server refuses leaves the pet in Ricordi and says why', () async {
      final store = PetDemoStore.instance;
      final memorial = await store.upsert(_pet('m', memorial: true));
      store.debugUpsertRow = (_) async => throw _inMemories;

      await expectLater(
        _service().restore(memorial),
        throwsA(isA<PetSyncException>().having((e) => e.message, 'message', contains('sola lettura'))),
      );

      expect(store.memorialPets().single.id, 'm', reason: 'still in Ricordi, as on the server');
      expect(store.list(), isEmpty);
      expect(store.isUnsynced('m'), isFalse, reason: 'nothing pending: it is simply as it was');
    });

    test('any other failure (a lost connection) is undone too, with the generic text', () async {
      final store = PetDemoStore.instance;
      final memorial = await store.upsert(_pet('m', memorial: true));
      store.debugUpsertRow = (_) async => throw Exception('offline');

      await expectLater(_service().restore(memorial), throwsA(isA<PetSyncException>()));

      expect(store.memorialPets().single.id, 'm');
      expect(store.list(), isEmpty);
    });

    test('the move the server refuses leaves the pet among the active ones', () async {
      final store = PetDemoStore.instance;
      final active = await store.upsert(_pet('a'));
      store.debugUpsertRow = (_) async => throw _noPlan;

      await expectLater(
        _service().moveToMemories(active, lossDate: DateTime(2026, 11, 1)),
        throwsA(isA<PetSyncException>()),
      );

      expect(store.list().single.id, 'a');
      expect(store.memorialPets(), isEmpty);
    });

    test('a refusal that is not a failure does not change: an accepted return works', () async {
      final store = PetDemoStore.instance;
      final memorial = await store.upsert(_pet('m', memorial: true));

      final back = await _service().restore(memorial);

      expect(back.isMemorial, isFalse);
      expect(store.list().single.id, 'm');
    });
  });

  group('step (a): the upload for a pet in Ricordi', () {
    test('the backend 409 becomes a clear refusal, not a generic failed upload', () async {
      final source = HttpChatAttachmentRemoteDataSource(
        client: MockClient((_) async => http.Response(
              jsonEncode({'detail': 'pet_in_memories', 'code': 'pet_in_memories'}),
              409,
            )),
        configLoader: const _FakeConfigLoader(),
      );

      final result = await source.upload(
        petId: 'm',
        imageBytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]),
        fileName: 'referto.jpg',
      );

      final error = result.fold(onSuccess: (_) => null, onFailure: (error) => error);
      expect(error?.code, 'pet_in_memories');
      expect(error?.message, contains('sola lettura'));
    });
  });

  group('the page of a pet in Ricordi', () {
    testWidgets('says it is read-only and shows the way back clearly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final pet = await PetDemoStore.instance.upsert(_pet('m', memorial: true));

      await tester.pumpWidget(_app(PetMemorialPage(
        pet: pet,
        loadMoments: (_) async => const MemorialMoments(),
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('memorial-read-only-notice')), findsOneWidget);
      expect(find.textContaining('non modificare'), findsOneWidget);
      expect(find.byKey(const ValueKey('memorial-restore')), findsOneWidget);
      expect(find.text('Spostata per errore? Riporta tra gli animali'), findsOneWidget);
    });
  });
}
