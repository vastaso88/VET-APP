import 'package:flutter/material.dart';

import '../../../../shared/widgets/pet_loader.dart';


import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_spacing.dart';
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
      _title = 'Aggiornamento in corso';
      _message = 'Sto salvando la nuova password.';
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
          _title = 'Aggiornamento non riuscito';
          _message = presented.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenScaffold(
      title: 'Imposta una nuova password.',
      subtitle: 'Scegli una nuova password per il tuo account.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_status != null)
              AuthStateBanner(status: _status!, title: _title, message: _message),
            AuthInputField(
              controller: _passwordController,
              label: 'Nuova password',
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
            const SizedBox(height: AppSpacing.md),
            AuthInputField(
              controller: _confirmController,
              label: 'Conferma password',
              hintText: 'Ripeti la password',
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) {
                if (value != _passwordController.text) return 'Le password non coincidono.';
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
                    : const Text('Salva nuova password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
