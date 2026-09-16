import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/auth/current_user.dart';
import '../../../../shared/widgets/coming_soon_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;
  bool _activityReminders = true;
  bool _analytics = false;
  String _weightUnit = 'kg';

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
    );
  }

  void _openHelpCenter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ComingSoonPage(
          title: 'Centro assistenza',
          icon: Icons.help_outline_rounded,
          description: 'Domande frequenti e guide rapide, presto disponibili direttamente qui.',
        ),
      ),
    );
  }

  void _showInfoDialog(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
        title: Text(title, style: AppTextStyles.title.copyWith(fontSize: 17)),
        content: Text(body, style: AppTextStyles.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  void _rateApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grazie per il supporto! ⭐')),
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
              icon: Icons.notifications_active_outlined,
              iconColor: AppColors.primary,
              title: 'Notifiche push',
              value: _notifications,
              onChanged: (value) => setState(() => _notifications = value),
            ),
            _ToggleRow(
              icon: Icons.event_available_outlined,
              iconColor: AppColors.success,
              title: 'Promemoria attività',
              value: _activityReminders,
              onChanged: (value) => setState(() => _activityReminders = value),
            ),
            _UnitRow(
              value: _weightUnit,
              onChanged: (value) => setState(() => _weightUnit = value),
            ),
            const _SectionLabel('Privacy'),
            _ToggleRow(
              icon: Icons.insights_outlined,
              iconColor: AppColors.info,
              title: "Analisi d'uso",
              value: _analytics,
              onChanged: (value) => setState(() => _analytics = value),
            ),
            _Row(
              icon: Icons.lock_outline_rounded,
              iconColor: AppColors.secondary,
              title: 'Gestisci dati personali',
              onTap: () => _showInfoDialog(
                'Dati personali',
                'Puoi richiedere una copia o la cancellazione dei tuoi dati in qualsiasi momento scrivendo al supporto.',
              ),
            ),
            const _SectionLabel('Assistenza'),
            _Row(
              icon: Icons.help_outline_rounded,
              iconColor: AppColors.primary,
              title: 'Centro assistenza',
              onTap: _openHelpCenter,
            ),
            _Row(
              icon: Icons.mail_outline_rounded,
              iconColor: AppColors.accent,
              title: 'Contattaci',
              subtitle: 'supporto@vetapp.it',
              onTap: () => _showInfoDialog(
                'Contattaci',
                'Scrivi a supporto@vetapp.it per qualsiasi domanda: rispondiamo di solito entro un giorno lavorativo.',
              ),
            ),
            _Row(
              icon: Icons.star_outline_rounded,
              iconColor: AppColors.warning,
              title: "Valuta l'app",
              onTap: _rateApp,
            ),
            const _SectionLabel('Info'),
            const _Row(
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.mutedText,
              title: 'Versione app',
              trailingText: '1.0.0',
            ),
            _Row(
              icon: Icons.description_outlined,
              iconColor: AppColors.mutedText,
              title: 'Termini di servizio',
              onTap: () => _showInfoDialog(
                'Termini di servizio',
                'I termini completi saranno disponibili qui prima del lancio pubblico dell\'app.',
              ),
            ),
            _Row(
              icon: Icons.shield_outlined,
              iconColor: AppColors.mutedText,
              title: 'Privacy policy',
              onTap: () => _showInfoDialog(
                'Privacy policy',
                'L\'informativa completa sulla privacy sarà disponibile qui prima del lancio pubblico dell\'app.',
              ),
            ),
            const _SectionLabel('Account'),
            _Row(
              icon: Icons.logout_rounded,
              iconColor: AppColors.danger,
              title: 'Esci',
              titleColor: AppColors.danger,
              onTap: _logout,
            ),
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

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    this.leading,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailingText,
    this.onTap,
  });

  final Widget? leading;
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveLeading = leading ?? (icon != null ? _IconBadge(icon: icon!, color: iconColor ?? AppColors.primary) : null);

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
              if (effectiveLeading != null) ...[effectiveLeading, const SizedBox(width: AppSpacing.md)],
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
              if (trailingText != null)
                Text(trailingText!, style: AppTextStyles.bodySmall)
              else if (onTap != null)
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
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
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
          _IconBadge(icon: icon, color: iconColor),
          const SizedBox(width: AppSpacing.md),
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

class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const _IconBadge(icon: Icons.scale_outlined, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Unità di misura',
              style: AppTextStyles.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
            ),
          ),
          _UnitToggleButton(label: 'kg', selected: value == 'kg', onTap: () => onChanged('kg')),
          const SizedBox(width: AppSpacing.xs),
          _UnitToggleButton(label: 'lb', selected: value == 'lb', onTap: () => onChanged('lb')),
        ],
      ),
    );
  }
}

class _UnitToggleButton extends StatelessWidget {
  const _UnitToggleButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
