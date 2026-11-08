import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/features/billing/data/billing_demo_store.dart';
import 'package:vet_app_mobile/features/billing/data/subscription_remote_data_source.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/billing/domain/subscription_status.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/listing_radius_store.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_repository.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/listing_detail_page.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/marketplace_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

import '../territory/territory_test_helpers.dart';

const _me = Coordinates(latitude: 45.46, longitude: 9.19);

class _FakeSource implements SubscriptionRemoteDataSource {
  _FakeSource(this.status);

  final SubscriptionStatus status;

  @override
  Future<Result<SubscriptionStatus>> fetchStatus() async => Result.success(status);

  @override
  Future<Result<SubscriptionStatus>> selectPlan(PlanTier plan) async =>
      Result.failure(const AppNetworkError(code: 'no', message: 'no'));
}

Future<void> _setAccess({required bool hasAccess}) => BillingDemoStore.instance.syncFromBackend(
      dataSource: _FakeSource(
        SubscriptionStatus(
          trialEndsAt: DateTime.now().add(Duration(days: hasAccess ? 5 : -5)),
          plan: null,
          isDeveloper: false,
          hasAccess: hasAccess,
        ),
      ),
    );

MarketplaceListing _limited(String id, {double distanceMeters = 2500}) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  return MarketplaceListing(
    id: id,
    ownerId: '',
    title: 'Trasportino $id',
    category: ListingCategory.other,
    condition: ListingCondition.good,
    priceCents: 2500,
    location: const Coordinates(latitude: 0, longitude: 0),
    cityLabel: 'Milano',
    createdAt: epoch,
    updatedAt: epoch,
    isLimited: true,
    serverDistanceMeters: distanceMeters,
  );
}

MarketplaceListing _full(String id) {
  final now = DateTime(2026, 10, 7);
  return MarketplaceListing(
    id: id,
    ownerId: 'seller',
    title: 'Pallina $id',
    description: 'Poco usata',
    category: ListingCategory.toys,
    condition: ListingCondition.good,
    priceCents: 400,
    species: const [ListingSpecies.dog],
    location: Coordinates(latitude: _me.latitude + 0.01, longitude: _me.longitude),
    createdAt: now,
    updatedAt: now,
  );
}

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

Future<void> _pumpPage(WidgetTester tester, List<MarketplaceListing> listings) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _app(
      MarketplacePage(
        repository: MarketplaceRepository.inMemory(listings),
        referenceLoader: () async => _me,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ListingRadiusStore.instance.resetForTest();
    await useLanguageVariant('it');
  });
  tearDown(() async {
    resetTerritoryForTest();
    await _setAccess(hasAccess: true);
  });

  testWidgets('without a plan the list shows the ads, a notice and no way to act', (tester) async {
    await _setAccess(hasAccess: false);

    await _pumpPage(tester, [_limited('uno'), _limited('due', distanceMeters: 4000)]);

    expect(find.text('Trasportino uno'), findsOneWidget);
    expect(find.text('Trasportino due'), findsOneWidget);
    expect(find.byKey(const ValueKey('marketplace-limited-notice')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing, reason: 'no new ad');
    expect(find.byIcon(Icons.map_outlined), findsNothing, reason: 'no map');
  });

  testWidgets('without a plan the detail shows the first look, a notice and only the report button',
      (tester) async {
    await _setAccess(hasAccess: false);
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        ListingDetailPage(
          listing: _limited('uno'),
          distanceMeters: 2500,
          repository: MarketplaceRepository.inMemory([_limited('uno')]),
          currentOwnerId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('marketplace-limited-notice')), findsOneWidget);
    // Owner decision 2026-11-08: reporting stays open without a plan.
    expect(find.text('Segnala annuncio'), findsOneWidget);
    expect(find.text('Modifica annuncio'), findsNothing);
  });

  testWidgets('with a plan the list is the full one: new-ad button, map, no notice',
      (tester) async {
    await _setAccess(hasAccess: true);

    await _pumpPage(tester, [_full('uno')]);

    expect(find.text('Pallina uno'), findsOneWidget);
    expect(find.byKey(const ValueKey('marketplace-limited-notice')), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
  });
}
