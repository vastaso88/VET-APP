import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/auth_widgets.dart';
import 'login_page.dart';
import 'register_page.dart';

class AuthPlaceholderPage extends StatelessWidget {
  const AuthPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScreenScaffold(
      title: context.l10n.authHubTitle,
      allowBack: false,
      subtitle: context.l10n.authHubSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginPage()),
              ),
              child: Text(context.l10n.authLoginButton),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
              ),
              child: Text(context.l10n.authHubCreateAccount),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.l10n.authHubPrivacyNote,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
