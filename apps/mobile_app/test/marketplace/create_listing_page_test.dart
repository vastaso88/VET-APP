import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/location/data/device_location_service.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_repository.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/create_listing_page.dart';

class _FakeLocationSampler implements LocationSampler {
  const _FakeLocationSampler(this.result);

  final DeviceLocationResult result;

  @override
  Future<DeviceLocationResult> requestCurrentPosition() async => result;
}

/// The form has more fields than the default 800x600 test surface shows at
/// once, and ListView only builds widgets within its viewport - same fix
/// as chat_feature_test.dart's _useTallSurface.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('submitting the form fuzzes the position and saves a new active listing', (
    tester,
  ) async {
    await _useTallSurface(tester);
    const exact = Coordinates(latitude: 45.4642, longitude: 9.1900);
    await tester.pumpWidget(
      const MaterialApp(
        home: CreateListingPage(
          locationSampler: _FakeLocationSampler(DeviceLocationResult.success(exact)),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Titolo'), 'Guinzaglio test');
    await tester.tap(find.text('Pubblica annuncio'));
    await tester.pumpAndSettle();

    final repository = MarketplaceRepository();
    final listings = await repository.loadActiveListings();
    final created = listings.where((listing) => listing.title == 'Guinzaglio test');

    expect(created, hasLength(1));
    expect(created.first.location, isNot(exact));
  });

  testWidgets('a location failure blocks submission with a visible error', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: CreateListingPage(
          locationSampler: _FakeLocationSampler(
            DeviceLocationResult.failure(LocationRequestFailure.permissionDenied),
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Titolo'), 'Annuncio senza posizione');
    await tester.tap(find.text('Pubblica annuncio'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Non riesco a rilevare la tua posizione'), findsOneWidget);
    // Still on the create page - no pop happened.
    expect(find.text('Nuovo annuncio'), findsOneWidget);
  });

  testWidgets('a negative price blocks submission with a validation error', (tester) async {
    await _useTallSurface(tester);
    const exact = Coordinates(latitude: 45.4642, longitude: 9.1900);
    await tester.pumpWidget(
      const MaterialApp(
        home: CreateListingPage(
          locationSampler: _FakeLocationSampler(DeviceLocationResult.success(exact)),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Titolo'), 'Ciotola test');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prezzo in € (vuoto = gratis)'),
      '-5',
    );
    await tester.tap(find.text('Pubblica annuncio'));
    await tester.pumpAndSettle();

    expect(find.text('Il prezzo non può essere negativo'), findsOneWidget);
    expect(find.text('Nuovo annuncio'), findsOneWidget);

    final repository = MarketplaceRepository();
    final listings = await repository.loadActiveListings();
    expect(listings.where((listing) => listing.title == 'Ciotola test'), isEmpty);
  });
}
