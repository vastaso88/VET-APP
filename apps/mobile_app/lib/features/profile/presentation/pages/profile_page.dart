import 'package:flutter/material.dart';

import '../../../../../design_system/tokens/app_colors.dart';
import '../../../../../design_system/tokens/app_radii.dart';
import '../../../../../design_system/tokens/app_spacing.dart';
import '../../../../../design_system/tokens/app_text_styles.dart';
import '../../../../../shared/auth/current_user.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _darkMode = false;

  void _openSettings() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  void _showLogoutPreview() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logout pronto per essere collegato al flusso account reale.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = CurrentUser.get();
    final ownerName = CurrentUser.fullName(fallback: 'Ospite');
    final ownerEmail = user?.email ?? 'Nessuna sessione attiva';

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
                  onLogoutPreview: _showLogoutPreview,
                ),
                const SizedBox(height: AppSpacing.lg),
                _SummaryCard(
                  title: ownerName,
                  body: 'Profilo owner collegato a ${_petCountLabel()} e pronto per la web app responsive.',
                  icon: Icons.verified_user_outlined,
                ),
                const SizedBox(height: AppSpacing.lg),
                _InfoCard(
                  title: 'Contatti',
                  rows: [
                    _InfoRow(label: 'Email', value: ownerEmail),
                    const _InfoRow(label: 'Telefono', value: 'Non specificato'),
                    const _InfoRow(label: 'Città', value: 'Non specificata'),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _ToggleCard(
                  title: 'Tema serale',
                  body: 'Anteprima di una palette piu soft per l uso serale.',
                  value: _darkMode,
                  onChanged: (value) => setState(() => _darkMode = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _InfoCard(
                  title: 'Stato account',
                  rows: [
                    _InfoRow(label: 'Sessione', value: 'Attiva'),
                    _InfoRow(label: 'Privacy', value: 'Aggiornata'),
                    _InfoRow(label: 'Supporto', value: 'Disponibile'),
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

  String _petCountLabel() => '2 pet';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.onOpenSettings,
    required this.onLogoutPreview,
  });

  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogoutPreview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Indietro'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Impostazioni'),
            ),
            FilledButton.tonalIcon(
              onPressed: onLogoutPreview,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Logout'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const _BrandPill(),
        const SizedBox(height: AppSpacing.lg),
        Text('Profilo', style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Dati owner, preferenze e dettagli account in un unico posto per la web app responsive.',
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
            'VET APP',
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
                  Text(row.value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text)),
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
            'Prossimi step',
            style: AppTextStyles.title.copyWith(color: AppColors.onPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Qui possiamo far evolvere consensi, preferenze e collegamento account senza cambiare il flusso web.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onPrimary),
          ),
        ],
      ),
    );
  }
}
