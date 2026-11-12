import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../data/radar_places_repository.dart';
import '../../domain/radar_data_source.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';

/// "Fonti dati": where the radar's places come from and under which
/// license. The list of sources is fixed (attribution must be shown even
/// offline); the release and import date come from the backend when it
/// answers.
class DataSourcesPage extends StatefulWidget {
  const DataSourcesPage({super.key, this.repository});

  /// Injectable for tests; defaults to the real HTTP repository.
  final RadarPlacesRepository? repository;

  @override
  State<DataSourcesPage> createState() => _DataSourcesPageState();
}

class _DataSourcesPageState extends State<DataSourcesPage> {
  late final Future<RadarSourcesInfo> _sourcesFuture =
      (widget.repository ?? RadarPlacesRepository()).loadSources();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(context.l10n.placesSourcesTitle, style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: FutureBuilder<RadarSourcesInfo>(
          future: _sourcesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: PetLoader());
            }
            final info = snapshot.data ?? const RadarSourcesInfo();
            final imported = {for (final source in info.sources) source.source: source};
            final contact = info.supportContactEmail;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text(
                  context.l10n.placesSourcesIntro,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final info in radarSourceCatalog) ...[
                  _SourceCard(info: info, imported: imported[info.source]),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  contact == null
                      ? context.l10n.placesSourcesNoContact
                      : context.l10n.placesSourcesContact(contact),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.info, this.imported});

  final RadarSourceInfo info;
  final RadarDataSource? imported;

  @override
  Widget build(BuildContext context) {
    final imported = this.imported;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          Text(info.description, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Text(info.attribution, style: AppTextStyles.caption),
          Text(context.l10n.placesSourceLicense(info.license), style: AppTextStyles.caption),
          if (imported != null)
            Text(
              context.l10n.placesSourceVersion(
                imported.release,
                formatAppDate(imported.importedAt.toLocal(), 'd MMMM yyyy'),
              ),
              style: AppTextStyles.caption,
            ),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => launchUrl(Uri.parse(info.url), webOnlyWindowName: '_blank'),
            child: Text(context.l10n.placesSourceLicenseLink),
          ),
        ],
      ),
    );
  }
}
