import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/listing_report_service.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';

MarketplaceListing _listing(String id) {
  final now = DateTime.now();
  return MarketplaceListing(
    id: id,
    ownerId: 'seller-1',
    title: 'Annuncio test $id',
    category: ListingCategory.toys,
    condition: ListingCondition.good,
    location: const Coordinates(latitude: 45.4642, longitude: 9.1900),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('a single report does not remove the listing', () async {
    final listing = _listing('listing-report-a');
    final service = ListingReportService();

    final updated = await service.report(
      listing: listing,
      reporterOwnerId: 'user-1',
      reason: 'spam',
    );

    expect(updated.status, ListingStatus.active);
    expect(updated.reportCount, 1);
  });

  test('reaching the threshold of distinct reporters removes the listing', () async {
    final listing = _listing('listing-report-b');
    final service = ListingReportService();

    var current = listing;
    for (var i = 0; i < reportCountAutoRemoveThreshold; i++) {
      current = await service.report(
        listing: current,
        reporterOwnerId: 'user-$i',
        reason: 'scam',
      );
    }

    expect(current.status, ListingStatus.removed);
    expect(current.reportCount, reportCountAutoRemoveThreshold);
  });

  test('repeated reports from the same user do not count multiple times', () async {
    final listing = _listing('listing-report-c');
    final service = ListingReportService();

    var current = listing;
    for (var i = 0; i < reportCountAutoRemoveThreshold; i++) {
      current = await service.report(listing: current, reporterOwnerId: 'user-x', reason: 'spam');
    }

    expect(current.status, ListingStatus.active);
    expect(current.reportCount, 1);
  });
}
