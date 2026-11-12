import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/errors/app_error.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../auth/data/auth_repository_factory.dart';
import '../../../auth/domain/auth_error_messages.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';
import '../widgets/account_page_scaffold.dart';

/// True when [error] is "the password you typed is wrong" (Supabase answers
/// `invalid_credentials` / "Invalid login credentials").
bool isWrongPasswordError(AppError error) {
  final code = error.code.toLowerCase();
  final message = error.message.toLowerCase();
  return code == 'invalid_credentials' ||
      message.contains('invalid login credentials') ||
      message.contains('incorrect');
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();

  bool _saving = false;
  String? _currentError;
  String? _newError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final l10n = context.l10n;
    setState(() {
      _saving = true;
      _currentError = null;
      _newError = null;
    });

    final result = await const AuthRepositoryFactory().create().changePassword(
          currentPassword: _current.text,
          newPassword: _next.text,
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.accountPasswordChanged)),
        );
        Navigator.of(context).maybePop();
      },
      onFailure: (error) {
        setState(() {
          _saving = false;
          if (isWrongPasswordError(error)) {
            _currentError = l10n.accountPasswordCurrentWrong;
          } else {
            final presented = presentAuthError(error);
            if (presented.field == AuthErrorField.password) {
              _newError = presented.message;
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(presented.message)),
              );
            }
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AccountPageScaffold(
      title: l10n.accountPasswordTitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthInputField(
              controller: _current,
              label: l10n.accountPasswordCurrent,
              hintText: '',
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              serverError: _currentError,
              validator: (value) =>
                  (value ?? '').isEmpty ? l10n.accountPasswordCurrentRequired : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AuthInputField(
              controller: _next,
              label: l10n.accountPasswordNew,
              hintText: l10n.authPasswordHint,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              serverError: _newError,
              // Same rules as sign-up.
              validator: (value) {
                final text = value ?? '';
                if (text.isEmpty) return l10n.authPasswordRequiredNew;
                if (text.length < 6) return l10n.authPasswordMinLength;
                if (text == _current.text) return l10n.accountPasswordSameAsOld;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AuthInputField(
              controller: _repeat,
              label: l10n.accountPasswordRepeat,
              hintText: l10n.authConfirmPasswordHint,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) => value != _next.text ? l10n.authPasswordsMismatch : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : () => unawaited(_submit()),
              child: _saving ? const PetLoader.small() : Text(l10n.accountPasswordSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
