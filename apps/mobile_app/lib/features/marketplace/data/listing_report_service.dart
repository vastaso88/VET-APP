import '../domain/marketplace_listing.dart';
import 'listing_reports_repository.dart';
import 'marketplace_repository.dart';

/// Mirrors packages/core/application/services/report_listing.py: saves the
/// report, then auto-removes the listing once enough distinct reporters
/// have flagged it. No moderation queue for MVP (docs/maps/) - this
/// threshold is the only safety lever.
const reportCountAutoRemoveThreshold = 3;

class ListingReportService {
  ListingReportService({
    MarketplaceRepository? listingRepository,
    ListingReportsRepository? reportRepository,
  })  : _listingRepository = listingRepository ?? MarketplaceRepository(),
        _reportRepository = reportRepository ?? ListingReportsRepository();

  final MarketplaceRepository _listingRepository;
  final ListingReportsRepository _reportRepository;

  Future<MarketplaceListing> report({
    required MarketplaceListing listing,
    required String reporterOwnerId,
    required String reason,
  }) async {
    await _reportRepository.save(
      ListingReport(
        id: 'report-${DateTime.now().microsecondsSinceEpoch}',
        listingId: listing.id,
        reporterOwnerId: reporterOwnerId,
        reason: reason,
        createdAt: DateTime.now(),
      ),
    );

    final reportCount = await _reportRepository.countDistinctReporters(listing.id);
    final updated = listing.copyWith(
      reportCount: reportCount,
      status: reportCount >= reportCountAutoRemoveThreshold ? ListingStatus.removed : null,
      updatedAt: DateTime.now(),
    );
    await _listingRepository.saveListing(updated);
    return updated;
  }
}
