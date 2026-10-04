import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_text_styles.dart';
import '../../location/domain/coordinates.dart';
import '../../location/presentation/distance_label.dart';
import '../domain/radar_community.dart';
import '../domain/radar_data_source.dart';
import '../domain/radar_place.dart';
import 'radar_category.dart';
import 'radar_contributions.dart';

Future<void> callRadarPlace(RadarPlace place) =>
    launchUrl(Uri(scheme: 'tel', path: place.phone));

/// Opens the device's maps app with directions to [destination].
Future<void> openDirections(Coordinates destination) => launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${destination.latitude},${destination.longitude}',
      ),
      mode: LaunchMode.externalApplication,
    );

/// The card of one place. With [contributions] the user can also confirm
/// or deny a pending report, report a problem and rate a dog park;
/// without it the card is read-only.
Future<void> showRadarPlaceSheet(
  BuildContext context,
  RadarPlace place, {
  RadarContributions? contributions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _RadarPlaceSheet(place: place, contributions: contributions),
  );
}

/// One stated fact about a place, ready to show.
typedef RadarDetail = ({IconData icon, String label});

/// What OpenStreetMap says about a place (mostly dog parks), in Italian.
/// Only stated values with a known meaning are listed: nothing is implied
/// from a missing or unrecognized tag.
List<RadarDetail> radarPlaceDetails(Map<String, String> details) {
  const barriers = {
    'fence': 'Recintata',
    'wall': 'Recintata da un muro',
    'hedge': 'Delimitata da una siepe',
  };
  const surfaces = {
    'grass': 'Fondo in erba',
    'ground': 'Fondo in terra',
    'earth': 'Fondo in terra',
    'dirt': 'Fondo in terra',
    'sand': 'Fondo in sabbia',
    'gravel': 'Fondo in ghiaia',
    'fine_gravel': 'Fondo in ghiaia',
    'asphalt': 'Fondo asfaltato',
    'paved': 'Fondo pavimentato',
  };
  const accesses = {
    'yes': 'Accesso libero',
    'public': 'Accesso libero',
    'permissive': 'Accesso consentito',
    'customers': 'Solo per i clienti',
    'private': 'Area privata',
  };
  const wheelchairs = {
    'yes': 'Accessibile in sedia a rotelle',
    'limited': 'Accessibilità parziale in sedia a rotelle',
    'no': 'Non accessibile in sedia a rotelle',
  };

  final result = <RadarDetail>[];
  void add(IconData icon, String? label) {
    if (label != null) {
      result.add((icon: icon, label: label));
    }
  }

  add(Icons.fence, barriers[details['barrier']]);
  add(
    Icons.water_drop_outlined,
    const {'yes': 'Acqua potabile', 'no': 'Senza acqua potabile'}[details['drinking_water']],
  );
  add(Icons.lightbulb_outline, const {'yes': 'Illuminata', 'no': 'Non illuminata'}[details['lit']]);
  add(Icons.grass, surfaces[details['surface']]);
  add(Icons.lock_open_outlined, accesses[details['access']]);
  add(Icons.pets, const {'unleashed': 'Cani liberi senza guinzaglio'}[details['dog']]);
  add(Icons.accessible, wheelchairs[details['wheelchair']]);
  return result;
}

/// "Segnalato dagli utenti · in attesa di conferma (2/5)".
String pendingReportLabel(RadarReportInfo report) =>
    'Segnalato dagli utenti · in attesa di conferma (${report.progressLabel})';

class _RadarPlaceSheet extends StatefulWidget {
  const _RadarPlaceSheet({required this.place, this.contributions});

  final RadarPlace place;
  final RadarContributions? contributions;

  @override
  State<_RadarPlaceSheet> createState() => _RadarPlaceSheetState();
}

class _RadarPlaceSheetState extends State<_RadarPlaceSheet> {
  bool _busy = false;

  RadarPlace get _place => widget.place;

  /// Runs one contribution and closes the card when it went through: the
  /// page reloads, so what the card shows would be out of date.
  Future<void> _contribute<T>(
    Future<bool> Function(RadarContributions contributions) action,
  ) async {
    final contributions = widget.contributions;
    if (contributions == null || _busy) {
      return;
    }
    setState(() => _busy = true);
    final done = await action(contributions);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (done) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _vote(RadarReportInfo report, {required bool confirm}) {
    return _contribute(
      (contributions) => contributions.run<void>(
        context,
        () => contributions.repository.vote(report.reportId, confirm: confirm),
        successMessage: (_) => confirm ? 'Grazie, conferma registrata.' : 'Grazie, registrato.',
      ),
    );
  }

  Future<void> _rate(int stars) {
    return _contribute(
      (contributions) => contributions.run<void>(
        context,
        () => contributions.repository.rate(_place, stars),
        successMessage: (_) => 'Voto registrato: $stars su 5.',
      ),
    );
  }

  Future<void> _reportProblem() async {
    final problem = await showDialog<RadarProblem>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Cosa non va in questo luogo?'),
        children: RadarProblem.values
            .map(
              (problem) => SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(problem),
                child: Text(problem.label),
              ),
            )
            .toList(),
      ),
    );
    if (problem == null || !mounted) {
      return;
    }
    await _contribute(
      (contributions) => contributions.run(
        context,
        () => contributions.repository.reportProblem(_place, problem),
        successMessage: (receipt) => receipt.countedAsConfirmation
            ? 'Era già stato segnalato: la tua segnalazione vale come conferma.'
            : 'Segnalazione inviata. Sarà applicata quando altri utenti la confermano.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = _place;
    final category = radarCategoryForPlace(place.type);
    final address = place.addressLabel ?? place.city;
    final isClinic = place.type == RadarPlaceType.veterinary;
    final details = radarPlaceDetails(place.details);
    final source = radarSourceInfo(place.sourceName);
    final confirmedBy = place.confirmedBy
        .map((name) => radarSourceInfo(name)?.name)
        .whereType<String>()
        .join(', ');
    final community = place.community;
    final pendingClosure = place.pendingClosure;
    final rating = place.rating;
    final canContribute = widget.contributions != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RadarCategoryBadge(category: category, pending: place.isPendingReport),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: AppTextStyles.title),
                      Text(
                        '${radarPlaceTypeLabel(place.type)} · ${formatDistance(place.distanceMeters)}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (community != null && community.isPending) ...[
              const SizedBox(height: AppSpacing.md),
              _ReportBanner(
                label: pendingReportLabel(community),
                question: 'Questo luogo esiste davvero qui?',
                report: community,
                busy: _busy,
                onVote: canContribute ? _vote : null,
              ),
            ],
            if (pendingClosure != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ReportBanner(
                label: 'Segnalato come chiuso (${pendingClosure.progressLabel})',
                question: 'Ha chiuso davvero?',
                report: pendingClosure,
                busy: _busy,
                onVote: canContribute ? _vote : null,
              ),
            ],
            if (address != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(address, style: AppTextStyles.body),
            ],
            if (place.openingHours != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Orari indicati: ${formatOpeningHours(place.openingHours!)}',
                style: AppTextStyles.bodySmall,
              ),
            ],
            if (place.summary != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(place.summary!, style: AppTextStyles.bodySmall),
            ],
            if (details.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: details.map((detail) => _DetailChip(detail: detail)).toList(),
              ),
            ],
            if (rating != null) ...[
              const SizedBox(height: AppSpacing.md),
              _RatingRow(rating: rating, onRate: canContribute && !_busy ? _rate : null),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (place.phone != null)
                  FilledButton.icon(
                    onPressed: () => callRadarPlace(place),
                    icon: const Icon(Icons.call),
                    label: const Text('Chiama'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => openDirections(place.location),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Indicazioni'),
                ),
                if (place.websiteUrl != null)
                  OutlinedButton.icon(
                    onPressed: () =>
                        launchUrl(Uri.parse(place.websiteUrl!), webOnlyWindowName: '_blank'),
                    icon: const Icon(Icons.public),
                    label: const Text('Sito web'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              community != null
                  ? 'Luogo segnalato dagli utenti: non è una garanzia, verifica prima di andarci.'
                  : isClinic
                      ? 'In caso di urgenza telefona prima di partire: orari e recapiti arrivano '
                          'da archivi aperti e non sono verificati da VetApp.'
                      : 'Orari e recapiti arrivano da archivi aperti e non sono verificati '
                          'da VetApp.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                'Fonte: ${source?.attribution ?? place.sourceName}',
                if (confirmedBy.isNotEmpty) 'Presente anche in: $confirmedBy',
              ].join('. '),
              style: AppTextStyles.caption,
            ),
            // A user report is corrected with "Non è così", not with a
            // second report about the report.
            if (canContribute && community == null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _busy ? null : _reportProblem,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Segnala un problema'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportBanner extends StatelessWidget {
  const _ReportBanner({
    required this.label,
    required this.question,
    required this.report,
    required this.busy,
    required this.onVote,
  });

  final String label;
  final String question;
  final RadarReportInfo report;
  final bool busy;
  final Future<void> Function(RadarReportInfo report, {required bool confirm})? onVote;

  @override
  Widget build(BuildContext context) {
    final onVote = this.onVote;
    final viewerNote = report.viewerIsReporter
        ? 'L’hai segnalato tu: servono le conferme di altri utenti.'
        : switch (report.viewerVote) {
            1 => 'Hai confermato. Puoi cambiare idea.',
            -1 => 'Hai indicato che non è così. Puoi cambiare idea.',
            _ => question,
          };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, size: 18, color: AppColors.text),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(viewerNote, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text)),
          if (onVote != null && !report.viewerIsReporter) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                FilledButton(
                  onPressed: busy ? null : () => onVote(report, confirm: true),
                  child: const Text('Confermo'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => onVote(report, confirm: false),
                  child: const Text('Non è così'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.onRate});

  final RadarRating rating;
  final ValueChanged<int>? onRate;

  @override
  Widget build(BuildContext context) {
    final average = rating.average;
    final viewerStars = rating.viewerStars ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          average != null
              ? 'Secondo gli utenti VetApp: ${average.toStringAsFixed(1).replaceAll('.', ',')} '
                  'su 5 (${rating.count} voti)'
              : rating.count == 0
                  ? 'Nessun voto ancora. Com’è quest’area cani?'
                  : 'Voti finora: ${rating.count}. La media compare da 3 voti.',
          style: AppTextStyles.bodySmall,
        ),
        Row(
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                tooltip: 'Dai $star ${star == 1 ? 'stella' : 'stelle'}',
                visualDensity: VisualDensity.compact,
                onPressed: onRate == null ? null : () => onRate!(star),
                icon: Icon(
                  star <= viewerStars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppColors.warning,
                ),
              ),
          ],
        ),
        if (viewerStars > 0)
          Text('Il tuo voto: $viewerStars su 5. Tocca per cambiarlo.', style: AppTextStyles.caption),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.detail});

  final RadarDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(detail.icon, size: 16, color: AppColors.secondaryText),
          const SizedBox(width: AppSpacing.xs),
          Text(detail.label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
