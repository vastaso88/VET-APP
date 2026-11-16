import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/auth_widgets.dart';
import 'login_page.dart';
import 'reset_password_page.dart';

/// "Recupera account": for an owner who deleted their account and is still
/// within the period to change their mind. There is nothing to type here: the
/// way back is the ordinary one (sign in with the same e-mail, resetting the
/// password through the e-mail link if it is forgotten), after which the app
/// offers to cancel the deletion.
class RecoverAccountPage extends StatelessWidget {
  const RecoverAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthScreenScaffold(
      title: l10n.authRecoverTitle,
      subtitle: l10n.authRecoverSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.authRecoverSteps, style: AppTextStyles.body.copyWith(color: AppColors.text)),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LoginPage()),
            ),
            child: Text(l10n.authRecoverLogin),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ResetPasswordPage()),
            ),
            child: Text(l10n.authRecoverReset),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.authRecoverExpired, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
