import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';

import '../../../../shared/widgets/pet_loader.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/auth/auth.dart';
import '../../../account_consents/data/account_consents_remote_data_source.dart';
import '../../../account_consents/domain/account_consent_models.dart';
import '../../../billing/data/subscription_remote_data_source.dart';
import '../../../first_run/presentation/pages/add_first_pet_prompt_page.dart';
import '../../../first_run/presentation/pages/notification_permission_page.dart';
import '../../../first_run/presentation/pages/plan_intro_page.dart';
import '../../../first_run/presentation/pages/tutorial_page.dart';
import '../../data/auth_repository_factory.dart';
import '../../domain/auth_error_messages.dart';
import '../widgets/auth_widgets.dart';
import 'legal_text_page.dart';
import 'login_page.dart';

class _TermsAcceptanceText extends StatefulWidget {
  const _TermsAcceptanceText(
      {required this.onTermsTap, required this.onPrivacyTap});

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  State<_TermsAcceptanceText> createState() => _TermsAcceptanceTextState();
}

class _TermsAcceptanceTextState extends State<_TermsAcceptanceText> {
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = widget.onTermsTap;
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = widget.onPrivacyTap;

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text);
    final link = base.copyWith(
        color: AppColors.primary, decoration: TextDecoration.underline);
    final l10n = context.l10n;
    // The sentence is one localized message; the two link names are swapped
    // in as markers so the surrounding words can move with the language.
    const termsMarker = '\u0001';
    const privacyMarker = '\u0002';
    final sentence = l10n.authTermsAcceptance(termsMarker, privacyMarker);
    final spans = <InlineSpan>[];
    sentence.splitMapJoin(
      RegExp('[$termsMarker$privacyMarker]'),
      onMatch: (match) {
        final isTerms = match[0] == termsMarker;
        spans.add(
          TextSpan(
            text: isTerms
                ? l10n.authTermsOfServiceLabel
                : l10n.authPrivacyPolicyLabel,
            style: link,
            recognizer: isTerms ? _termsTap : _privacyTap,
          ),
        );
        return '';
      },
      onNonMatch: (text) {
        if (text.isNotEmpty) spans.add(TextSpan(text: text));
        return '';
      },
    );
    return Text.rich(TextSpan(style: base, children: spans));
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _authRepository = const AuthRepositoryFactory().create();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _acceptTerms = false;
  bool _isLoading = false;
  AuthBannerStatus? _status;
  String Function(AppLocalizations) _title = (_) => '';
  String Function(AppLocalizations) _message = (_) => '';
  bool _hasValidated = false;
  String Function()? _emailServerError;
  String Function()? _passwordServerError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _hasValidated = true);
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || !_acceptTerms) {
      setState(() {
        _status = AuthBannerStatus.error;
        _title = (l10n) => l10n.authRegisterCheckTitle;
        _message = (l10n) => !_acceptTerms
            ? l10n.authRegisterTermsRequired
            : l10n.authRegisterFieldsInvalid;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _emailServerError = null;
      _passwordServerError = null;
      _status = AuthBannerStatus.loading;
      _title = (l10n) => l10n.authRegisterLoadingTitle;
      _message = (l10n) => l10n.authRegisterLoadingMessage;
    });

    final result = await _authRepository.signUpWithPassword(
      AuthSignUpRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      ),
    );

    if (!mounted) return;
    final success = result.fold(
      onSuccess: (_) {
        setState(() {
          _isLoading = false;
          _status = AuthBannerStatus.success;
          _title = (l10n) => l10n.authRegisterSuccessTitle;
          _message = (l10n) => l10n.authRegisterSuccessMessage;
        });
        return true;
      },
      onFailure: (error) {
        final presented = presentAuthError(error);
        setState(() {
          _isLoading = false;
          _status = AuthBannerStatus.error;
          _title = (l10n) => l10n.authRegisterFailureTitle;
          _message = (_) => presentAuthError(error).message;
          if (presented.field == AuthErrorField.email) {
            _emailServerError = () => presentAuthError(error).message;
          }
          if (presented.field == AuthErrorField.password) {
            _passwordServerError = () => presentAuthError(error).message;
          }
        });
        return false;
      },
    );

    if (success) {
      // Best-effort: the account is already created at this point, so a
      // failure here must not block the user from reaching the app — the
      // Settings "Permessi e consensi" section shows a "Da confermare"
      // fallback for exactly this case (and for accounts that predate this
      // feature entirely).
      final consentsDataSource = HttpAccountConsentsRemoteDataSource();
      unawaited(
        Future.wait([
          consentsDataSource.setConsent(
            consentKey: AccountConsentKeys.termsOfService,
            granted: true,
          ),
          consentsDataSource.setConsent(
            consentKey: AccountConsentKeys.privacyPolicy,
            granted: true,
          ),
        ]),
      );

      // Starts the 10-day free trial server-side (first status lookup for
      // this owner_id creates it — see GetOrCreateSubscriptionService).
      await HttpSubscriptionRemoteDataSource().fetchStatus();

      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await _runFirstRunFlow();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.homeShell,
        (route) => false,
      );
    }
  }

  void _openLegal(String consentKey, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalTextPage(consentKey: consentKey, title: title),
      ),
    );
  }

  /// Plan proposal (trial or immediate pick) → short feature tutorial →
  /// notification permission → optional guided first-pet creation. Each
  /// page pops itself when done, so this just runs them in sequence before
  /// landing on the real home.
  Future<void> _runFirstRunFlow() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlanIntroPage()),
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TutorialPage()),
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => const NotificationPermissionPage()),
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AddFirstPetPromptPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenScaffold(
      title: context.l10n.authRegisterTitle,
      subtitle: context.l10n.authRegisterSubtitle,
      child: Form(
        key: _formKey,
        autovalidateMode:
            _hasValidated ? AutovalidateMode.always : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_status != null)
              AuthStateBanner(
                  status: _status!,
                  title: _title(context.l10n),
                  message: _message(context.l10n)),
            AuthInputField(
              controller: _nameController,
              label: context.l10n.authNameLabel,
              hintText: context.l10n.authNameHint,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return context.l10n.authNameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AuthInputField(
              controller: _emailController,
              label: context.l10n.authEmailLabel,
              hintText: context.l10n.authEmailHint,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              serverError: _emailServerError?.call(),
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
              serverError: _passwordServerError?.call(),
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
              controller: _confirmPasswordController,
              label: context.l10n.authConfirmPasswordLabel,
              hintText: context.l10n.authConfirmPasswordHint,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) {
                if (value != _passwordController.text) {
                  return context.l10n.authPasswordsMismatch;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _acceptTerms,
                onChanged: (value) => setState(() => _acceptTerms = value),
                title: _TermsAcceptanceText(
                  onTermsTap: () => _openLegal(
                    AccountConsentKeys.termsOfService,
                    context.l10n.authTermsOfServiceLabel,
                  ),
                  onPrivacyTap: () => _openLegal(
                    AccountConsentKeys.privacyPolicy,
                    context.l10n.authPrivacyPolicyLabel,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
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
                    : Text(context.l10n.authRegisterButton),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthFooterLink(
              label: context.l10n.authHaveAccountLoginLink,
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
