import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../auth/data/auth_repository_factory.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';
import '../../../notifications/application/notification_scheduler.dart';
import '../../../pets/data/pet_photo_repository.dart';
import '../../data/profile_photo_repository.dart';
import '../widgets/account_page_scaffold.dart';
import 'change_password_page.dart';

/// Account deletion (required by the App Store, Google Play and GDPR art. 17).
/// The owner must type their password and tick that they understand; the
/// backend then erases their data and the sign-in account.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  bool _understood = false;
  bool _deleting = false;
  String? _passwordError;
  String? _failure;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_formKey.currentState!.validate() || !_understood || _deleting) return;
    final l10n = context.l10n;
    setState(() {
      _deleting = true;
      _passwordError = null;
      _failure = null;
    });

    final result = await const AuthRepositoryFactory().create().deleteAccount(
          password: _password.text,
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        // Nothing of this account may stay on the phone.
        unawaited(NotificationScheduler.instance.clearAll());
        unawaited(PetPhotoRepository.clearLocalCaches());
        ProfilePhotoRepository.clearLocalCache();
        final navigator = Navigator.of(context, rootNavigator: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.accountDeleteDone)),
        );
        navigator.pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
      },
      onFailure: (error) => setState(() {
        _deleting = false;
        if (isWrongPasswordError(error)) {
          _passwordError = l10n.accountPasswordCurrentWrong;
        } else {
          _failure = l10n.accountDeleteFailed;
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AccountPageScaffold(
      title: l10n.accountDeleteTitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
          ],
        ),
      ),
    );
  }
}
