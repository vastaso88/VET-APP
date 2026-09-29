import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../features/billing/data/subscription_gate.dart';
import '../../../../shared/auth/auth.dart';
import '../../data/auth_repository_factory.dart';
import '../widgets/auth_widgets.dart';
import 'register_page.dart';
import 'reset_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const bool _uiPreviewEnabled = bool.fromEnvironment(
    'ENABLE_UI_PREVIEW',
    defaultValue: false,
  );
  static const String _demoFounderEmail = String.fromEnvironment(
    'DEMO_FOUNDER_EMAIL',
    defaultValue: 'demo-founder-01@vetapp.ai',
  );
  static const String _demoFounderPassword = String.fromEnvironment(
    'DEMO_FOUNDER_PASSWORD',
    defaultValue: 'VetAppDemo2026!',
  );

  final _authRepository = const AuthRepositoryFactory().create();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AuthBannerStatus? _status;
  String _title = '';
  String _message = '';
  bool _isLoading = false;
  bool _rememberMe = true;

  bool get _showUiPreview => kDebugMode || _uiPreviewEnabled;

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
        _title = 'Controlla i campi';
        _message = 'Servono una email valida e una password di almeno 6 caratteri.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = AuthBannerStatus.loading;
      _title = 'Accesso in corso';
      _message = 'Sto verificando le credenziali.';
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
          _title = 'Accesso completato';
          _message = 'La sessione e pronta. Ti porto nel flusso principale.';
        });
        return true;
      },
      onFailure: (error) {
        setState(() {
          _isLoading = false;
          _status = AuthBannerStatus.error;
          _title = 'Accesso non riuscito';
          _message = error.message;
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

  Future<void> _openDevelopmentPreview() async {
    setState(() {
      _isLoading = true;
      _status = AuthBannerStatus.loading;
      _title = 'Apro anteprima sviluppo';
      _message = 'Creo una sessione demo per rendere disponibili anche le API protette.';
    });

    final result = await _authRepository.signInWithPassword(
      const AuthEmailPasswordCredentials(
        email: _demoFounderEmail,
        password: _demoFounderPassword,
      ),
      rememberMe: true,
    );

    if (!mounted) return;

    final success = result.fold(
      onSuccess: (_) {
        setState(() {
          _isLoading = false;
          _status = AuthBannerStatus.success;
          _title = 'Anteprima pronta';
          _message = 'Sessione demo attiva. Apro l’app.';
        });
        return true;
      },
      onFailure: (error) {
        setState(() {
          _isLoading = false;
          _status = AuthBannerStatus.error;
          _title = 'Anteprima non disponibile';
          _message = error.message;
        });
        return false;
      },
    );

    if (!success || !mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.homeShell,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenScaffold(
      title: 'Bentornato.',
      subtitle: 'Accedi per ritrovare i tuoi animali, promemoria e documenti.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_status != null)
              AuthStateBanner(status: _status!, title: _title, message: _message),
            AuthInputField(
              controller: _emailController,
              label: 'Email',
              hintText: 'nome@dominio.it',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Inserisci la tua email.';
                if (!text.contains('@')) return 'Email non valida.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AuthInputField(
              controller: _passwordController,
              label: 'Password',
              hintText: 'Almeno 6 caratteri',
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              validator: (value) {
                final text = value ?? '';
                if (text.isEmpty) return 'Inserisci la password.';
                if (text.length < 6) return 'Minimo 6 caratteri.';
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
                  child: const Text('Resta connesso'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AuthFooterLink(
              label: 'Password dimenticata?',
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Accedi'),
              ),
            ),
            if (_showUiPreview) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _openDevelopmentPreview,
                  icon: const Icon(Icons.developer_mode_rounded),
                  label: const Text('Apri anteprima sviluppo'),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AuthFooterLink(
              label: 'Non hai un account? Registrati',
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
