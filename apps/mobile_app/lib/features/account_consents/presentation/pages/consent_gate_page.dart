import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../account/presentation/pages/delete_account_page.dart';
import '../../../account/presentation/pages/export_data_page.dart';
import '../../../auth/data/auth_repository_factory.dart';
import '../../../auth/presentation/pages/legal_text_page.dart';
import '../../data/account_consents_remote_data_source.dart';
import '../../domain/account_consent_models.dart';

/// The page that cannot be dismissed: the backend refuses the app
/// (`consent_required`) until the Terms of Service and the Privacy Policy are
/// accepted at the current version. The owner reads them, ticks the box and goes
/// on, or leaves the account. Nothing optional is touched here.
class ConsentGatePage extends StatefulWidget {
  const ConsentGatePage({super.key, this.dataSource, this.onLeave, this.catalogVersions});

  final AccountConsentsRemoteDataSource? dataSource;

  /// The versions of the catalog already read (the texts the owner can open here): the ones
  /// declared with the acceptance. Without them, this build's own.
  final Map<String, String>? catalogVersions;

  /// What "Esci" does; by default sign out and go to the sign-in page.
  final Future<void> Function(BuildContext context)? onLeave;

  @override
  State<ConsentGatePage> createState() => _ConsentGatePageState();
}

class _ConsentGatePageState extends State<ConsentGatePage> {
  late final AccountConsentsRemoteDataSource _source =
      widget.dataSource ?? HttpAccountConsentsRemoteDataSource();
  bool _accepted = false;
  bool _busy = false;
  bool _failed = false;
  late Map<String, String>? _versions = widget.catalogVersions;

  /// A sentence for the owner when the text changed or the app is too old (null otherwise).
  String? _notice;

  Future<void> _continue() async {
    if (!_accepted || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _notice = null;
    });
    var ok = true;
    var mismatch = false;
    for (final key in const [
      AccountConsentKeys.termsOfService,
      AccountConsentKeys.privacyPolicy,
    ]) {
      final result = await _source.setConsent(
        consentKey: key,
        granted: true,
        shownVersion: AccountConsentKeys.shownVersionIn(_versions, key),
      );
      if (result.isFailure) {
        ok = false;
        final code = result.fold(onSuccess: (_) => null, onFailure: (error) => error.code);
        if (code == kConsentVersionMismatchCode) mismatch = true;
      }
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    if (mismatch) {
      await _reloadCatalog();
      return;
    }
    setState(() {
      _busy = false;
      _failed = true;
    });
  }

  /// The text shown was not the current one: read the catalog again and ask with the new
  /// text (the owner reads it and ticks again). If no newer text can be shown, say that the
  /// app must be updated: nothing is recorded for a text that was not shown.
  Future<void> _reloadCatalog() async {
    final l10n = context.l10n;
    final result = await _source.fetch();
    if (!mounted) return;
    final snapshot = result.fold(onSuccess: (value) => value, onFailure: (_) => null);
    final fresh = snapshot == null
        ? null
        : {for (final key in AccountConsentKeys.mandatory) key: snapshot.catalog[key]?.version ?? ''};
    final changed = fresh != null &&
        fresh.entries.any((e) => e.value.isNotEmpty && e.value != _versions?[e.key]);
    setState(() {
      _busy = false;
      if (changed) {
        _versions = fresh;
        _accepted = false;
        _notice = l10n.consentTextChanged;
      } else {
        _notice = l10n.consentUpdateApp;
      }
    });
  }

  Future<void> _leave() async {
    if (_busy) return;
    final custom = widget.onLeave;
    if (custom != null) {
      await custom(context);
      return;
    }
    await const AuthRepositoryFactory().create().signOut();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
  }

  /// Whoever does not accept the new text can still leave with their data: download them,
  /// put the account in pause or delete it (pages and routes that already exist; the server
  /// keeps them open while a consent is missing).
  Future<void> _otherOptions() async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: Text(l10n.settingsAccountExport),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openPage(const ExportDataPage());
              },
            ),
            ListTile(
              leading: const Icon(Icons.pause_circle_outline_rounded),
              title: Text(l10n.consentGatePauseOrDelete),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openPage(const DeleteAccountPage());
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _open(String key, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LegalTextPage(consentKey: key, title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.consentGateTitle, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.consentGateBody, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      _open(AccountConsentKeys.termsOfService, l10n.authTermsOfServiceLabel),
                  child: Text(l10n.authTermsOfServiceLabel),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      _open(AccountConsentKeys.privacyPolicy, l10n.authPrivacyPolicyLabel),
                  child: Text(l10n.authPrivacyPolicyLabel),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _accepted,
                onChanged: _busy ? null : (value) => setState(() => _accepted = value ?? false),
                title: Text(
                  l10n.authTermsAcceptance(
                      l10n.authTermsOfServiceLabel, l10n.authPrivacyPolicyLabel),
                  style: AppTextStyles.bodySmall,
                ),
              ),
              if (_notice != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _notice!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
                ),
              ],
              if (_failed) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.consentGateFailed,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _accepted && !_busy ? () => unawaited(_continue()) : null,
                child: _busy ? const PetLoader.small() : Text(l10n.consentGateContinue),
              ),
              TextButton(
                onPressed: _busy ? null : () => unawaited(_leave()),
                child: Text(l10n.settingsLogout),
              ),
              TextButton(
                key: const Key('consentGateOtherOptions'),
                onPressed: _busy ? null : () => unawaited(_otherOptions()),
                child: Text(l10n.consentGateOtherOptions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
