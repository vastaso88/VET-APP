import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../account/presentation/widgets/account_page_scaffold.dart';
import '../../../auth/data/auth_repository_factory.dart';
import '../../data/age_store.dart';

/// The only thing a closed account (declared age under the minimum) can open.
/// It says so, says what will happen, and offers the two ways out: writing to
/// support (a mistyped date is corrected there) and signing out.
class ClosedAccountPage extends StatefulWidget {
  const ClosedAccountPage({super.key});

  @override
  State<ClosedAccountPage> createState() => _ClosedAccountPageState();
}

class _ClosedAccountPageState extends State<ClosedAccountPage> {
  String? _supportEmail = AgeStore.instance.status.supportContactEmail;

  @override
  void initState() {
    super.initState();
    if (_supportEmail == null) unawaited(_loadSupportEmail());
  }

  Future<void> _loadSupportEmail() async {
    await AgeStore.instance.refresh();
    if (mounted) {
      setState(() => _supportEmail = AgeStore.instance.status.supportContactEmail);
    }
  }

  Future<void> _writeToSupport() async {
    final email = _supportEmail;
    if (email == null) return;
    final uri = Uri.parse(
        'mailto:$email?subject=${Uri.encodeComponent(context.l10n.ageClosedMailSubject)}');
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    await const AuthRepositoryFactory().create().signOut();
    await AgeStore.instance.reset();
    navigator.pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      child: AccountPageScaffold(
        title: l10n.ageClosedTitle,
        showBack: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.mutedText),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.ageClosedBody, style: AppTextStyles.body.copyWith(color: AppColors.text)),
            const SizedBox(height: AppSpacing.xl),
            if (_supportEmail != null)
              FilledButton(onPressed: _writeToSupport, child: Text(l10n.ageClosedContact)),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: _signOut, child: Text(l10n.settingsLogout)),
          ],
        ),
      ),
    );
  }
}
