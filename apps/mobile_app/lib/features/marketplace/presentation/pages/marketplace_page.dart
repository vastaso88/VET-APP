import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../../location/data/location_preference_store.dart';
import '../../../location/domain/coordinates.dart';
import '../../../location/presentation/reference_location.dart';
import '../../data/marketplace_repository.dart';
import '../../domain/listing_filters.dart';
import '../../domain/marketplace_listing.dart';
import '../marketplace_labels.dart';
import '../widgets/listing_photo.dart';
import 'create_listing_page.dart';
import 'listing_detail_page.dart';
import 'marketplace_map_page.dart';

/// The user's position for distances: the Località preference (its mode
/// decides between current position and residence), or null when neither
/// was ever set - then the distance filter is off rather than measuring
/// from an arbitrary city.
Future<Coordinates?> loadMarketplaceReferenceLocation() async {
  await LocationPreferenceStore.instance.ensureLoaded();
  final preference = LocationPreferenceStore.instance.preference;
  if (preference.current == null && preference.home == null) return null;
  return resolveReferenceLocation(preference, preference.current ?? preference.home!);
}

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key, this.repository, this.referenceLoader});

  /// Injectable for widget tests.
  final MarketplaceRepository? repository;
  final Future<Coordinates?> Function()? referenceLoader;

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  late final MarketplaceRepository _repository = widget.repository ?? MarketplaceRepository();
  ListingFilter _filter = const ListingFilter();
  bool _distanceInitialized = false;
  late Future<_MarketplaceViewData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_MarketplaceViewData> _loadData() async {
    final reference = await (widget.referenceLoader ?? loadMarketplaceReferenceLocation)();
    final listings = await _repository.loadActiveListings();
    if (!_distanceInitialized) {
      _distanceInitialized = true;
      // 25 km by default, "Ovunque" for users without a position (owner
      // decision, 2026-10-07).
      _filter = _filter.withMaxDistance(reference != null ? defaultListingDistanceKm : null);
    }
    return _MarketplaceViewData(referenceLocation: reference, listings: listings);
  }

  Future<void> _reload() async {
    setState(() {
      _dataFuture = _loadData();
    });
    await _dataFuture;
  }

  Future<void> _openCreateListing() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => CreateListingPage(repository: _repository)),
    );
    if (created == true) await _reload();
  }

  Future<void> _openListing(ListingMatch match) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ListingDetailPage(
          listing: match.listing,
          distanceMeters: match.distanceMeters,
          repository: _repository,
        ),
      ),
    );
    if (changed == true) await _reload();
  }

  Future<void> _openMap(_MarketplaceViewData data) async {
    final reference = data.referenceLocation;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MarketplaceMapPage(
          matches: applyListingFilter(data.listings, _filter, reference: reference),
          reference: reference,
          radiusKm: reference == null ? null : _filter.maxDistanceKm,
          repository: _repository,
        ),
      ),
    );
    if (changed == true) await _reload();
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
        actions: [
          FutureBuilder<_MarketplaceViewData>(
            future: _dataFuture,
            builder: (context, snapshot) => TextButton.icon(
              onPressed: snapshot.hasData ? () => _openMap(snapshot.data!) : null,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Mappa'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
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
            if (snapshot.hasError) {
              return _LoadError(onRetry: _reload);
            }
            if (!snapshot.hasData) {
              return const Center(child: PetLoader());
            }

            final data = snapshot.data!;
            final matches = applyListingFilter(
              data.listings,
              _filter,
              reference: data.referenceLocation,
            );

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xxxxl + AppSpacing.xl,
                ),
                children: [
                  Text(
                    'Compra, vendi e regala articoli per animali con altri proprietari.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _CategoryFilterRow(
                    selected: _filter.category,
                    onSelected: (category) =>
                        setState(() => _filter = _filter.withCategory(category)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SpeciesFilterRow(
                    selected: _filter.species,
                    onSelected: (species) => setState(() => _filter = _filter.withSpecies(species)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DistanceFilterRow(
                    selected: _filter.maxDistanceKm,
                    enabled: data.referenceLocation != null,
                    onSelected: (km) => setState(() => _filter = _filter.withMaxDistance(km)),
                  ),
                  if (data.referenceLocation == null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Per filtrare per distanza imposta la tua posizione in Impostazioni → Località.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (matches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: Text(
                        'Nessun annuncio con questi filtri per ora.',
                        style: AppTextStyles.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...matches.map(
                      (match) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _ListingRow(match: match, onTap: () => _openListing(match)),
                      ),
                    ),
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

  final Coordinates? referenceLocation;
  final List<MarketplaceListing> listings;
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.match, required this.onTap});

  final ListingMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final listing = match.listing;
    final details = [
      listingConditionLabel(listing.condition),
      listingPriceLabel(listing.priceCents),
      if (match.distanceMeters != null) listingDistanceLabel(match.distanceMeters),
      if (listing.cityLabel != null) listing.cityLabel!,
    ];
    return DashboardListRow(
      title: listing.title,
      subtitle: details.join(' · '),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: SizedBox(
          width: 52,
          height: 52,
          child: listing.photoUrls.isNotEmpty
              ? ListingPhoto(url: listing.photoUrls.first)
              : ColoredBox(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  child: Icon(listingCategoryIcon(listing.category), color: AppColors.warning),
                ),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
      onTap: onTap,
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Non riesco a caricare gli annunci. Controlla la connessione.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Riprova')),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow({required this.selected, required this.onSelected});

  final ListingCategory? selected;
  final ValueChanged<ListingCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
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

/// "Tutti gli animali" plus each concrete species. Picking one also keeps
/// the listings meant for all species (ListingSpecies.allSpecies).
class _SpeciesFilterRow extends StatelessWidget {
  const _SpeciesFilterRow({required this.selected, required this.onSelected});

  final ListingSpecies? selected;
  final ValueChanged<ListingSpecies?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: const Text('Tutti gli animali'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...ListingSpecies.values.where((species) => species != ListingSpecies.allSpecies).map(
                (species) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(listingSpeciesLabel(species)),
                    selected: selected == species,
                    onSelected: (_) => onSelected(species),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _DistanceFilterRow extends StatelessWidget {
  const _DistanceFilterRow({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final double? selected;
  final bool enabled;
  final ValueChanged<double?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Icon(
              Icons.near_me_outlined,
              size: 18,
              color: enabled ? AppColors.secondaryText : AppColors.mutedText,
            ),
          ),
          ...listingDistanceOptionsKm.map(
            (km) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(listingDistanceFilterLabel(km)),
                selected: selected == km,
                onSelected: enabled ? (_) => onSelected(km) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
