import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/shell/home_shell_page.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../../location/data/location_preference_store.dart';
import '../../../location/domain/coordinates.dart';
import '../../../location/presentation/reference_location.dart';
import '../../../settings/data/unit_settings_store.dart';
import '../../../territory/domain/territory.dart';
import '../../data/listing_radius_store.dart';
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
/// was ever set - then the Mercatino shows no ads at all (it is local: no
/// search without a centre) rather than measuring from an arbitrary city.
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
  // The radius the owner chose last time (kept on the phone), 50 km until
  // then; there is no "everywhere". Always km, whatever unit is shown.
  late ListingFilter _filter = ListingFilter(maxDistanceKm: ListingRadiusStore.instance.radiusKm);
  late Future<_MarketplaceViewData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    // The owner may set the position in Impostazioni and come back.
    LocationPreferenceStore.instance.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    LocationPreferenceStore.instance.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _onLocationChanged() {
    if (!mounted) return;
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<_MarketplaceViewData> _loadData() async {
    // The saved radius is read before the first search, so it is the one asked.
    await ListingRadiusStore.instance.ensureLoaded();
    _filter = _filter.withMaxDistance(ListingRadiusStore.instance.radiusKm);
    final reference = await (widget.referenceLoader ?? loadMarketplaceReferenceLocation)();
    // Without a position nothing is asked of the backend or the table.
    final listings = reference == null
        ? const <MarketplaceListing>[]
        : await _repository.loadNearbyListings(
            center: reference,
            radiusKm: clampMarketplaceRadiusKm(_filter.maxDistanceKm),
          );
    return _MarketplaceViewData(referenceLocation: reference, listings: listings);
  }

  Future<void> _reload() async {
    setState(() {
      _dataFuture = _loadData();
    });
    await _dataFuture;
  }

  /// A new radius asks again: the backend only returns what is inside it.
  void _selectRadius(double km) {
    unawaited(ListingRadiusStore.instance.save(km));
    setState(() {
      _filter = _filter.withMaxDistance(km);
      _dataFuture = _loadData();
    });
  }

  /// "Altro": any whole number of km (or miles, shown as such) from 1 to 300.
  Future<void> _askOtherRadius() async {
    final km = await showDialog<double>(
      context: context,
      builder: (_) => _OtherRadiusDialog(currentKm: _filter.maxDistanceKm),
    );
    if (km != null) _selectRadius(km);
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
        title: Text(context.l10n.marketplacePageTitle, style: AppTextStyles.title),
        actions: [
          FutureBuilder<_MarketplaceViewData>(
            future: _dataFuture,
            builder: (context, snapshot) => TextButton.icon(
              onPressed: snapshot.hasData ? () => _openMap(snapshot.data!) : null,
              icon: const Icon(Icons.map_outlined),
              label: Text(context.l10n.marketplaceMapAction),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateListing,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.marketplaceNewListing),
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
                    context.l10n.marketplaceIntro,
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.l10n.marketplaceRules,
                    key: const ValueKey('marketplace-rules'),
                    style: AppTextStyles.caption,
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
                    onSelected: _selectRadius,
                    onOther: _askOtherRadius,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (data.referenceLocation == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: Column(
                        children: [
                          Text(
                            context.l10n.marketplaceNeedsLocation,
                            style: AppTextStyles.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton.icon(
                            key: const ValueKey('marketplace-set-location'),
                            onPressed: HomeShellNavigation.showSettingsLocation,
                            icon: const Icon(Icons.place_outlined),
                            label: Text(context.l10n.marketplaceSetLocationAction),
                          ),
                        ],
                      ),
                    )
                  else if (matches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: Text(
                        context.l10n.marketplaceEmptyFiltered,
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
      listingPriceLabel(listing.priceCents, country: listing.country),
      listingDistanceLabel(match.distanceMeters),
      if (listingPlaceLabel(listing) case final place?) place,
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
              context.l10n.marketplaceLoadError,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
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
              label: Text(context.l10n.marketplaceFilterAllCategories),
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
              label: Text(context.l10n.marketplaceFilterAllSpecies),
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
    required this.onOther,
  });

  final double selected;
  final bool enabled;
  final ValueChanged<double> onSelected;
  final VoidCallback onOther;

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
          ...marketplaceRadiusOptionsKm.map(
            (km) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                key: ValueKey('marketplace-radius-${km.round()}'),
                label: Text(listingDistanceFilterLabel(km)),
                selected: selected == km,
                onSelected: enabled ? (_) => onSelected(km) : null,
              ),
            ),
          ),
          // "Altro" is selected whenever the radius is not one of the quick
          // choices, and then shows the value.
          ChoiceChip(
            key: const ValueKey('marketplace-radius-other'),
            label: Text(
              marketplaceRadiusOptionsKm.contains(selected)
                  ? context.l10n.marketplaceDistanceOther
                  : context.l10n.marketplaceDistanceOtherValue(
                      listingDistanceFilterLabel(selected),
                    ),
            ),
            selected: !marketplaceRadiusOptionsKm.contains(selected),
            onSelected: enabled ? (_) => onOther() : null,
          ),
        ],
      ),
    );
  }
}

/// The "Altro" field: one whole number in the unit the owner reads, checked
/// against 1-300 km before it is accepted; what comes out is always km.
class _OtherRadiusDialog extends StatefulWidget {
  const _OtherRadiusDialog({required this.currentKm});

  final double currentKm;

  @override
  State<_OtherRadiusDialog> createState() => _OtherRadiusDialogState();
}

class _OtherRadiusDialogState extends State<_OtherRadiusDialog> {
  late final bool _miles = UnitSettingsStore.instance.system.usesMiles;
  late final TextEditingController _controller = TextEditingController(
    text: marketplaceRadiusOptionsKm.contains(widget.currentKm)
        ? ''
        : (_miles ? kmToMiles(widget.currentKm).round() : widget.currentKm.round()).toString(),
  );
  bool _invalid = false;

  String get _unit => _miles ? 'mi' : 'km';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final km = marketplaceRadiusFromInput(_controller.text, miles: _miles);
    if (km == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(km);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final min = marketplaceMinRadiusKm.toInt();
    final max = marketplaceMaxRadiusInput(miles: _miles);
    return AlertDialog(
      title: Text(l10n.marketplaceDistanceDialogTitle),
      content: TextField(
        key: const ValueKey('marketplace-radius-field'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          helperText: l10n.marketplaceDistanceDialogHelp(min, max, _unit),
          helperMaxLines: 2,
          errorText: _invalid ? l10n.marketplaceDistanceDialogInvalid(min, max, _unit) : null,
          errorMaxLines: 3,
          suffixText: _unit,
        ),
        onChanged: (_) {
          if (_invalid) setState(() => _invalid = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('marketplace-radius-confirm'),
          onPressed: _submit,
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}
