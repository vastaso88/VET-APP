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

/// The acknowledgement that Quokka does not handle emergencies
/// (docs/compliance/22 §5): its own page and its own box, never pre-ticked, with the
/// short version in front of the owner (no scrolling, not a link). "Non accetto" has
/// the same weight as "Continua" and leads to what the owner can do instead. Shown
/// to every account at the first opening after the clause (a version of its own).
class EmergencyNoticeGatePage extends StatefulWidget {
  const EmergencyNoticeGatePage({super.key, this.dataSource, this.onDecline});

  final AccountConsentsRemoteDataSource? dataSource;

  /// What "Non accetto" does; by default the page of the alternatives.
  final Future<void> Function(BuildContext context)? onDecline;

  @override
  State<EmergencyNoticeGatePage> createState() => _EmergencyNoticeGatePageState();
}

class _EmergencyNoticeGatePageState extends State<EmergencyNoticeGatePage> {
  late final AccountConsentsRemoteDataSource _source =
      widget.dataSource ?? HttpAccountConsentsRemoteDataSource();
  bool _understood = false; // never pre-ticked
  bool _busy = false;
  bool _failed = false;

  Future<void> _continue() async {
    if (!_understood || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final result = await _source.setConsent(
      consentKey: AccountConsentKeys.emergencyNotice,
      granted: true,
    );
    if (!mounted) return;
    if (result.isFailure) {
      setState(() {
        _busy = false;
        _failed = true;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _decline() async {
    if (_busy) return;
    final custom = widget.onDecline;
    if (custom != null) {
      await custom(context);
      return;
    }
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const _EmergencyDeclinePage()));
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
              Semantics(
                header: true,
                child: Text(l10n.emergencyNoticeTitle, style: AppTextStyles.title),
              ),
              const SizedBox(height: AppSpacing.md),
              // The short version, always in view: not behind a link.
              Text(l10n.emergencyNoticeShort, style: AppTextStyles.body),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LegalTextPage(
                        consentKey: AccountConsentKeys.termsOfService,
                        title: l10n.authTermsOfServiceLabel,
                      ),
                    ),
                  ),
                  child: Text(l10n.emergencyNoticeFullLink),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _understood,
                onChanged: _busy ? null : (value) => setState(() => _understood = value ?? false),
                title: Text(l10n.emergencyNoticeCheckbox, style: AppTextStyles.bodySmall),
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
                onPressed: _understood && !_busy ? () => unawaited(_continue()) : null,
                child: _busy ? const PetLoader.small() : Text(l10n.commonContinue),
              ),
              const SizedBox(height: AppSpacing.sm),
              // The same weight as "Continua": same size, same place in the column.
              OutlinedButton(
                onPressed: _busy ? null : () => unawaited(_decline()),
                child: Text(l10n.emergencyNoticeDecline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Non accetto": what the owner can do instead. Nothing here blames or pressures.
class _EmergencyDeclinePage extends StatelessWidget {
  const _EmergencyDeclinePage();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(l10n.emergencyNoticeDeclineTitle, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.emergencyNoticeDeclineBody, style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const ExportDataPage())),
              child: Text(l10n.accountExportTitle),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const DeleteAccountPage())),
              child: Text(l10n.accountDeleteTitle),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () async {
                final navigator = Navigator.of(context, rootNavigator: true);
                await const AuthRepositoryFactory().create().signOut();
                navigator.pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
              },
              child: Text(l10n.settingsLogout),
            ),
          ],
        ),
      ),
    );
  }
}
