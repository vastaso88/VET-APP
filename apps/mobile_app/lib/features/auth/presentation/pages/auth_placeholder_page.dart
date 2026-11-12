import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../account/data/device_registry.dart';
import '../widgets/auth_widgets.dart';
import 'login_page.dart';
import 'register_page.dart';

class AuthPlaceholderPage extends StatefulWidget {
  const AuthPlaceholderPage({super.key});

  @override
  State<AuthPlaceholderPage> createState() => _AuthPlaceholderPageState();
}

class _AuthPlaceholderPageState extends State<AuthPlaceholderPage> {
  // Shown once: the app signed this device out because the plan's device
  // limit was reached and a newer device took its place.
  late final bool _signedOutForDeviceLimit = DeviceRegistry.takePendingNotice();

  @override
  Widget build(BuildContext context) {
    return AuthScreenScaffold(
      title: context.l10n.authHubTitle,
      allowBack: false,
      subtitle: context.l10n.authHubSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_signedOutForDeviceLimit) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
              child: Text(
                context.l10n.authDeviceLimitNotice,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
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
