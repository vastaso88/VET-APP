import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../data/account_export_remote_data_source.dart';
import '../widgets/account_page_scaffold.dart';

/// Saves the exported file with the system file picker (no permission needed).
/// True when the owner saved it, false when they cancelled; throws when saving
/// failed.
typedef AccountExportSaver = Future<bool> Function(AccountExportFile file, String dialogTitle);

Future<bool> saveWithSystemPicker(AccountExportFile file, String dialogTitle) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: file.fileName,
    bytes: file.bytes,
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  // On the web the browser downloads the file and reports no path.
  return kIsWeb || path != null;
}

/// «Scarica i miei dati» (GDPR art. 15 and 20): asks the backend for every
/// piece of data of the account and lets the owner save it. One request every
/// 10 minutes is allowed; a refusal is explained, never retried.
class ExportDataPage extends StatefulWidget {
  const ExportDataPage({super.key, this.dataSource, this.saver});

  /// Injectable for widget tests.
  final AccountExportRemoteDataSource? dataSource;
  final AccountExportSaver? saver;

  @override
  State<ExportDataPage> createState() => _ExportDataPageState();
}

enum _Outcome { none, saved, rateLimited, failed, saveFailed }

class _ExportDataPageState extends State<ExportDataPage> {
  late final AccountExportRemoteDataSource _dataSource =
      widget.dataSource ?? HttpAccountExportRemoteDataSource();
  late final AccountExportSaver _saver = widget.saver ?? saveWithSystemPicker;

  bool _working = false;
  _Outcome _outcome = _Outcome.none;

  Future<void> _download() async {
    if (_working) return;
    final dialogTitle = context.l10n.accountExportSaveDialogTitle;
    setState(() {
      _working = true;
      _outcome = _Outcome.none;
    });

    final result = await _dataSource.fetch();
    if (!mounted) return;
    final file = result.fold<AccountExportFile?>(onSuccess: (value) => value, onFailure: (_) => null);
    if (file == null) {
      final code = result.fold<String>(onSuccess: (_) => '', onFailure: (error) => error.code);
      setState(() {
        _working = false;
        _outcome = code == accountExportRateLimitedCode ? _Outcome.rateLimited : _Outcome.failed;
      });
      return;
    }

    var outcome = _Outcome.none;
    try {
      if (await _saver(file, dialogTitle)) outcome = _Outcome.saved;
    } catch (_) {
      outcome = _Outcome.saveFailed;
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _outcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (message, color) = switch (_outcome) {
      _Outcome.none => (null, AppColors.text),
      _Outcome.saved => (l10n.accountExportDone, AppColors.successStrong),
      _Outcome.rateLimited => (l10n.accountExportRateLimited, AppColors.warningStrong),
      _Outcome.failed => (l10n.accountExportFailed, AppColors.danger),
      _Outcome.saveFailed => (l10n.accountExportSaveFailed, AppColors.danger),
    };

    return AccountPageScaffold(
      title: l10n.accountExportTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.secondarySoft,
              borderRadius: BorderRadius.circular(AppRadii.large),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.download_rounded, color: AppColors.secondaryStrong),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.accountExportIntro, style: AppTextStyles.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.accountExportSensitive,
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const ValueKey('export-data-button'),
            onPressed: _working ? null : () => unawaited(_download()),
            child: _working
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PetLoader.small(),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(child: Text(l10n.accountExportWorking)),
                    ],
                  )
                : Text(l10n.accountExportButton),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              key: const ValueKey('export-data-outcome'),
              style: AppTextStyles.bodySmall.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}
