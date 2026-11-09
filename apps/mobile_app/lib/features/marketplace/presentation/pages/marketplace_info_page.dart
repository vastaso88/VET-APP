import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';

/// "Come funziona il Mercatino": rules, deals between private people, safety
/// advice and how to report. Texts from the legal session
/// (docs/compliance/11_esclusioni_responsabilita.md §4 B), reachable from the
/// Mercatino's bar and from every conversation, with or without a plan.
class MarketplaceInfoPage extends StatelessWidget {
  const MarketplaceInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final points = [
      l10n.marketplaceInfoWhat,
      l10n.marketplaceInfoPrivateOnly,
      l10n.marketplaceInfoDeal,
      l10n.marketplaceInfoChecks,
      l10n.marketplaceInfoPrivateSale,
      l10n.marketplaceInfoContacts,
      l10n.marketplaceInfoReports,
      l10n.marketplaceInfoForbidden,
      l10n.marketplaceInfoPrivacy,
      l10n.marketplaceInfoTerms,
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(
          l10n.marketplaceInfoTitle,
          style: AppTextStyles.title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          key: const ValueKey('marketplace-info'),
          padding: const EdgeInsets.all(AppSpacing.xl),
          itemCount: points.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7, right: AppSpacing.sm),
                child: Icon(Icons.circle, size: 6, color: AppColors.primary),
              ),
              Expanded(child: Text(points[index], style: AppTextStyles.body)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens [MarketplaceInfoPage]; the same button everywhere it appears.
class MarketplaceInfoButton extends StatelessWidget {
  const MarketplaceInfoButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('marketplace-info-button'),
      tooltip: context.l10n.marketplaceInfoTitle,
      icon: const Icon(Icons.info_outline_rounded),
      onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const MarketplaceInfoPage()),
      ),
    );
  }
}
