import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/travel_card.dart';
import '../../domain/travel_resolver.dart';

/// The answer for one traveller: its heading and what was found.
class TravelResultSection {
  const TravelResultSection({required this.title, required this.answer});

  final String title;
  final TravelAnswer answer;
}

/// The blocks that carry steps with timings or serious consequences: they get
/// the "arrange it well in advance" notice (docs/compliance/17 A.11, level 3).
const _timedBlocks = {'microchip', 'vaccini_obbligatori', 'test_sierologici', 'farmaci_e_protezioni'};

class TravelResultView extends StatelessWidget {
  const TravelResultView({super.key, required this.sections, this.onReportError});

  final List<TravelResultSection> sections;

  /// Null when there is no support address to write to.
  final void Function(TravelCard card)? onReportError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          Text(section.title, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          _AnswerView(answer: section.answer, onReportError: onReportError),
          const SizedBox(height: AppSpacing.lg),
          _Fixed(l10n.aroundWorldFinal),
          const Divider(height: AppSpacing.xxl),
        ],
        // Not a trip, transport companies, local customs: said once at the end.
        _Fixed(l10n.aroundWorldNotATrip),
        const SizedBox(height: AppSpacing.sm),
        _Fixed(l10n.aroundWorldTransport),
        const SizedBox(height: AppSpacing.sm),
        _Fixed(l10n.aroundWorldLocalCustoms),
      ],
    );
  }
}

class _AnswerView extends StatelessWidget {
  const _AnswerView({required this.answer, required this.onReportError});

  final TravelAnswer answer;
  final void Function(TravelCard card)? onReportError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    switch (answer) {
      case NoTravelCardAnswer():
        return _Box(text: l10n.aroundWorldNoCard);
      case OtherSpeciesAnswer():
        return _Box(text: l10n.aroundWorldOtherSpecies);
      case final TravelCardAnswer answer:
        final card = answer.card;
        if (card.isHidden) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Box(text: l10n.aroundWorldHiddenCard),
              _OfficialLink(url: card.officialUrl),
            ],
          );
        }
        final blocks = answer.blocks;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (card.visibility == TravelCardVisibility.old)
              _Box(
                text: l10n.aroundWorldOldCard(_date(context, card.checkedOn)),
                warning: true,
              ),
            for (final block in blocks) _BlockView(block: block),
            const SizedBox(height: AppSpacing.sm),
            if (card.checkedOn != null)
              Text(l10n.aroundWorldCheckedOn(_date(context, card.checkedOn)), style: AppTextStyles.caption),
            for (final source in card.sources)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(source.citation, style: AppTextStyles.caption),
              ),
            _OfficialLink(url: card.officialUrl),
            if (onReportError != null)
              TextButton(
                onPressed: () => onReportError!(card),
                child: Text(l10n.aroundWorldReportError),
              ),
          ],
        );
    }
  }

  String _date(BuildContext context, DateTime? value) {
    if (value == null) return '';
    return DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(value);
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});

  final TravelBlock block;

  String _title(BuildContext context) {
    final l10n = context.l10n;
    return switch (block.kind) {
      'documenti' => l10n.aroundWorldBlockDocuments,
      'microchip' => l10n.aroundWorldBlockMicrochip,
      'vaccini_obbligatori' => l10n.aroundWorldBlockCompulsoryVaccines,
      'test_sierologici' => l10n.aroundWorldBlockAntibodyTest,
      'vaccini_consigliati' => l10n.aroundWorldBlockRecommendedVaccines,
      'malattie_presenti' => l10n.aroundWorldBlockDiseases,
      'farmaci_e_protezioni' => l10n.aroundWorldBlockMedicinesProtection,
      'comportamenti_e_norme' => l10n.aroundWorldBlockLocalRules,
      'rientro' => l10n.aroundWorldBlockReturn,
      'non_diffondere' => l10n.aroundWorldBlockSpreading,
      'quando_andare_dal_veterinario' => l10n.aroundWorldBlockVet,
      'limiti' => l10n.aroundWorldBlockLimits,
      _ => block.kind,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title(context), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          for (final sentence in block.sentences)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 6, right: AppSpacing.sm),
                    child: Icon(Icons.circle, size: 5, color: AppColors.mutedText),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (sentence.own)
                          Text(
                            l10n.aroundWorldOwnAdvice,
                            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
                          ),
                        Text(sentence.text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_timedBlocks.contains(block.kind))
            Text(
              l10n.aroundWorldTimes,
              style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.text, this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: warning ? AppColors.warningSoft : AppColors.infoSoft,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text)),
    );
  }
}

class _Fixed extends StatelessWidget {
  const _Fixed(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppTextStyles.caption);
}

class _OfficialLink extends StatelessWidget {
  const _OfficialLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => launchUrl(uri, webOnlyWindowName: '_blank'),
        icon: const Icon(Icons.open_in_new, size: 18),
        label: Text(context.l10n.aroundWorldOpenOfficial),
      ),
    );
  }
}
