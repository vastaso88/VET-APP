import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/auth/auth.dart';
import '../../../../shared/auth/current_user.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../auth/data/auth_repository_factory.dart';
import '../../../auth/domain/auth_error_messages.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';
import '../widgets/account_page_scaffold.dart';

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  bool _saving = false;
  String? _serverError;
  String? _resultMessage;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final l10n = context.l10n;
    final target = _email.text.trim();
    setState(() {
      _saving = true;
      _serverError = null;
      _resultMessage = null;
    });

    final result = await const AuthRepositoryFactory().create().changeEmail(target);
    if (!mounted) return;
    result.fold(
      onSuccess: (status) => setState(() {
        _saving = false;
        _resultMessage = status == EmailChangeStatus.applied
            ? l10n.accountEmailApplied(target)
            : l10n.accountEmailConfirmationSent(target);
      }),
      onFailure: (error) {
        final presented = presentAuthError(error);
        setState(() {
          _saving = false;
          _serverError = presented.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = CurrentUser.get()?.email ?? '';

    return AccountPageScaffold(
      title: l10n.accountEmailTitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.accountEmailCurrent, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            Text(current, style: AppTextStyles.body.copyWith(color: AppColors.text)),
            const SizedBox(height: AppSpacing.lg),
            AuthInputField(
              controller: _email,
              label: l10n.accountEmailNew,
              hintText: l10n.authEmailHint,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              serverError: _serverError,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return l10n.authEmailRequired;
                if (!text.contains('@') || !text.contains('.')) return l10n.authEmailInvalid;
                if (text.toLowerCase() == current.toLowerCase()) return l10n.accountEmailSame;
                return null;
              },
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_resultMessage!, style: AppTextStyles.body.copyWith(color: AppColors.success)),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : () => unawaited(_submit()),
              child: _saving ? const PetLoader.small() : Text(l10n.accountEmailSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
