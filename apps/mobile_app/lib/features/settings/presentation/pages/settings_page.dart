import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/auth/current_user.dart';
import '../../../profile/presentation/pages/profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;
  bool _analytics = false;

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
    );
  }

  void _logout() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logout non ancora collegato al flusso account.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = CurrentUser.get();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          children: [
            Text('Impostazioni', style: AppTextStyles.display.copyWith(fontSize: 28)),
            const SizedBox(height: AppSpacing.xl),
            _Row(
              leading: _Avatar(letter: CurrentUser.firstName(fallback: 'O').substring(0, 1).toUpperCase()),
              title: CurrentUser.fullName(fallback: 'Ospite'),
              subtitle: user?.email ?? 'Nessuna sessione attiva',
              onTap: _openProfile,
            ),
            const _SectionLabel('Preferenze'),
            _ToggleRow(
              title: 'Notifiche push',
              value: _notifications,
              onChanged: (value) => setState(() => _notifications = value),
            ),
            _ToggleRow(
              title: "Analisi d'uso",
              value: _analytics,
              onChanged: (value) => setState(() => _analytics = value),
            ),
            const _SectionLabel('Account'),
            _Row(title: 'Esci', titleColor: AppColors.danger, onTap: _logout),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.caption.copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    this.leading,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.onTap,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.md)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        color: titleColor ?? AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTextStyles.bodySmall),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.primaryStrong,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          letter,
          style: AppTextStyles.title.copyWith(color: AppColors.onPrimary, fontSize: 16),
        ),
      ),
    );
  }
}
