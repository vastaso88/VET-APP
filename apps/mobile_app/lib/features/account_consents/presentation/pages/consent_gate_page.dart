import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../auth/data/auth_repository_factory.dart';
import '../../../auth/presentation/pages/legal_text_page.dart';
import '../../data/account_consents_remote_data_source.dart';
import '../../domain/account_consent_models.dart';

/// The page that cannot be dismissed: the backend refuses the app
/// (`consent_required`) until the Terms of Service and the Privacy Policy are
/// accepted at the current version. The owner reads them, ticks the box and goes
/// on, or leaves the account. Nothing optional is touched here.
class ConsentGatePage extends StatefulWidget {
  const ConsentGatePage({super.key, this.dataSource, this.onLeave});

  final AccountConsentsRemoteDataSource? dataSource;

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

  Future<void> _continue() async {
    if (!_accepted || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    var ok = true;
    for (final key in const [
      AccountConsentKeys.termsOfService,
      AccountConsentKeys.privacyPolicy,
    ]) {
      final result = await _source.setConsent(consentKey: key, granted: true);
      if (result.isFailure) ok = false;
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
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
            ],
          ),
        ),
      ),
    );
  }
}
