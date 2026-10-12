import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/pet_loader.dart';


import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/config/app_runtime_config_loader.dart';
import '../../data/auth_repository_factory.dart';
import '../../domain/auth_error_messages.dart';
import '../widgets/auth_widgets.dart';
import 'login_page.dart';
import 'set_new_password_page.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _authRepository = const AuthRepositoryFactory().create();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  AuthBannerStatus? _status;
  String _title = '';
  String _message = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() {
        _status = AuthBannerStatus.error;
        _title = context.l10n.authResetInvalidTitle;
        _message = context.l10n.authResetInvalidMessage;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = AuthBannerStatus.loading;
      _title = context.l10n.authResetLoadingTitle;
      _message = context.l10n.authResetLoadingMessage;
    });

    final email = _emailController.text.trim();
    final result = await _authRepository.resetPasswordForEmail(email);

    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        // The fake/offline path never sends a real email, so there is no
        // link to click — jump straight to the "set new password" step
        // (what clicking the email link would do on the real Supabase
        // path) so the flow stays fully testable without email infra.
        if (!const AppRuntimeConfigLoader().load().hasSupabaseCredentials) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => SetNewPasswordPage(email: email)),
          );
          return;
        }
        setState(() {
          _isLoading = false;
          _status = AuthBannerStatus.success;
          _title = context.l10n.authResetSuccessTitle;
          _message = context.l10n.authResetSuccessMessage;
        });
      },
      onFailure: (error) {
        setState(() {
          _isLoading = false;
          _status = AuthBannerStatus.error;
          _title = context.l10n.authResetFailureTitle;
          _message = localizedAuthMessage(error);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenScaffold(
      title: context.l10n.authResetTitle,
      subtitle: context.l10n.authResetSubtitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_status != null)
              AuthStateBanner(status: _status!, title: _title, message: _message),
            AuthInputField(
              controller: _emailController,
              label: context.l10n.authEmailLabel,
              hintText: context.l10n.authEmailHint,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return context.l10n.authEmailRequired;
                if (!text.contains('@')) return context.l10n.authEmailInvalid;
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
                    : Text(context.l10n.authResetSendButton),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthFooterLink(
              label: context.l10n.authBackToLoginLink,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
