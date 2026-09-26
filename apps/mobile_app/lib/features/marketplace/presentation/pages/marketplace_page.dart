import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../../location/data/location_preference_store.dart';
import '../../../location/domain/coordinates.dart';
import '../../../location/domain/geo_math.dart';
import '../../../location/presentation/reference_location.dart';
import '../../data/marketplace_repository.dart';
import '../../domain/marketplace_listing.dart';
import '../marketplace_labels.dart';
import 'create_listing_page.dart';
import 'listing_detail_page.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  // Milano center, same fallback used by the maps demo route - lets
  // distances/sorting still make sense before the user has ever set a
  // Località preference or granted GPS access.
  static const _fallbackLocation = Coordinates(latitude: 45.4642, longitude: 9.1900);

  final _repository = MarketplaceRepository();
  ListingCategory? _categoryFilter;
  late Future<_MarketplaceViewData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_MarketplaceViewData> _loadData() async {
    await LocationPreferenceStore.instance.ensureLoaded();
    final preference = LocationPreferenceStore.instance.preference;
    final referenceLocation = resolveReferenceLocation(preference, _fallbackLocation);

    final listings = await _repository.loadActiveListings();
    return _MarketplaceViewData(referenceLocation: referenceLocation, listings: listings);
  }

  Future<void> _reload() async {
    setState(() {
      _dataFuture = _loadData();
    });
    await _dataFuture;
  }

  Future<void> _openCreateListing() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const CreateListingPage()),
    );
    if (created == true) {
      await _reload();
    }
  }

  Future<void> _openListing(MarketplaceListing listing, double distanceMeters) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ListingDetailPage(listing: listing, distanceMeters: distanceMeters),
      ),
    );
    if (changed == true) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Mercatino dell\'usato', style: AppTextStyles.title),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateListing,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo annuncio'),
      ),
      body: SafeArea(
        child: FutureBuilder<_MarketplaceViewData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            final filtered = _categoryFilter == null
                ? data.listings
                : data.listings.where((listing) => listing.category == _categoryFilter).toList();

            final sorted = [...filtered]
              ..sort(
                (a, b) => haversineMeters(data.referenceLocation, a.location)
                    .compareTo(haversineMeters(data.referenceLocation, b.location)),
              );

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xxxl,
                ),
                children: [
                  Text(
                    'Compra, vendi e scambia articoli per animali con altri proprietari.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _CategoryFilterRow(
                    selected: _categoryFilter,
                    onSelected: (category) => setState(() => _categoryFilter = category),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (sorted.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: Text(
                        'Nessun annuncio in questa categoria per ora.',
                        style: AppTextStyles.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...sorted.map((listing) {
                      final distanceMeters = haversineMeters(data.referenceLocation, listing.location);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: DashboardListRow(
                          title: listing.title,
                          subtitle:
                              '${listingConditionLabel(listing.condition)} · ${listingPriceLabel(listing.priceCents)} · ${listingDistanceLabel(distanceMeters)}',
                          leading: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(AppRadii.medium),
                            ),
                            child: const Icon(Icons.storefront_outlined, color: AppColors.warning),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
                          onTap: () => _openListing(listing, distanceMeters),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MarketplaceViewData {
  const _MarketplaceViewData({required this.referenceLocation, required this.listings});

  final Coordinates referenceLocation;
  final List<MarketplaceListing> listings;
}

class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow({required this.selected, required this.onSelected});

  final ListingCategory? selected;
  final ValueChanged<ListingCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: const Text('Tutte'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...ListingCategory.values.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(listingCategoryLabel(category)),
                selected: selected == category,
                onSelected: (_) => onSelected(category),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
