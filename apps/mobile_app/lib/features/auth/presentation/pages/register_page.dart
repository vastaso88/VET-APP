import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../shared/auth/auth.dart';
import '../../data/auth_repository_factory.dart';
import '../widgets/auth_widgets.dart';
import 'login_page.dart';

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

  bool _acceptTerms = false;
  bool _isLoading = false;
  AuthBannerStatus? _status;
  String _title = '';
  String _message = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || !_acceptTerms) {
      setState(() {
        _status = AuthBannerStatus.error;
        _title = 'Serve un ultimo controllo';
        _message = !_acceptTerms
            ? 'Devi accettare privacy e disclaimer per continuare.'
            : 'Controlla i campi: nome, email e password devono essere validi.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = AuthBannerStatus.loading;
      _title = 'Creazione account';
      _message = 'Sto creando l account e preparando la sessione iniziale.';
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
          _title = 'Account pronto';
          _message = 'Registrazione completata. Ti porto nella home.';
        });
        return true;
      },
      onFailure: (error) {
        setState(() {
          _isLoading = false;
          _status = AuthBannerStatus.error;
          _title = 'Account non creato';
          _message = error.message;
        });
        return false;
      },
    );

    if (success) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.homeShell,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenScaffold(
      title: 'Crea il tuo profilo.',
      subtitle: 'Pochi campi per iniziare a gestire salute e documenti dei tuoi animali.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_status != null)
              AuthStateBanner(status: _status!, title: _title, message: _message),
            AuthInputField(
              controller: _nameController,
              label: 'Nome',
              hintText: 'Il tuo nome',
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Inserisci il tuo nome.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
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
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) {
                final text = value ?? '';
                if (text.isEmpty) return 'Inserisci una password.';
                if (text.length < 6) return 'Minimo 6 caratteri.';
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
                title: const Text(
                  'Accetto privacy e disclaimer medico',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crea account'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthFooterLink(
              label: 'Hai gia un account? Accedi',
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
