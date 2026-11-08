import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/auth/current_owner.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../data/listing_report_service.dart';
import '../../data/marketplace_messages_repository.dart';
import '../../data/marketplace_repository.dart';
import '../../domain/marketplace_conversation.dart';
import '../../domain/marketplace_listing.dart';
import '../marketplace_labels.dart';
import '../widgets/limited_marketplace_notice.dart';
import '../widgets/listing_photo.dart';
import 'create_listing_page.dart';
import 'marketplace_conversation_page.dart';

/// Pops `true` whenever the listing changed (edited, deleted, removed by
/// reports) so the list reloads.
class ListingDetailPage extends StatefulWidget {
  const ListingDetailPage({
    super.key,
    required this.listing,
    this.distanceMeters,
    this.repository,
    this.currentOwnerId,
    this.messagesRepository,
  });

  final MarketplaceListing listing;
  final double? distanceMeters;
  final MarketplaceRepository? repository;
  final String? currentOwnerId;
  final MarketplaceMessagesRepository? messagesRepository;

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  late final MarketplaceRepository _repository = widget.repository ?? MarketplaceRepository();
  bool _busy = false;

  Map<String, String> _reasons(BuildContext context) => {
        'spam': context.l10n.marketplaceReasonSpam,
        'scam': context.l10n.marketplaceReasonScam,
        'prohibited_item': context.l10n.marketplaceReasonProhibitedItem,
        'inappropriate': context.l10n.marketplaceReasonInappropriate,
        'sells_animals': context.l10n.marketplaceReasonSellsAnimals,
        'other': context.l10n.marketplaceOther,
      };

  String get _currentOwnerId => widget.currentOwnerId ?? resolveCurrentOwnerId();

  // Whether "Scrivi al venditore" can be offered. Asked once; while it is on its
  // way, or when the backend cannot be asked, the button stays (a tap then
  // explains). A false answer shows a neutral sentence: it never says why.
  ListingMessagingStatus? _messaging;

  @override
  void initState() {
    super.initState();
    final listing = widget.listing;
    if (!listing.isLimited && !canManageListing(listing, _currentOwnerId)) {
      unawaited(_loadMessaging());
    }
  }

  Future<void> _loadMessaging() async {
    try {
      final status = await (widget.messagesRepository ?? MarketplaceMessagesRepository())
          .listingStatus(widget.listing.id);
      if (mounted) setState(() => _messaging = status);
    } on Exception {
      // Keep the button: the conversation page says what went wrong.
    }
  }

  bool get _canWriteToSeller {
    final status = _messaging;
    return status == null || status.conversation != null || status.canStart;
  }

  Future<void> _writeToSeller() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MarketplaceConversationPage(
          listingId: widget.listing.id,
          listingTitle: widget.listing.title,
          repository: widget.messagesRepository,
        ),
      ),
    );
  }

  Future<void> _reportListing() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.marketplaceReportListing),
        children: _reasons(context)
            .entries
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
              ? context.l10n.marketplaceReportRemoved
              : context.l10n.marketplaceReportSent,
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
        title: Text(context.l10n.marketplaceDeleteConfirmTitle),
        content: Text(context.l10n.marketplaceDeleteConfirmBody(widget.listing.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(context.l10n.commonDelete),
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
                : context.l10n.marketplaceDeleteFailed,
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.marketplaceDeleted)));
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
                if (!listing.isLimited) ...[
                  DashboardBadge(
                    label: listingCategoryLabel(listing.category),
                    tone: DashboardTone.info,
                  ),
                  DashboardBadge(
                    label: listingConditionLabel(listing.condition),
                    tone: DashboardTone.neutral,
                  ),
                ],
                if (widget.distanceMeters != null)
                  DashboardBadge(
                    label: listingDistanceLabel(widget.distanceMeters),
                    icon: Icons.location_on_outlined,
                    tone: DashboardTone.primary,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(listingPriceLabel(listing.priceCents, country: listing.country),
                style: AppTextStyles.heading),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.marketplaceDetailPrivateSeller,
              key: const ValueKey('listing-private-seller'),
              style: AppTextStyles.caption,
            ),
            if (listingPlaceLabel(listing) case final place?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                listing.cityLabel == null ? place : context.l10n.marketplaceDetailApproxZone(place),
                key: const ValueKey('listing-place'),
                style: AppTextStyles.bodySmall,
              ),
            ],
            if (listing.species.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.marketplaceDetailForSpecies(
                  listing.species.map(listingSpeciesLabel).join(', '),
                ),
                style: AppTextStyles.bodySmall,
              ),
            ],
            if (listing.description != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(listing.description!, style: AppTextStyles.body),
            ],
            if (listing.isLimited) ...[
              const SizedBox(height: AppSpacing.xl),
              const LimitedMarketplaceNotice(),
            ],
            const SizedBox(height: AppSpacing.xxl),
            // Without a plan the only action left is reporting (owner decision
            // 2026-11-08): the backend accepts it from everyone.
            if (listing.isLimited && !isOwner)
              DashboardActionButton(
                key: const ValueKey('marketplace-report-listing'),
                label: _busy
                    ? context.l10n.marketplaceReporting
                    : context.l10n.marketplaceReportListing,
                icon: Icons.flag_outlined,
                tone: DashboardTone.danger,
                filled: false,
                onPressed: _busy ? null : _reportListing,
              )
            else if (isOwner) ...[
              if (!listing.isLimited) ...[
                DashboardActionButton(
                  label: context.l10n.marketplaceEditListing,
                  icon: Icons.edit_outlined,
                  onPressed: _busy ? null : _editListing,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              DashboardActionButton(
                label: _busy
                    ? context.l10n.marketplaceDeleting
                    : context.l10n.marketplaceDeleteListing,
                icon: Icons.delete_outline_rounded,
                tone: DashboardTone.danger,
                filled: false,
                onPressed: _busy ? null : _deleteListing,
              ),
            ] else ...[
              if (_canWriteToSeller)
                DashboardActionButton(
                  key: const ValueKey('marketplace-write-to-seller'),
                  label: context.l10n.marketplaceMessagesWriteToSeller,
                  icon: Icons.mail_outline_rounded,
                  onPressed: _busy ? null : _writeToSeller,
                )
              else
                Text(
                  context.l10n.marketplaceMessagesUnavailable,
                  key: const ValueKey('marketplace-write-unavailable'),
                  style: AppTextStyles.bodySmall,
                ),
              const SizedBox(height: AppSpacing.md),
              DashboardActionButton(
                label: _busy
                    ? context.l10n.marketplaceReporting
                    : context.l10n.marketplaceReportListing,
                icon: Icons.flag_outlined,
                tone: DashboardTone.danger,
                filled: false,
                onPressed: _busy ? null : _reportListing,
              ),
            ],
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
