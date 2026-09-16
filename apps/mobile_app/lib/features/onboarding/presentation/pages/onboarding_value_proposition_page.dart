import 'package:flutter/material.dart';

import '../../../../../design_system/tokens/app_colors.dart';
import '../../../../../design_system/tokens/app_radii.dart';
import '../../../../../design_system/tokens/app_spacing.dart';
import '../../../../../design_system/tokens/app_text_styles.dart';
import '../onboarding_routes.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingValuePropositionPage extends StatelessWidget {
  const OnboardingValuePropositionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      currentStep: 2,
      title: 'Perche usare VET APP',
      subtitle:
          'Un solo posto per documenti, promemoria e supporto quotidiano del tuo pet.',
      primaryActionLabel: 'Continua',
      onPrimaryAction: () {
        Navigator.of(context).push(OnboardingRoutes.privacyDisclaimer());
      },
      secondaryActionLabel: 'Torna indietro',
      onSecondaryAction: () {
        Navigator.of(context).pop();
      },
      content: const [
        _FeatureBullets(),
        SizedBox(height: AppSpacing.xl),
        _StateCard(),
        SizedBox(height: AppSpacing.xl),
        _BenefitGrid(),
      ],
      footerNote:
          'Il flusso iniziale resta semplice: scopri il valore, leggi le regole essenziali, poi accedi.',
    );
  }
}

class _FeatureBullets extends StatelessWidget {
  const _FeatureBullets();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _BulletRow(
          title: 'Promemoria chiari',
          subtitle: 'Vaccini, antiparassitari, visite e scadenze sempre visibili.',
        ),
        SizedBox(height: AppSpacing.md),
        _BulletRow(
          title: 'Documenti ordinati',
          subtitle: 'Referti, PDF e note cliniche raccolti in una timeline unica.',
        ),
        SizedBox(height: AppSpacing.md),
        _BulletRow(
          title: 'Chat guidata',
          subtitle: 'Domande rapide e risposte utili senza perdere il contesto del pet.',
        ),
      ],
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.title.copyWith(fontSize: 16)),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2EC),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cosa puoi mostrare subito', style: AppTextStyles.title),
          SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatusChip(label: 'Onboarding guidato', color: Color(0xFFDDEDE8)),
              _StatusChip(label: 'Pet profile chiaro', color: Color(0xFFFFF5EC)),
              _StatusChip(label: 'Chat contestuale', color: Color(0xFFF5D9D0)),
              _StatusChip(label: 'Reminder visibili', color: Color(0xFFD8E8DD)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _BenefitGrid extends StatelessWidget {
  const _BenefitGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 360
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _BenefitCard(
              width: cardWidth,
              title: 'Piu controllo',
              body: 'Tutto il percorso del pet diventa facile da seguire.',
            ),
            _BenefitCard(
              width: cardWidth,
              title: 'Piu velocita',
              body: 'Le azioni importanti sono a un tap dalla home.',
            ),
          ],
        );
      },
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.width,
    required this.title,
    required this.body,
  });

  final double width;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.large),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentSoft,
              ),
              child: const Icon(Icons.favorite_border, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.title.copyWith(fontSize: 16)),
            const SizedBox(height: AppSpacing.xs),
            Text(body, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
