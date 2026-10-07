import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../dog_walks/presentation/widgets/walk_map_style.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../../location/domain/coordinates.dart';
import '../../data/marketplace_repository.dart';
import '../../domain/listing_filters.dart';
import '../marketplace_labels.dart';
import 'listing_detail_page.dart';

/// Milano center, the same fallback the marketplace list uses when nothing
/// else gives the map a center.
const _fallbackCenter = Coordinates(latitude: 45.4642, longitude: 9.1900);

/// Zoom that roughly fits a circle of [radiusKm] in the viewport.
double marketplaceZoomForRadius(double? radiusKm) {
  if (radiusKm == null) return 11;
  if (radiusKm <= 2) return 13.5;
  if (radiusKm <= 5) return 12.5;
  if (radiusKm <= 10) return 11.5;
  return 10;
}

/// Listings that share one map point. Positions are snapped to the ~1 km
/// grid, so every listing of the same cell lands on the same coordinate:
/// one marker with a count instead of markers stacked on top of each other.
class ListingCluster {
  const ListingCluster(this.location, this.matches);

  final Coordinates location;
  final List<ListingMatch> matches;
}

List<ListingCluster> clusterListingsByLocation(List<ListingMatch> matches) {
  final byLocation = <Coordinates, List<ListingMatch>>{};
  for (final match in matches) {
    byLocation.putIfAbsent(match.listing.location, () => []).add(match);
  }
  return byLocation.entries.map((entry) => ListingCluster(entry.key, entry.value)).toList();
}

/// The already-filtered listings (same filter as the list page) on a map.
/// Basemap and attribution come from walk_map_style.dart, the app-wide map
/// style switch, so this map always matches the walk maps. Pops `true` when
/// a listing was changed from a detail page.
class MarketplaceMapPage extends StatefulWidget {
  const MarketplaceMapPage({
    super.key,
    required this.matches,
    this.reference,
    this.radiusKm,
    this.repository,
  });

  final List<ListingMatch> matches;
  final Coordinates? reference;
  final double? radiusKm;
  final MarketplaceRepository? repository;

  @override
  State<MarketplaceMapPage> createState() => _MarketplaceMapPageState();
}

class _MarketplaceMapPageState extends State<MarketplaceMapPage> {
  Future<void> _openCluster(ListingCluster cluster) async {
    if (cluster.matches.length == 1) {
      await _openListing(cluster.matches.single);
      return;
    }
    final picked = await showModalBottomSheet<ListingMatch>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
          children: [
            Text('${cluster.matches.length} annunci in questa zona', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            ...cluster.matches.map(
              (match) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: DashboardListRow(
                  title: match.listing.title,
                  subtitle:
                      '${listingCategoryLabel(match.listing.category)} · ${listingPriceLabel(match.listing.priceCents)}',
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
                  onTap: () => Navigator.of(context).pop(match),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) await _openListing(picked);
  }

  Future<void> _openListing(ListingMatch match) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ListingDetailPage(
          listing: match.listing,
          distanceMeters: match.distanceMeters,
          repository: widget.repository,
        ),
      ),
    );
    // The list behind owns the data: go back so it reloads.
    if (changed == true && mounted) Navigator.of(context).pop(true);
  }

  Coordinates _center() {
    if (widget.reference != null) return widget.reference!;
    if (widget.matches.isEmpty) return _fallbackCenter;
    final latitudes = widget.matches.map((match) => match.listing.location.latitude);
    final longitudes = widget.matches.map((match) => match.listing.location.longitude);
    return Coordinates(
      latitude: latitudes.reduce((a, b) => a + b) / widget.matches.length,
      longitude: longitudes.reduce((a, b) => a + b) / widget.matches.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _center();
    final centerPoint = latlong.LatLng(center.latitude, center.longitude);
    final clusters = clusterListingsByLocation(widget.matches);
    final reference = widget.reference;
    final radiusKm = widget.radiusKm;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Mappa del mercatino', style: AppTextStyles.title),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: centerPoint,
              initialZoom: marketplaceZoomForRadius(radiusKm),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.scrollWheelZoom,
              ),
            ),
            children: [
              buildWalkTileLayer(),
              if (reference != null && radiusKm != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: latlong.LatLng(reference.latitude, reference.longitude),
                      radius: radiusKm * 1000,
                      useRadiusInMeter: true,
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderColor: AppColors.primary.withValues(alpha: 0.5),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (reference != null)
                    Marker(
                      point: latlong.LatLng(reference.latitude, reference.longitude),
                      width: 18,
                      height: 18,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.info,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ...clusters.map(
                    (cluster) => Marker(
                      point: latlong.LatLng(cluster.location.latitude, cluster.location.longitude),
                      width: 44,
                      height: 44,
                      child: _ClusterMarker(
                        cluster: cluster,
                        onTap: () => _openCluster(cluster),
                      ),
                    ),
                  ),
                ],
              ),
              buildWalkMapAttribution(),
            ],
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.matches.isEmpty
                    ? 'Nessun annuncio con questi filtri.'
                    : '${widget.matches.length} annunci · posizioni approssimate (circa 1 km)',
                style: AppTextStyles.caption,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({required this.cluster, required this.onTap});

  final ListingCluster cluster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = cluster.matches.length;
    final single = count == 1 ? cluster.matches.single.listing : null;
    return Semantics(
      button: true,
      label: single?.title ?? '$count annunci',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.warning,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 6)],
          ),
          alignment: Alignment.center,
          child: single != null
              ? Icon(listingCategoryIcon(single.category), color: Colors.white, size: 20)
              : Text(
                  '$count',
                  style: AppTextStyles.button.copyWith(color: Colors.white),
                ),
        ),
      ),
    );
  }
}
