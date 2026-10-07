import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/auth/current_owner.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../data/listing_report_service.dart';
import '../../data/marketplace_repository.dart';
import '../../domain/marketplace_listing.dart';
import '../marketplace_labels.dart';
import '../widgets/listing_photo.dart';
import 'create_listing_page.dart';

/// Pops `true` whenever the listing changed (edited, deleted, removed by
/// reports) so the list reloads.
class ListingDetailPage extends StatefulWidget {
  const ListingDetailPage({
    super.key,
    required this.listing,
    this.distanceMeters,
    this.repository,
    this.currentOwnerId,
  });

  final MarketplaceListing listing;
  final double? distanceMeters;
  final MarketplaceRepository? repository;
  final String? currentOwnerId;

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  late final MarketplaceRepository _repository = widget.repository ?? MarketplaceRepository();
  bool _busy = false;

  static const _reasons = {
    'spam': 'Spam',
    'scam': 'Truffa',
    'prohibited_item': 'Articolo non consentito',
    'inappropriate': 'Contenuto inappropriato',
    'other': 'Altro',
  };

  String get _currentOwnerId => widget.currentOwnerId ?? resolveCurrentOwnerId();

  Future<void> _reportListing() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Segnala annuncio'),
        children: _reasons.entries
            .map(
              (entry) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(entry.key),
                child: Text(entry.value),
              ),
            )
            .toList(),
      ),
    );
    if (reason == null) return;

    setState(() => _busy = true);
    final updated = await ListingReportService(listingRepository: _repository).report(
      listing: widget.listing,
      reporterOwnerId: _currentOwnerId,
      reason: reason,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.status == ListingStatus.removed
              ? 'Grazie, l\'annuncio è stato rimosso dopo le segnalazioni ricevute.'
              : 'Segnalazione inviata, grazie.',
        ),
      ),
    );

    if (updated.status == ListingStatus.removed) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _editListing() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateListingPage(
          existing: widget.listing,
          repository: _repository,
          currentOwnerId: widget.currentOwnerId,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    // The edit page doesn't hand the result back; the list reloads it.
    Navigator.of(context).pop(true);
  }

  Future<void> _deleteListing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare l\'annuncio?'),
        content: Text(
            '"${widget.listing.title}" e le sue foto verranno cancellati. Non si può annullare.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _repository.deleteListing(widget.listing, requesterId: _currentOwnerId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ListingPermissionException
                ? error.toString()
                : 'Non sono riuscito a eliminare l\'annuncio. Riprova.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Annuncio eliminato.')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final isOwner = canManageListing(listing, _currentOwnerId);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(listing.title, style: AppTextStyles.title, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          children: [
            if (listing.photoUrls.isNotEmpty) ...[
              _PhotoCarousel(urls: listing.photoUrls),
              const SizedBox(height: AppSpacing.xl),
            ],
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                DashboardBadge(
                  label: listingCategoryLabel(listing.category),
                  tone: DashboardTone.info,
                ),
                DashboardBadge(
                  label: listingConditionLabel(listing.condition),
                  tone: DashboardTone.neutral,
                ),
                if (widget.distanceMeters != null)
                  DashboardBadge(
                    label: listingDistanceLabel(widget.distanceMeters),
                    icon: Icons.location_on_outlined,
                    tone: DashboardTone.primary,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(listingPriceLabel(listing.priceCents), style: AppTextStyles.heading),
            if (listing.cityLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('${listing.cityLabel!} · zona approssimata', style: AppTextStyles.bodySmall),
            ],
            if (listing.species.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Per: ${listing.species.map(listingSpeciesLabel).join(', ')}',
                style: AppTextStyles.bodySmall,
              ),
            ],
            if (listing.description != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(listing.description!, style: AppTextStyles.body),
            ],
            const SizedBox(height: AppSpacing.xxl),
            if (isOwner) ...[
              DashboardActionButton(
                label: 'Modifica annuncio',
                icon: Icons.edit_outlined,
                onPressed: _busy ? null : _editListing,
              ),
              const SizedBox(height: AppSpacing.md),
              DashboardActionButton(
                label: _busy ? 'Eliminazione...' : 'Elimina annuncio',
                icon: Icons.delete_outline_rounded,
                tone: DashboardTone.danger,
                filled: false,
                onPressed: _busy ? null : _deleteListing,
              ),
            ] else
              DashboardActionButton(
                label: _busy ? 'Invio segnalazione...' : 'Segnala annuncio',
                icon: Icons.flag_outlined,
                tone: DashboardTone.danger,
                filled: false,
                onPressed: _busy ? null : _reportListing,
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.urls});

  final List<String> urls;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.large),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: PageView.builder(
              itemCount: widget.urls.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) => ListingPhoto(url: widget.urls[index]),
            ),
          ),
        ),
        if (widget.urls.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.urls.length,
              (index) => Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _page ? AppColors.primary : AppColors.borderStrong,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
