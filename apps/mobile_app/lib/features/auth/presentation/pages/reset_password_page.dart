import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_spacing.dart';
import '../../data/auth_repository_factory.dart';
import '../widgets/auth_widgets.dart';
import 'login_page.dart';

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
        _title = 'Email non valida';
        _message = 'Inserisci un indirizzo email corretto per continuare.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = AuthBannerStatus.loading;
      _title = 'Invio in corso';
      _message = 'Sto preparando la richiesta di recupero password.';
    });

    final result = await _authRepository.resetPasswordForEmail(_emailController.text);

    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        setState(() {
          _isLoading = false;
          _status = AuthBannerStatus.success;
          _title = 'Email inviata';
          _message = 'Se l account esiste, riceverai il link per il recupero accesso.';
        });
      },
      onFailure: (error) {
        setState(() {
          _isLoading = false;
          _status = AuthBannerStatus.error;
          _title = 'Invio non riuscito';
          _message = error.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenScaffold(
      title: 'Recupera l accesso.',
      subtitle: 'Inserisci la tua email: ti mandiamo un link per reimpostare la password.',
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
                    : const Text('Invia link'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthFooterLink(
              label: 'Torna all accesso',
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
