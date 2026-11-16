import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/regional_defaults.dart';
import '../../../age/data/age_store.dart';
import '../../../age/domain/age_status.dart';
import '../../../auth/data/auth_repository_factory.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';
import '../../../notifications/application/notification_scheduler.dart';
import '../../../pets/data/pet_photo_repository.dart';
import '../../data/account_deletion_remote_data_source.dart';
import '../../data/profile_photo_repository.dart';
import '../widgets/account_page_scaffold.dart';
import 'change_password_page.dart';

/// Account deletion (required by the App Store, Google Play and GDPR art. 17).
/// The owner must type their password and tick that they understand; the
/// backend then erases their data and the sign-in account.
enum _Leave { pause, delete }

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  /// Nothing is chosen at first: neither road is preselected (docs/auth/02).
  _Leave? _choice;
  bool _pausing = false;
  bool _understood = false;
  bool _deleting = false;
  String? _passwordError;
  String? _failure;

  /// The backend's period to change one's mind (a setting, read from there).
  /// Null until known, and for an account closed for age, which is erased at
  /// once with no period.
  DeletionStatus? _period;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPeriod());
  }

  Future<void> _loadPeriod() async {
    if (AgeStore.instance.status.band == AgeBand.underMinimum) return;
    final result = await HttpAccountDeletionRemoteDataSource().fetch();
    if (!mounted) return;
    result.fold(
      onSuccess: (status) => setState(() => _period = status),
      onFailure: (_) {},
    );
  }

  /// The day the account would be erased if the owner confirmed now.
  DateTime? _erasureDay() {
    final period = _period;
    return period == null ? null : DateTime.now().add(Duration(days: period.graceDays));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete({bool immediate = false}) async {
    if (!_formKey.currentState!.validate() || !_understood || _deleting) return;
    final l10n = context.l10n;
    setState(() {
      _deleting = true;
      _passwordError = null;
      _failure = null;
    });

    final result = await const AuthRepositoryFactory().create().deleteAccount(
          password: _password.text,
          immediate: immediate,
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        // Nothing of this account may stay on the phone.
        unawaited(NotificationScheduler.instance.clearAll());
        unawaited(PetPhotoRepository.clearLocalCaches());
        ProfilePhotoRepository.clearLocalCache();
        final navigator = Navigator.of(context, rootNavigator: true);
        final day = immediate ? null : _erasureDay();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // The sign-in page opens under it: long enough to read the date.
            duration: const Duration(seconds: 10),
            content: Text(
              day == null
                  ? l10n.accountDeleteDone
                  : l10n.accountDeleteScheduledDone(formatAppDate(day, appNumericDatePattern())),
            ),
          ),
        );
        navigator.pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
      },
      onFailure: (error) => setState(() {
        _deleting = false;
        if (isWrongPasswordError(error)) {
          _passwordError = l10n.accountPasswordCurrentWrong;
        } else if (error.code == 'reauth_required') {
          // The server found the sign-in too old: ask for the password again.
          _password.clear();
          _passwordError = l10n.accountDeleteReauth;
        } else {
          _failure = l10n.accountDeleteFailed;
        }
      }),
    );
  }

  Future<void> _pause() async {
    if (_pausing || _deleting) return;
    final l10n = context.l10n;
    setState(() {
      _pausing = true;
      _failure = null;
    });
    final result = await HttpAccountDeletionRemoteDataSource().pause();
    if (!mounted) return;
    await result.fold(
      onSuccess: (deleteAfter) async {
        // The account is inactive now: nothing of it stays on the phone, and the
        // session that asked is refused by the server from here on.
        unawaited(NotificationScheduler.instance.clearAll());
        unawaited(PetPhotoRepository.clearLocalCaches());
        ProfilePhotoRepository.clearLocalCache();
        await const AuthRepositoryFactory().create().signOut();
        if (!mounted) return;
        final navigator = Navigator.of(context, rootNavigator: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.accountPauseDone(
                formatAppDate(
                  deleteAfter ?? DateTime.now().add(const Duration(days: 730)),
                  appNumericDatePattern(),
                ),
              ),
            ),
          ),
        );
        navigator.pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
      },
      onFailure: (_) async => setState(() {
        _pausing = false;
        _failure = l10n.accountPauseFailed;
      }),
    );
  }

  Widget _choiceCard({
    required _Leave value,
    required String title,
    required String body,
    required Color accent,
  }) {
    final selected = _choice == value;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large),
        onTap: _pausing || _deleting ? null : () => setState(() => _choice = value),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(
              color: selected ? accent : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? accent : AppColors.mutedText,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(title, style: AppTextStyles.title.copyWith(fontSize: 17)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(body, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // A closed account (declared age under the minimum) cannot pause: the server
    // refuses everything but deleting itself, so the card is not offered.
    final canPause = AgeStore.instance.status.band != AgeBand.underMinimum;

    return AccountPageScaffold(
      title: l10n.accountDeleteTitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.accountLeaveQuestion, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            if (canPause) ...[
              _choiceCard(
                value: _Leave.pause,
                title: l10n.accountPauseOptionTitle,
                // The number is the server's setting; 24 only until it is read.
                body: l10n.accountPauseOptionBody(_period?.pauseMaxMonths ?? 24),
                accent: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _choiceCard(
              value: _Leave.delete,
              title: l10n.accountDeleteOptionTitle,
              body: l10n.accountDeleteOptionBody,
              accent: AppColors.danger,
            ),
            if (_choice == _Leave.pause) ...[
              const SizedBox(height: AppSpacing.lg),
              if (_failure != null) ...[
                Text(
                  _failure!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              FilledButton(
                onPressed: _pausing ? null : () => unawaited(_pause()),
                child: _pausing ? const PetLoader.small() : Text(l10n.accountPauseSubmit),
              ),
            ],
            if (_choice == _Leave.delete) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.large),
                border: Border.all(color: AppColors.danger),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.accountDeleteWarningTitle,
                          style: AppTextStyles.title.copyWith(
                            color: AppColors.danger,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.accountDeleteWarningBody, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            if (_period != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.accountDeletePeriodNote(
                  _period!.graceDays,
                  formatAppDate(_erasureDay()!, appNumericDatePattern()),
                ),
                style: AppTextStyles.body.copyWith(color: AppColors.text),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AuthInputField(
              controller: _password,
              label: l10n.accountDeletePasswordLabel,
              hintText: '',
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              serverError: _passwordError,
              validator: (value) =>
                  (value ?? '').isEmpty ? l10n.accountDeletePasswordRequired : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _understood,
              onChanged: _deleting ? null : (value) => setState(() => _understood = value ?? false),
              title: Text(l10n.accountDeleteUnderstood, style: AppTextStyles.bodySmall),
            ),
            if (_failure != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_failure!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.onPrimary,
              ),
              onPressed: _understood && !_deleting ? () => unawaited(_delete()) : null,
              child: _deleting ? const PetLoader.small() : Text(l10n.accountDeleteSubmit),
            ),
            if (_period != null)
              TextButton(
                onPressed: _understood && !_deleting ? () => unawaited(_delete(immediate: true)) : null,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(l10n.accountDeleteNowLink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
