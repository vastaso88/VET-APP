import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/regional_defaults.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../age/data/age_store.dart';
import '../../../auth/data/auth_repository_factory.dart';
import '../../data/account_deletion_remote_data_source.dart';
import '../widgets/account_page_scaffold.dart';

/// What a signed-in owner sees while their account is waiting to be erased:
/// nothing else works. They can cancel the deletion (the account opens again as
/// it was) or sign out. Reached with the same e-mail, after a password reset
/// through the e-mail link if they had forgotten it.
class RestoreAccountPage extends StatefulWidget {
  const RestoreAccountPage({super.key, required this.status, this.dataSource});

  final DeletionStatus status;

  /// Injectable for tests.
  final AccountDeletionRemoteDataSource? dataSource;

  @override
  State<RestoreAccountPage> createState() => _RestoreAccountPageState();
}

class _RestoreAccountPageState extends State<RestoreAccountPage> {
  late final AccountDeletionRemoteDataSource _dataSource =
      widget.dataSource ?? HttpAccountDeletionRemoteDataSource();
  bool _busy = false;
  String? _error;

  Future<void> _cancel() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _dataSource.cancel();
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.accountRestoreDone)));
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil(AppRouter.homeShell, (route) => false);
      },
      onFailure: (error) => setState(() {
        _busy = false;
        _error = error.code == 'reauth_required' ? l10n.accountRestoreReauth : l10n.accountRestoreFailed;
      }),
    );
  }

  Future<void> _deleteNow() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.accountRestoreDeleteNow),
        content: Text(dialogContext.l10n.accountRestoreDeleteNowBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: Size.zero,
            ),
            child: Text(dialogContext.l10n.accountRestoreDeleteNow),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _dataSource.deleteNow();
    if (!mounted) return;
    await result.fold(
      onSuccess: (_) async {
        final navigator = Navigator.of(context, rootNavigator: true);
        await const AuthRepositoryFactory().create().signOut();
        await AgeStore.instance.reset();
        navigator.pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
      },
      onFailure: (error) async => setState(() {
        _busy = false;
        _error = error.code == 'reauth_required' ? l10n.accountRestoreReauth : l10n.accountDeleteFailed;
      }),
    );
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    await const AuthRepositoryFactory().create().signOut();
    await AgeStore.instance.reset();
    navigator.pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final purgeAfter = widget.status.purgeAfter;
    final date = purgeAfter == null ? '' : formatAppDate(purgeAfter, appNumericDatePattern());
    return PopScope(
      canPop: false,
      child: AccountPageScaffold(
        title: l10n.accountRestoreTitle,
        showBack: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.hourglass_bottom_rounded, size: 40, color: AppColors.mutedText),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.accountRestoreBody(date),
              style: AppTextStyles.body.copyWith(color: AppColors.text),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _busy ? null : _cancel,
              child: _busy ? const PetLoader.small() : Text(l10n.accountRestoreCancel),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: _busy ? null : _signOut, child: Text(l10n.settingsLogout)),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _busy ? null : _deleteNow,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: Text(l10n.accountRestoreDeleteNow),
            ),
          ],
        ),
      ),
    );
  }
}
