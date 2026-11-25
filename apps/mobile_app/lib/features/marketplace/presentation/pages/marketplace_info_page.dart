import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/page_header.dart';
import '../../../../design_system/atoms/outline_icon_button.dart';

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
      appBar: PageHeader(title: l10n.marketplaceInfoTitle),
      body: SafeArea(
        child: ListView.separated(
          key: const ValueKey('marketplace-info'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.xl,
          ),
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
    return OutlineIconButton(
      key: const ValueKey('marketplace-info-button'),
      tooltip: context.l10n.marketplaceInfoTitle,
      icon: Icons.info_outline_rounded,
      onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const MarketplaceInfoPage()),
      ),
    );
  }
}
