import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/auth/current_owner.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../data/listing_report_service.dart';
import '../../domain/marketplace_listing.dart';
import '../marketplace_labels.dart';

class ListingDetailPage extends StatefulWidget {
  const ListingDetailPage({super.key, required this.listing, this.distanceMeters});

  final MarketplaceListing listing;
  final double? distanceMeters;

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  bool _reporting = false;

  static const _reasons = {
    'spam': 'Spam',
    'scam': 'Truffa',
    'prohibited_item': 'Articolo non consentito',
    'inappropriate': 'Contenuto inappropriato',
    'other': 'Altro',
  };

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

    setState(() => _reporting = true);
    final updated = await ListingReportService().report(
      listing: widget.listing,
      reporterOwnerId: resolveCurrentOwnerId(),
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
      setState(() => _reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
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
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                DashboardBadge(label: listingCategoryLabel(listing.category), tone: DashboardTone.info),
                DashboardBadge(label: listingConditionLabel(listing.condition), tone: DashboardTone.neutral),
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
              Text(listing.cityLabel!, style: AppTextStyles.bodySmall),
            ],
            if (listing.description != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(listing.description!, style: AppTextStyles.body),
            ],
            const SizedBox(height: AppSpacing.xxl),
            DashboardActionButton(
              label: _reporting ? 'Invio segnalazione...' : 'Segnala annuncio',
              icon: Icons.flag_outlined,
              tone: DashboardTone.danger,
              filled: false,
              onPressed: _reporting ? null : _reportListing,
            ),
          ],
        ),
      ),
    );
  }
}
