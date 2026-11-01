import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_text_styles.dart';
import '../../../l10n/l10n.dart';
import '../../location/domain/coordinates.dart';
import '../../location/presentation/distance_label.dart';
import '../domain/radar_community.dart';
import '../domain/radar_data_source.dart';
import '../domain/radar_place.dart';
import 'radar_category.dart';
import 'radar_contributions.dart';

Future<void> callRadarPlace(RadarPlace place) => launchUrl(Uri(scheme: 'tel', path: place.phone));

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
  String? supportContactEmail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _RadarPlaceSheet(
      place: place,
      contributions: contributions,
      supportContactEmail: supportContactEmail,
    ),
  );
}

/// One stated fact about a place, ready to show.
typedef RadarDetail = ({IconData icon, String label});

/// What OpenStreetMap says about a place (mostly dog parks), in the app
/// language. Only stated values with a known meaning are listed: nothing is
/// implied from a missing or unrecognized tag.
List<RadarDetail> radarPlaceDetails(Map<String, String> details) {
  final l10n = appL10n;
  final barriers = {
    'fence': l10n.placesDetailBarrierFence,
    'wall': l10n.placesDetailBarrierWall,
    'hedge': l10n.placesDetailBarrierHedge,
  };
  final surfaces = {
    'grass': l10n.placesDetailSurfaceGrass,
    'ground': l10n.placesDetailSurfaceGround,
    'earth': l10n.placesDetailSurfaceGround,
    'dirt': l10n.placesDetailSurfaceGround,
    'sand': l10n.placesDetailSurfaceSand,
    'gravel': l10n.placesDetailSurfaceGravel,
    'fine_gravel': l10n.placesDetailSurfaceGravel,
    'asphalt': l10n.placesDetailSurfaceAsphalt,
    'paved': l10n.placesDetailSurfacePaved,
  };
  final accesses = {
    'yes': l10n.placesDetailAccessFree,
    'public': l10n.placesDetailAccessFree,
    'permissive': l10n.placesDetailAccessPermissive,
    'customers': l10n.placesDetailAccessCustomers,
    'private': l10n.placesDetailAccessPrivate,
  };
  final wheelchairs = {
    'yes': l10n.placesDetailWheelchairYes,
    'limited': l10n.placesDetailWheelchairLimited,
    'no': l10n.placesDetailWheelchairNo,
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
    {
      'yes': l10n.placesDetailDrinkingWaterYes,
      'no': l10n.placesDetailDrinkingWaterNo,
    }[details['drinking_water']],
  );
  add(
    Icons.lightbulb_outline,
    {'yes': l10n.placesDetailLitYes, 'no': l10n.placesDetailLitNo}[details['lit']],
  );
  add(Icons.grass, surfaces[details['surface']]);
  add(Icons.lock_open_outlined, accesses[details['access']]);
  add(Icons.pets, {'unleashed': l10n.placesDetailDogUnleashed}[details['dog']]);
  add(
    Icons.favorite_outline,
    {
      'yes': l10n.placesDetailAdoptionYes,
      'no': l10n.placesDetailAdoptionNo,
    }[details['animal_shelter:adoption']],
  );
  add(Icons.accessible, wheelchairs[details['wheelchair']]);
  return result;
}

/// How a not-yet-confirmed user report is announced, in lists and on the
/// card. A dog park gets an explicit caution: unlike a shop, a patch of
/// grass someone reported may be private ground.
String pendingPlaceLabel(RadarPlace place) {
  final progress = place.community?.progressLabel ?? '';
  final l10n = appL10n;
  return place.type == RadarPlaceType.dogPark
      ? l10n.placesPendingDogPark(progress)
      : l10n.placesPendingPlace(progress);
}

/// Opens an email to the support contact about [place], with subject and
/// identifier already filled in: the fastest way to get a reported area
/// that is not public taken down.
Future<void> writeAboutPlace(RadarPlace place, String supportContactEmail) {
  final l10n = appL10n;
  return launchUrl(
    Uri(
      scheme: 'mailto',
      path: supportContactEmail,
      query: _mailQuery({
        'subject': l10n.placesMailRemoveSubject(place.sourceExternalId),
        'body': l10n.placesMailRemoveBody(
          place.name,
          '${place.location.latitude}, ${place.location.longitude}',
          place.sourceExternalId,
        ),
      }),
    ),
  );
}

String _mailQuery(Map<String, String> fields) =>
    fields.entries.map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}').join('&');

class _RadarPlaceSheet extends StatefulWidget {
  const _RadarPlaceSheet({required this.place, this.contributions, this.supportContactEmail});

  final RadarPlace place;
  final RadarContributions? contributions;
  final String? supportContactEmail;

  @override
  State<_RadarPlaceSheet> createState() => _RadarPlaceSheetState();
}

class _RadarPlaceSheetState extends State<_RadarPlaceSheet> {
  bool _busy = false;

  // What the user just tapped, shown at once while the server answers
  // (it can take seconds): cleared when the answer arrives, so a failure
  // puts the card back as it was.
  int? _savingStars;
  int? _savingVote;
  bool _withdrawing = false;

  RadarPlace get _place => widget.place;

  /// Runs one contribution and closes the card when it went through: the
  /// page reloads, so what the card shows would be out of date.
  Future<void> _contribute<T>(
    Future<bool> Function(RadarContributions contributions) action, {
    bool closeOnSuccess = true,
  }) async {
    final contributions = widget.contributions;
    if (contributions == null || _busy) {
      return;
    }
    setState(() => _busy = true);
    final done = await action(contributions);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _savingStars = null;
      _savingVote = null;
      _withdrawing = false;
    });
    if (done && closeOnSuccess) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _withdraw(RadarReportInfo report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.placesWithdrawTitle),
        content: Text(dialogContext.l10n.placesWithdrawBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.placesWithdrawConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) {
      return;
    }
    setState(() => _withdrawing = true);
    await _contribute(
      (contributions) => contributions.run<void>(
        context,
        () => contributions.repository.withdraw(report.reportId),
        successMessage: (_) => context.l10n.placesWithdrawnSnack,
      ),
    );
  }

  Future<void> _vote(RadarReportInfo report, {required bool confirm}) {
    if (_busy) {
      return Future.value();
    }
    setState(() => _savingVote = confirm ? 1 : -1);
    return _contribute(
      (contributions) => contributions.run<void>(
        context,
        () => contributions.repository.vote(report.reportId, confirm: confirm),
        successMessage: (_) =>
            confirm ? context.l10n.placesVoteConfirmedSnack : context.l10n.placesVoteDeniedSnack,
      ),
    );
  }

  /// The card stays open after a vote, showing it: closing it made the
  /// vote look as if it had not been taken.
  Future<void> _rate(int stars) {
    if (_busy || widget.contributions == null) {
      return Future.value();
    }
    setState(() => _savingStars = stars);
    return _contribute(
      (contributions) async {
        final done = await contributions.run<void>(
          context,
          () => contributions.repository.rate(_place, stars),
          successMessage: (_) => context.l10n.placesRatedSnack(stars),
          reload: false,
        );
        if (done) {
          contributions.rememberStars(_place, stars);
        }
        return done;
      },
      closeOnSuccess: false,
    );
  }

  Future<void> _reportProblem() async {
    final contributions = widget.contributions;
    if (contributions == null) {
      return;
    }
    // The backend decides which problems can be reported right now.
    final problems = (await contributions.repository.loadOptions()).problems;
    if (!mounted) {
      return;
    }
    if (problems.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.placesReportsInactiveSnack)),
      );
      return;
    }
    final problem = await showDialog<RadarProblem>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.placesReportProblemTitle),
        children: problems
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
            ? context.l10n.placesReportAlreadyKnown
            : context.l10n.placesReportSent,
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
    final confirmedBy =
        place.confirmedBy.map((name) => radarSourceInfo(name)?.name).whereType<String>().join(', ');
    final community = place.community;
    final pendingClosure = place.pendingClosure;
    final rating =
        place.rating?.withViewerStars(_savingStars ?? widget.contributions?.starsGivenTo(place));
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
                label: pendingPlaceLabel(place),
                question: context.l10n.placesSheetPendingQuestion,
                report: community,
                busy: _busy,
                savingVote: _savingVote,
                withdrawing: _withdrawing,
                onVote: canContribute ? _vote : null,
                onWithdraw: canContribute ? _withdraw : null,
              ),
            ],
            if (community != null &&
                community.isPending &&
                place.type == RadarPlaceType.dogPark &&
                widget.supportContactEmail != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => writeAboutPlace(place, widget.supportContactEmail!),
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: Text(context.l10n.placesSheetNotPublicWrite),
                ),
              ),
            if (pendingClosure != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ReportBanner(
                label: context.l10n.placesSheetClosedReported(pendingClosure.progressLabel),
                question: context.l10n.placesSheetClosedQuestion,
                report: pendingClosure,
                busy: _busy,
                savingVote: _savingVote,
                withdrawing: _withdrawing,
                onVote: canContribute ? _vote : null,
                onWithdraw: canContribute ? _withdraw : null,
              ),
            ],
            if (address != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(address, style: AppTextStyles.body),
            ],
            if (place.openingHours != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.l10n.placesSheetOpeningHours(formatOpeningHours(place.openingHours!)),
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
              _RatingRow(
                rating: rating,
                saving: _savingStars != null,
                onRate: canContribute && !_busy ? _rate : null,
              ),
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
                    label: Text(context.l10n.placesActionCall),
                  ),
                OutlinedButton.icon(
                  onPressed: () => openDirections(place.location),
                  icon: const Icon(Icons.directions_outlined),
                  label: Text(context.l10n.placesActionDirections),
                ),
                if (place.websiteUrl != null)
                  OutlinedButton.icon(
                    onPressed: () =>
                        launchUrl(Uri.parse(place.websiteUrl!), webOnlyWindowName: '_blank'),
                    icon: const Icon(Icons.public),
                    label: Text(context.l10n.placesActionWebsite),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              community != null
                  ? context.l10n.placesDisclaimerCommunity
                  : isClinic
                      ? context.l10n.placesDisclaimerClinic
                      : context.l10n.placesDisclaimerGeneric,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                context.l10n.placesSourceLine(source?.attribution ?? place.sourceName),
                if (confirmedBy.isNotEmpty) context.l10n.placesAlsoIn(confirmedBy),
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
                  label: Text(context.l10n.placesReportProblemAction),
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
    required this.onWithdraw,
    this.savingVote,
    this.withdrawing = false,
  });

  final String label;
  final String question;
  final RadarReportInfo report;
  final bool busy;
  final Future<void> Function(RadarReportInfo report, {required bool confirm})? onVote;

  /// Offered only to whoever made the report.
  final Future<void> Function(RadarReportInfo report)? onWithdraw;

  /// The vote (+1 / -1) being saved right now, shown as if already given.
  final int? savingVote;
  final bool withdrawing;

  @override
  Widget build(BuildContext context) {
    final onVote = this.onVote;
    final onWithdraw = this.onWithdraw;
    final expiryLabel = report.expiryLabel;
    final l10n = context.l10n;
    final viewerNote = withdrawing
        ? l10n.placesBannerWithdrawing
        : report.viewerIsReporter
            ? l10n.placesBannerYouReported
            : switch (savingVote ?? report.viewerVote) {
                1 => savingVote != null
                    ? l10n.placesBannerConfirmedSaving
                    : l10n.placesBannerConfirmedChange,
                -1 => savingVote != null
                    ? l10n.placesBannerDeniedSaving
                    : l10n.placesBannerDeniedChange,
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
          if (expiryLabel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(expiryLabel, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text)),
          ],
          if (onWithdraw != null && report.viewerIsReporter) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: busy ? null : () => onWithdraw(report),
              icon: const Icon(Icons.undo, size: 18),
              label: Text(l10n.placesBannerWithdrawButton),
            ),
          ],
          if (onVote != null && !report.viewerIsReporter) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                FilledButton(
                  onPressed: busy ? null : () => onVote(report, confirm: true),
                  child: Text(l10n.placesBannerConfirm),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => onVote(report, confirm: false),
                  child: Text(l10n.placesBannerDeny),
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
  const _RatingRow({required this.rating, required this.onRate, this.saving = false});

  final RadarRating rating;

  /// The stars shown are being saved: not confirmed by the server yet.
  final bool saving;
  final ValueChanged<int>? onRate;

  @override
  Widget build(BuildContext context) {
    final viewerStars = rating.viewerStars ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rating.communityLabel,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        Row(
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                tooltip: context.l10n.placesRateStarTooltip(star),
                visualDensity: VisualDensity.compact,
                onPressed: onRate == null ? null : () => onRate!(star),
                icon: Icon(
                  star <= viewerStars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppColors.warning,
                ),
              ),
          ],
        ),
        Text(
          saving
              ? context.l10n.placesRatingSaving(viewerStars)
              : viewerStars > 0
                  ? context.l10n.placesRatingYours(viewerStars)
                  : context.l10n.placesRatingPrompt,
          style: AppTextStyles.bodySmall,
        ),
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
        color: AppColors.secondarySoft,
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
