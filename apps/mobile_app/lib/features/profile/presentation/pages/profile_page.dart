import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../app/router/app_router.dart';
import '../../../../../design_system/tokens/app_colors.dart';
import '../../../../../design_system/tokens/app_radii.dart';
import '../../../../../design_system/tokens/app_spacing.dart';
import '../../../../../design_system/tokens/app_text_styles.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/auth/current_user.dart';
import '../../../auth/data/auth_repository_factory.dart';
import '../../../notifications/application/notification_scheduler.dart';
import '../../../../app/shell/home_shell_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _darkMode = false;

  void _openSettings() {
    Navigator.of(context).pop();
    HomeShellNavigation.goToTab(HomeShellNavigation.settingsTab);
  }

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
        title: Text(dialogContext.l10n.profileLogoutDialogTitle, style: AppTextStyles.title.copyWith(fontSize: 17)),
        content: Text(
          dialogContext.l10n.profileLogoutDialogBody,
          style: AppTextStyles.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.commonClose),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(_performLogout());
            },
            child: Text(dialogContext.l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    final result = await const AuthRepositoryFactory().create().signOut();
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        // No reminders or pet names left on the phone after logout.
        unawaited(NotificationScheduler.instance.clearAll());
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
      },
      onFailure: (error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = CurrentUser.get();
    final ownerName = CurrentUser.fullName(fallback: context.l10n.profileGuestName);
    final ownerEmail = user?.email ?? context.l10n.profileNoActiveSession;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBF8), Color(0xFFF4F7F1), Color(0xFFE7EEE5)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  onBack: () => Navigator.of(context).maybePop(),
                  onOpenSettings: _openSettings,
                  onLogout: _confirmLogout,
                ),
                const SizedBox(height: AppSpacing.lg),
                _SummaryCard(
                  title: ownerName,
                  body: context.l10n.profileSummaryBody(_petCountLabel(context)),
                  icon: Icons.verified_user_outlined,
                ),
                const SizedBox(height: AppSpacing.lg),
                _InfoCard(
                  title: context.l10n.profileContactsTitle,
                  rows: [
                    _InfoRow(label: context.l10n.profileEmailLabel, value: ownerEmail),
                    _InfoRow(
                      label: context.l10n.profilePhoneLabel,
                      value: context.l10n.profilePhoneNotSet,
                    ),
                    _InfoRow(
                      label: context.l10n.profileCityLabel,
                      value: context.l10n.profileCityNotSet,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _ToggleCard(
                  title: context.l10n.profileEveningThemeTitle,
                  body: context.l10n.profileEveningThemeBody,
                  value: _darkMode,
                  onChanged: (value) => setState(() => _darkMode = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                _InfoCard(
                  title: context.l10n.profileAccountStatusTitle,
                  rows: [
                    _InfoRow(
                      label: context.l10n.profileSessionLabel,
                      value: context.l10n.profileSessionActive,
                    ),
                    _InfoRow(
                      label: context.l10n.profilePrivacyLabel,
                      value: context.l10n.profilePrivacyUpdated,
                    ),
                    _InfoRow(
                      label: context.l10n.profileSupportLabel,
                      value: context.l10n.profileSupportAvailable,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const _RoadmapCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _petCountLabel(BuildContext context) => context.l10n.profilePetCount(2);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.onOpenSettings,
    required this.onLogout,
  });

  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(context.l10n.commonBack),
            ),
            const Spacer(),
            // OutlinedButton's app-wide theme sets minimumSize to
            // Size.fromHeight(52), i.e. infinite width — every other use of
            // it in this app sits inside an Expanded pair for exactly that
            // reason. Override it back to a natural width here since this
            // one is a standalone pill next to Indietro, not a full-width
            // CTA.
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: Text(context.l10n.profileSettingsButton),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // Kept apart from Indietro/Impostazioni above (its own row, danger
        // tone) so it can't be fat-fingered right after tapping a nearby
        // nav pill — it's a consequential action.
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: onLogout,
            style: OutlinedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(context.l10n.profileLogoutButton),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _BrandPill(),
        const SizedBox(height: AppSpacing.lg),
        Text(context.l10n.profileTitle, style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.profileIntro,
          style: AppTextStyles.body,
        ),
      ],
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline, size: 14, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Text(
            context.l10n.appTitle,
            style: AppTextStyles.caption.copyWith(color: AppColors.onPrimary, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.sm),
                Text(body, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.lg),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(child: Text(row.label, style: AppTextStyles.caption)),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: Text(
                      row.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.title.copyWith(fontSize: 17)),
                const SizedBox(height: AppSpacing.xs),
                Text(body, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.profileRoadmapTitle,
            style: AppTextStyles.title.copyWith(color: AppColors.onPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.profileRoadmapBody,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onPrimary),
          ),
        ],
      ),
    );
  }
}
