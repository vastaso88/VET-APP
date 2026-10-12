import 'package:flutter/material.dart';

import '../../../../shared/widgets/pet_loader.dart';


import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../billing/data/subscription_gate.dart';
import '../../data/auth_repository_factory.dart';
import '../../domain/auth_error_messages.dart';
import '../widgets/auth_widgets.dart';
import 'login_page.dart';

/// Second half of password recovery — reached either from a Supabase
/// recovery email link (via the app-wide auth-state listener in
/// bootstrap.dart, no [email] needed: Supabase already has the recovery
/// session active) or, in the fake/offline dev path, directly from
/// [ResetPasswordPage] with [email] set, since there is no real email to
/// click there.
class SetNewPasswordPage extends StatefulWidget {
  const SetNewPasswordPage({super.key, this.email});

  final String? email;

  @override
  State<SetNewPasswordPage> createState() => _SetNewPasswordPageState();
}

class _SetNewPasswordPageState extends State<SetNewPasswordPage> {
  final _authRepository = const AuthRepositoryFactory().create();
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  AuthBannerStatus? _status;
  String _title = '';
  String _message = '';

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      _isLoading = true;
      _status = AuthBannerStatus.loading;
      _title = context.l10n.authSetPasswordLoadingTitle;
      _message = context.l10n.authSetPasswordLoadingMessage;
    });

    final result = await _authRepository.updatePassword(
      email: widget.email,
      newPassword: _passwordController.text,
    );

    if (!mounted) return;
    result.fold(
      onSuccess: (_) async {
        AppRouter.passwordRecoveryPending = false;
        if (_authRepository.currentContext.isSignedIn) {
          final destination = await const SubscriptionGate().resolveDestination();
          if (!mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil(destination, (route) => false);
          return;
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        );
      },
      onFailure: (error) {
        final presented = presentAuthError(error);
        setState(() {
          _isLoading = false;
          _status = AuthBannerStatus.error;
          _title = context.l10n.authSetPasswordFailureTitle;
          _message = presented.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenScaffold(
      title: context.l10n.authSetPasswordTitle,
      subtitle: context.l10n.authSetPasswordSubtitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_status != null)
              AuthStateBanner(status: _status!, title: _title, message: _message),
            AuthInputField(
              controller: _passwordController,
              label: context.l10n.authNewPasswordLabel,
              hintText: context.l10n.authPasswordHint,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) {
                final text = value ?? '';
                if (text.isEmpty) return context.l10n.authPasswordRequiredNew;
                if (text.length < 6) return context.l10n.authPasswordMinLength;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AuthInputField(
              controller: _confirmController,
              label: context.l10n.authConfirmPasswordLabel,
              hintText: context.l10n.authConfirmPasswordHint,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) {
                if (value != _passwordController.text) return context.l10n.authPasswordsMismatch;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: PetLoader.small(),
                      )
                    : Text(context.l10n.authSetPasswordSaveButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
