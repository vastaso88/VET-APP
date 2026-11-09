import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../settings/domain/unit_conversion.dart';
import '../../data/account_export_remote_data_source.dart';
import '../../data/account_export_zip_builder.dart';
import '../../data/export_file_fetcher.dart';
import '../../data/export_workspace.dart';
import '../account_export_labels.dart';
import '../widgets/account_page_scaffold.dart';

/// Saves the exported file with the system file picker (no permission needed).
/// True when the owner saved it, false when they cancelled; throws when saving
/// failed.
typedef AccountExportSaver = Future<bool> Function(AccountExportFile file, String dialogTitle);

Future<bool> saveWithSystemPicker(AccountExportFile file, String dialogTitle) async {
  final extension = file.fileName.contains('.') ? file.fileName.split('.').last : 'json';
  final path = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: file.fileName,
    bytes: file.bytes,
    type: FileType.custom,
    allowedExtensions: [extension],
  );
  // On the web the browser downloads the file and reports no path.
  return kIsWeb || path != null;
}

/// More than this and the zip is not offered: it is built in the phone's
/// memory (and its temporary folder), so a very large export would fail.
const exportZipMaxBytes = 400 * 1024 * 1024;

/// «Scarica i miei dati» (GDPR art. 15 and 20): asks the backend for every
/// piece of data of the account, shows what it holds and how big it is, then
/// saves a readable zip (`dati.json`, `leggimi.html`, `foto/`, `allegati/`) or
/// only the JSON. One request every 10 minutes is allowed; a refusal is
/// explained, never retried.
class ExportDataPage extends StatefulWidget {
  const ExportDataPage({
    super.key,
    this.dataSource,
    this.saver,
    this.fetcher,
    this.workspaceFactory,
    this.clock,
  });

  /// Injectable for widget tests.
  final AccountExportRemoteDataSource? dataSource;
  final AccountExportSaver? saver;
  final ExportFileFetcher? fetcher;
  final Future<ExportWorkspace> Function()? workspaceFactory;
  final DateTime Function()? clock;

  @override
  State<ExportDataPage> createState() => _ExportDataPageState();
}

enum _Step { idle, fetching, estimating, ready, building, saving }

enum _Outcome { none, saved, savedWithMissing, cancelled, rateLimited, failed, saveFailed }

class _ExportDataPageState extends State<ExportDataPage> {
  late final AccountExportRemoteDataSource _dataSource =
      widget.dataSource ?? HttpAccountExportRemoteDataSource();
  late final AccountExportSaver _saver = widget.saver ?? saveWithSystemPicker;
  late final ExportFileFetcher _fetcher = widget.fetcher ?? HttpExportFileFetcher();
  late final Future<ExportWorkspace> Function() _workspaceFactory =
      widget.workspaceFactory ?? createExportWorkspace;

  _Step _step = _Step.idle;
  _Outcome _outcome = _Outcome.none;
  int _missingCount = 0;

  // What the server sent, kept in memory until it is saved or the page closes.
  AccountExportFile? _jsonFile;
  Map<String, dynamic>? _export;
  ExportEstimate? _estimate;
  ExportCancelToken? _cancel;
  int _done = 0;
  int _total = 0;

  @override
  void dispose() {
    // Leaving the page stops any work in progress; its temporary files are
    // removed by the builder's own cleanup.
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (_step != _Step.idle) return;
    setState(() {
      _step = _Step.fetching;
      _outcome = _Outcome.none;
    });

    final result = await _dataSource.fetch();
    if (!mounted) return;
    final file = result.fold<AccountExportFile?>(onSuccess: (value) => value, onFailure: (_) => null);
    if (file == null) {
      final code = result.fold<String>(onSuccess: (_) => '', onFailure: (error) => error.code);
      setState(() {
        _step = _Step.idle;
        _outcome = code == accountExportRateLimitedCode ? _Outcome.rateLimited : _Outcome.failed;
      });
      return;
    }

    Map<String, dynamic> export;
    try {
      export = (jsonDecode(utf8.decode(file.bytes)) as Map).cast<String, dynamic>();
    } catch (_) {
      export = const <String, dynamic>{};
    }

    final cancel = ExportCancelToken();
    setState(() {
      _jsonFile = file;
      _export = export;
      _cancel = cancel;
      _step = _Step.estimating;
    });

    ExportEstimate estimate;
    try {
      estimate = await estimateExport(planExport(export), _fetcher, cancel: cancel);
    } on ExportCancelled {
      if (mounted) _reset(_Outcome.cancelled);
      return;
    }
    if (!mounted) return;
    if (cancel.isCancelled) {
      _reset(_Outcome.cancelled);
      return;
    }
    setState(() {
      _estimate = estimate;
      _step = _Step.ready;
    });
  }

  /// Back to the first screen; the data held in memory is dropped.
  void _reset(_Outcome outcome, {int missing = 0}) {
    setState(() {
      _step = _Step.idle;
      _outcome = outcome;
      _missingCount = missing;
      _jsonFile = null;
      _export = null;
      _estimate = null;
      _cancel = null;
      _done = 0;
      _total = 0;
    });
  }

  Future<void> _save(AccountExportFile file, {int missing = 0}) async {
    final dialogTitle = context.l10n.accountExportSaveDialogTitle;
    setState(() => _step = _Step.saving);
    var outcome = _Outcome.cancelled;
    var saved = false;
    try {
      saved = await _saver(file, dialogTitle);
      outcome = saved ? (missing > 0 ? _Outcome.savedWithMissing : _Outcome.saved) : _Outcome.none;
    } catch (_) {
      outcome = _Outcome.saveFailed;
    }
    if (!mounted) return;
    if (saved || outcome == _Outcome.saveFailed) {
      _reset(outcome, missing: missing);
    } else {
      // The picker was closed: the owner may choose again without a new request.
      setState(() {
        _step = _Step.ready;
        _outcome = _Outcome.none;
      });
    }
  }

  Future<void> _saveJsonOnly() async {
    final file = _jsonFile;
    if (file == null) return;
    await _save(file);
  }

  Future<void> _buildZip() async {
    final file = _jsonFile;
    final export = _export;
    if (file == null || export == null) return;
    final l10n = context.l10n;
    final builder = AccountExportZipBuilder(
      fetcher: _fetcher,
      workspaceFactory: _workspaceFactory,
      labels: exportReadmeLabelsFrom(l10n),
      formatDate: (date, {required withTime}) => formatAppDate(date, withTime ? 'd MMM y, HH:mm' : 'd MMM y'),
    );
    final cancel = ExportCancelToken();
    setState(() {
      _cancel = cancel;
      _step = _Step.building;
      _done = 0;
      _total = _estimate?.fileCount ?? 0;
      _outcome = _Outcome.none;
    });

    AccountExportZip zip;
    try {
      zip = await builder.build(
        jsonBytes: file.bytes,
        export: export,
        cancel: cancel,
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _done = done;
              _total = total;
            });
          }
        },
      );
    } on ExportCancelled {
      // The temporary files are already removed.
      if (mounted) {
        setState(() {
          _cancel = null;
          _step = _Step.ready;
          _outcome = _Outcome.cancelled;
        });
      }
      return;
    } catch (_) {
      if (mounted) _reset(_Outcome.failed);
      return;
    }
    if (!mounted) return;

    final day = (widget.clock ?? DateTime.now)();
    final name = 'quokka-dati-${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}.zip';
    await _save(AccountExportFile(fileName: name, bytes: Uint8List.fromList(zip.bytes)), missing: zip.missing.length);
  }

  String _size(int bytes) {
    if (bytes < 1024 * 1024) return '${formatDecimal(bytes / 1024, digits: 0)} KB';
    return '${formatDecimal(bytes / (1024 * 1024), digits: 1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (message, color) = switch (_outcome) {
      _Outcome.none => (null, AppColors.text),
      _Outcome.saved => (l10n.accountExportDone, AppColors.successStrong),
      _Outcome.savedWithMissing => (l10n.accountExportZipDoneMissing(_missingCount), AppColors.warningStrong),
      _Outcome.cancelled => (l10n.accountExportCancelled, AppColors.secondaryText),
      _Outcome.rateLimited => (l10n.accountExportRateLimited, AppColors.warningStrong),
      _Outcome.failed => (l10n.accountExportFailed, AppColors.danger),
      _Outcome.saveFailed => (l10n.accountExportSaveFailed, AppColors.danger),
    };

    final estimate = _estimate;
    final tooBig = (estimate?.knownBytes ?? 0) > exportZipMaxBytes;

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
          if (_step == _Step.idle || _step == _Step.fetching)
            FilledButton(
              key: const ValueKey('export-data-button'),
              onPressed: _step == _Step.fetching ? null : () => unawaited(_fetch()),
              child: _step == _Step.fetching
                  ? _busyLabel(l10n.accountExportWorking)
                  : Text(l10n.accountExportButton),
            ),
          if (_step == _Step.estimating) ...[
            _busyRow(l10n.accountExportEstimating),
            const SizedBox(height: AppSpacing.sm),
            _cancelButton(l10n.accountExportCancel),
          ],
          if (_step == _Step.ready && estimate != null) ...[
            Text(
              key: const ValueKey('export-estimate'),
              estimate.fileCount == 0
                  ? l10n.accountExportReadyOnlyData
                  : estimate.knownBytes == 0
                      ? l10n.accountExportReadyUnknownSize(estimate.fileCount)
                      : l10n.accountExportReadyFiles(estimate.fileCount, _size(estimate.knownBytes)),
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
            ),
            if (tooBig) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.accountExportTooBig,
                key: const ValueKey('export-too-big'),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningStrong),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const ValueKey('export-zip-button'),
              onPressed: tooBig ? null : () => unawaited(_buildZip()),
              child: Text(l10n.accountExportZipButton),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const ValueKey('export-json-button'),
              onPressed: () => unawaited(_saveJsonOnly()),
              child: Text(l10n.accountExportJsonButton),
            ),
            TextButton(
              key: const ValueKey('export-cancel-ready'),
              onPressed: () => _reset(_Outcome.cancelled),
              child: Text(l10n.accountExportCancel),
            ),
          ],
          if (_step == _Step.building) ...[
            Text(
              l10n.accountExportProgress(_done, _total),
              key: const ValueKey('export-progress'),
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
            const SizedBox(height: AppSpacing.md),
            _cancelButton(l10n.accountExportCancel),
          ],
          if (_step == _Step.saving) _busyRow(l10n.accountExportPackaging),
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

  Widget _busyLabel(String text) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const PetLoader.small(),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(text)),
        ],
      );

  Widget _busyRow(String text) => Row(
        children: [
          const PetLoader.small(),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      );

  Widget _cancelButton(String text) => OutlinedButton(
        key: const ValueKey('export-cancel'),
        onPressed: () => _cancel?.cancel(),
        child: Text(text),
      );
}
