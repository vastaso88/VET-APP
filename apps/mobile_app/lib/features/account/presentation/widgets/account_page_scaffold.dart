import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../shared/widgets/page_header.dart';

/// Shared frame of the account screens (profile, email, password, delete):
/// the same plain page the other settings screens use.
class AccountPageScaffold extends StatelessWidget {
  const AccountPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showBack = true,
  });

  final String title;

  /// False for a page the owner cannot leave (the closed account).
  final bool showBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PageHeader(
        title: title,
        showBack: showBack ? null : false,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.xxxl,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
