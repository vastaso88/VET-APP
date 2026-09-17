import 'package:flutter/material.dart';

import '../../../../../design_system/tokens/app_colors.dart';
import '../../../../../design_system/tokens/app_radii.dart';
import '../../../../../design_system/tokens/app_spacing.dart';
import '../../../../../design_system/tokens/app_text_styles.dart';
import '../../../auth/presentation/pages/auth_placeholder_page.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingPrivacyDisclaimerPage extends StatelessWidget {
  const OnboardingPrivacyDisclaimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      currentStep: 3,
      title: 'Privacy e disclaimer',
      subtitle:
          'Prima di entrare, chiarimo come usiamo i dati e cosa non puo sostituire l app.',
      primaryActionLabel: 'Accetto e continua',
      onPrimaryAction: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AuthPlaceholderPage()),
        );
      },
      secondaryActionLabel: 'Torna al valore',
      onSecondaryAction: () {
        Navigator.of(context).pop();
      },
      content: const [
        _PolicyCard(
          title: 'Dati personali',
          body:
              'Le informazioni del profilo servono a rendere l esperienza utile e coerente, con attenzione a privacy e sicurezza.',
        ),
        SizedBox(height: AppSpacing.md),
        _PolicyCard(
          title: 'Suggerimenti IA',
          body:
              'I suggerimenti aiutano a orientarti, ma non sostituiscono il parere di un veterinario.',
        ),
        SizedBox(height: AppSpacing.md),
        _PolicyCard(
          title: 'Trasparenza IA',
          body:
              'Quando una risposta, un report o un immagine sono generati automaticamente, te lo segnaliamo sempre, come previsto dal Regolamento UE sull intelligenza artificiale (AI Act).',
        ),
        SizedBox(height: AppSpacing.md),
        _PolicyCard(
          title: 'Responsabilita',
          body:
              'In caso di sintomi urgenti o dubbi clinici importanti, contatta sempre un professionista.',
        ),
        SizedBox(height: AppSpacing.xl),
        _DisclaimerStateRow(),
      ],
      footerNote:
          'Il consenso resta esplicito e puoi rivedere queste informazioni in seguito.',
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title.copyWith(fontSize: 16)),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _DisclaimerStateRow extends StatelessWidget {
  const _DisclaimerStateRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _StatusPill(label: 'Privacy chiara', color: Color(0xFFDDEDE8)),
        _StatusPill(label: 'Uso responsabile IA', color: Color(0xFFFFF5EC)),
        _StatusPill(label: 'Supporto, non diagnosi', color: Color(0xFFF5D9D0)),
        _StatusPill(label: 'Richiede la tua conferma', color: Color(0xFFD8E8DD)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
