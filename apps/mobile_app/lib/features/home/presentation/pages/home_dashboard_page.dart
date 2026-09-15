import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../chat/presentation/pages/chat_conversations_page.dart';
import '../../../medical_records/presentation/pages/medical_records_pages.dart';
import '../../../pets/domain/pet_models.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../reminders/presentation/pages/reminders_pages.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../models/home_dashboard_seed_data.dart';
import '../widgets/home_dashboard_sections.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = HomeDashboardSeedData.fromSeeds();
    final activePet = seed.activePet;

    final actions = <WarmClinicalActionButton>[
      WarmClinicalActionButton(
        label: 'Carica documento',
        icon: Icons.upload_file_rounded,
        onPressed: () => _openRecords(context),
      ),
      WarmClinicalActionButton(
        label: 'Apri chat',
        icon: Icons.chat_bubble_outline_rounded,
        onPressed: () => _openChat(context),
      ),
      WarmClinicalActionButton(
        label: 'Nuovo reminder',
        icon: Icons.notifications_active_outlined,
        accentColor: AppColors.accent,
        onPressed: () => _openReminders(context),
      ),
      WarmClinicalActionButton(
        label: 'Profilo pet',
        icon: Icons.pets_rounded,
        accentColor: AppColors.secondary,
        onPressed: () => _openProfile(context),
      ),
    ];

    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF9F6F1),
              Color(0xFFF4EFE7),
              Color(0xFFEDE6DC),
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -120,
              right: -40,
              child: _SoftGlow(
                size: 320,
                color: Color(0x33A9C4BB),
              ),
            ),
            const Positioned(
              left: -60,
              top: 220,
              child: _SoftGlow(
                size: 240,
                color: Color(0x26E6B9A8),
              ),
            ),
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xxxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DashboardTopBar(
                          pet: activePet,
                          alertCount: seed.alertCount,
                      onOpenProfile: () => _openProfile(context),
                      onOpenSettings: () => _openSettings(context),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 1100;
                        final hero = WarmClinicalDashboardHero(
                          petName: activePet.name,
                          petDetails: seed.heroDetails,
                          healthLabel: activePet.healthBadge,
                          healthDescription: seed.heroDescription,
                          petPortrait: _PetPortrait(pet: activePet),
                          primaryActionLabel: 'Apri profilo',
                          secondaryActionLabel: 'Contatta assistente',
                          onPrimaryAction: () => _openProfile(context),
                          onSecondaryAction: () => _openChat(context),
                        );
                        final remindersSection = WarmClinicalReminderSection(
                          title: 'Scadenze vicine',
                          items: seed.reminders,
                          footerLabel: 'Vedi tutti',
                          onFooterTap: () => _openReminders(context),
                        );

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: hero),
                              const SizedBox(width: AppSpacing.xl),
                              Expanded(flex: 5, child: remindersSection),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            hero,
                            const SizedBox(height: AppSpacing.xl),
                            remindersSection,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _QuickMetricsRow(pet: activePet),
                    const SizedBox(height: AppSpacing.xl),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 1100;
                        final aiPanel = WarmClinicalAiPanel(
                          title: 'Assistente Vet AI',
                          prompt: seed.aiPrompt,
                          suggestions: seed.aiSuggestions,
                          primaryActionLabel: 'Apri chat',
                          onPrimaryAction: () => _openChat(context),
                        );
                        final documentsSection = WarmClinicalDocumentSection(
                          title: 'Cartella clinica',
                          items: seed.documents,
                          footerLabel: 'Gestisci file',
                          onFooterTap: () => _openRecords(context),
                        );

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: aiPanel),
                              const SizedBox(width: AppSpacing.xl),
                              Expanded(flex: 5, child: documentsSection),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            aiPanel,
                            const SizedBox(height: AppSpacing.xl),
                            documentsSection,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 1100;
                        final activitySection = WarmClinicalActivitySection(
                          title: 'Attivita recente',
                          items: seed.activity,
                          footerLabel: 'Apri storico',
                          onFooterTap: () => _openProfile(context),
                        );
                        final actionsSection = _DashboardActionSection(actions: actions);

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: activitySection),
                              const SizedBox(width: AppSpacing.xl),
                              Expanded(flex: 5, child: actionsSection),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            activitySection,
                            const SizedBox(height: AppSpacing.xl),
                            actionsSection,
                          ],
                        );
                      },
                    ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
    );
  }

  static void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  static void _openChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ChatConversationsPage()),
    );
  }

  static void _openRecords(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MedicalRecordsListPage()),
    );
  }

  static void _openReminders(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RemindersListPage()),
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.pet,
    required this.alertCount,
    required this.onOpenProfile,
    required this.onOpenSettings,
  });

  final PetProfile pet;
  final int alertCount;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.lg,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryStrong,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: const Text(
                'Warm Clinical Dashboard',
                style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.25,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Benvenuto, Roberto', style: AppTextStyles.display),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Una vista chiara su salute, documenti e prossime scadenze di ${pet.name}.',
              style: AppTextStyles.body,
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _SoftPill(
              icon: Icons.pets_rounded,
              label: '${pet.name} attivo',
            ),
            _SoftPill(
              icon: Icons.notifications_none_rounded,
              label: '$alertCount alert',
            ),
            IconButton.filledTonal(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Impostazioni',
            ),
            FilledButton.tonalIcon(
              onPressed: onOpenProfile,
              icon: const Icon(Icons.person_outline_rounded),
              label: const Text('Profilo'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickMetricsRow extends StatelessWidget {
  const _QuickMetricsRow({required this.pet});

  final PetProfile pet;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        WarmClinicalMetricPill(
          label: 'Peso registrato',
          value: pet.weightLabel,
        ),
        WarmClinicalMetricPill(
          label: 'Nato',
          value: pet.birthDateLabel,
        ),
        WarmClinicalMetricPill(
          label: 'Stato attuale',
          value: pet.healthBadge,
          accentColor: AppColors.success,
        ),
        WarmClinicalMetricPill(
          label: 'Prossima visita',
          value: pet.nextVisitLabel,
          accentColor: AppColors.accent,
        ),
      ],
    );
  }
}

class _DashboardActionSection extends StatelessWidget {
  const _DashboardActionSection({required this.actions});

  final List<WarmClinicalActionButton> actions;

  @override
  Widget build(BuildContext context) {
    return WarmClinicalSectionCard(
      title: 'Azioni rapide',
      subtitle: 'Le azioni piu usate arrivano direttamente dalla dashboard.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Questa vista usa i seed reali di pets, chat e cartella clinica. Il layout resta demo-friendly ma i contenuti non sono piu hardcoded.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.lg),
          WarmClinicalActionRow(actions: actions),
        ],
      ),
    );
  }
}

class _SoftPill extends StatelessWidget {
  const _SoftPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _PetPortrait extends StatelessWidget {
  const _PetPortrait({required this.pet});

  final PetProfile pet;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints.tightFor(height: 240),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8F4ED),
            Color(0xFFE8F0EA),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -36,
            top: -24,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.accentSoft.withValues(alpha: 0.75),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 124,
                  height: 124,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryStrong,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    pet.avatarEmoji,
                    style: AppTextStyles.display.copyWith(
                      color: AppColors.onPrimary,
                      fontSize: 48,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  pet.name,
                  style: AppTextStyles.title.copyWith(fontSize: 22),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${pet.species} - ${pet.sex}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftGlow extends StatelessWidget {
  const _SoftGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
