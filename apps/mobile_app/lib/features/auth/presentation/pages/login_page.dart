import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/pet_loader.dart';


import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../features/billing/data/subscription_gate.dart';
import '../../../../shared/auth/auth.dart';
import '../../data/auth_repository_factory.dart';
import '../../domain/auth_error_messages.dart';
import '../widgets/auth_widgets.dart';
import 'register_page.dart';
import 'reset_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authRepository = const AuthRepositoryFactory().create();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AuthBannerStatus? _status;
  String _title = '';
  String _message = '';
  bool _isLoading = false;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() {
        _status = AuthBannerStatus.error;
        _title = context.l10n.authBannerCheckFieldsTitle;
        _message = context.l10n.authLoginFieldsInvalidMessage;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = AuthBannerStatus.loading;
      _title = context.l10n.authLoginLoadingTitle;
      _message = context.l10n.authLoginLoadingMessage;
    });

    final result = await _authRepository.signInWithPassword(
      AuthEmailPasswordCredentials(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
      rememberMe: _rememberMe,
    );

    if (!mounted) return;
    final success = result.fold(
      onSuccess: (_) {
        setState(() {
          _isLoading = false;
          _status = AuthBannerStatus.success;
          _title = context.l10n.authLoginSuccessTitle;
          _message = context.l10n.authLoginSuccessMessage;
        });
        return true;
      },
      onFailure: (error) {
        setState(() {
          _isLoading = false;
          _status = AuthBannerStatus.error;
          _title = context.l10n.authLoginFailureTitle;
          _message = localizedAuthMessage(error);
        });
        return false;
      },
    );

    if (success) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      final destination = await const SubscriptionGate().resolveDestination();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        destination,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenScaffold(
      title: context.l10n.authLoginTitle,
      subtitle: context.l10n.authLoginSubtitle,
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
            const SizedBox(height: AppSpacing.md),
            AuthInputField(
              controller: _passwordController,
              label: context.l10n.authPasswordLabel,
              hintText: context.l10n.authPasswordHint,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              validator: (value) {
                final text = value ?? '';
                if (text.isEmpty) return context.l10n.authPasswordRequiredLogin;
                if (text.length < 6) return context.l10n.authPasswordMinLength;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (value) => setState(() => _rememberMe = value ?? true),
                ),
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Text(context.l10n.authRememberMe),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AuthFooterLink(
              label: context.l10n.authForgotPasswordLink,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ResetPasswordPage()),
              ),
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
                    : Text(context.l10n.authLoginButton),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthFooterLink(
              label: context.l10n.authNoAccountRegisterLink,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
