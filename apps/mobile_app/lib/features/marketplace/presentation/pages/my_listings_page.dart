import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/auth/current_owner.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../data/marketplace_repository.dart';
import '../../domain/marketplace_listing.dart';
import '../marketplace_labels.dart';
import '../widgets/listing_removal_notice.dart';
import 'listing_detail_page.dart';

/// The owner's own ads, whatever their state: the only place where an ad the team
/// took down is still to be found, with the reason. Open with or without a plan.
/// Pops `true` when something changed, so the Mercatino reloads.
class MyListingsPage extends StatefulWidget {
  const MyListingsPage({super.key, this.repository, this.currentOwnerId});

  final MarketplaceRepository? repository;
  final String? currentOwnerId;

  @override
  State<MyListingsPage> createState() => _MyListingsPageState();
}

class _MyListingsPageState extends State<MyListingsPage> {
  late final MarketplaceRepository _repository = widget.repository ?? MarketplaceRepository();
  List<MarketplaceListing>? _listings;
  bool _failed = false;

  /// The server answered without the ads: the connection is not the reason.
  bool _serverWithoutAds = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final listings = await _repository.loadMyListings(
        requesterId: widget.currentOwnerId ?? resolveCurrentOwnerId(),
      );
      if (!mounted) return;
      setState(() {
        _listings = listings;
        _failed = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _failed = _listings == null;
        _serverWithoutAds = error is ListingBackendUnavailableException && error.answered;
      });
    }
  }

  Future<void> _open(MarketplaceListing listing) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ListingDetailPage(
          listing: listing,
          repository: _repository,
          currentOwnerId: widget.currentOwnerId,
        ),
      ),
    );
    if (changed != true || !mounted) return;
    _changed = true;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          foregroundColor: AppColors.text,
          title: Text(
            context.l10n.marketplaceMyListings,
            style: AppTextStyles.title,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(child: _body(context)),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final listings = _listings;
    if (listings == null && !_failed) return const Center(child: PetLoader());
    if (listings == null || listings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                !_failed
                    ? context.l10n.marketplaceMyListingsEmpty
                    : _serverWithoutAds
                        ? context.l10n.marketplaceBackendUnavailable
                        : context.l10n.marketplaceLoadError,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (_failed)
                TextButton(
                  onPressed: () {
                    setState(() => _failed = false);
                    unawaited(_load());
                  },
                  child: Text(context.l10n.commonRetry),
                ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: listings.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final listing = listings[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                key: ValueKey('my-listing-${listing.id}'),
                onTap: () => _open(listing),
                title: Text(
                  listing.title,
                  style: AppTextStyles.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    listingStatusLabel(listing),
                    listingPriceLabel(listing.priceCents, country: listing.country),
                  ].join(' · '),
                  style: AppTextStyles.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
              ),
              if (listing.removal case final removal?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: ListingRemovalNotice(removal: removal),
                ),
            ],
          );
        },
      ),
    );
  }
}
