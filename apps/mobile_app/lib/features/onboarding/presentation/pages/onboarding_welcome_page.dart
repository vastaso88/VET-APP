import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../onboarding_routes.dart';

const _kWelcomeContentMaxWidth = 920.0;

class OnboardingWelcomePage extends StatelessWidget {
  const OnboardingWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF5F9F7),
              Color(0xFFE7F2EE),
              Color(0xFFD7EAE2),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding =
                  constraints.maxWidth < 640 ? AppSpacing.lg : AppSpacing.xxl;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AppSpacing.lg,
                  horizontalPadding,
                  AppSpacing.lg,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _kWelcomeContentMaxWidth,
                    ),
                    child: const Column(
                      children: [
                        _TopBar(),
                        SizedBox(height: AppSpacing.xxl),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _HeroCard(),
                                SizedBox(height: AppSpacing.xl),
                                _BottomPanel(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: AppColors.accent),
              SizedBox(width: AppSpacing.sm),
              Text(
                'VET APP',
                style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(OnboardingRoutes.privacyDisclaimer());
          },
          child: const Text('Privacy'),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A163A35),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(),
          SizedBox(height: AppSpacing.xl),
          Text(
            'La salute del tuo pet, con un po di calma.',
            style: AppTextStyles.display,
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Promemoria, documenti clinici e chat guidata in un\'unica app pensata per accompagnarti tra visite, dubbi e routine.',
            style: AppTextStyles.body,
          ),
          SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _PillChip(
                label: 'Chat IA',
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              _PillChip(
                label: 'Documenti',
                backgroundColor: Color(0xFFF6DCCB),
                foregroundColor: Color(0xFF7B4A2E),
              ),
              _PillChip(
                label: 'Reminder',
                backgroundColor: AppColors.accentSoft,
                foregroundColor: Color(0xFF315E55),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xxl),
          _IllustrationPanel(),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: Color(0xFF2D6B60)),
          SizedBox(width: AppSpacing.sm),
          Text(
            'Assistente veterinario quotidiano',
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D6B60),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _IllustrationPanel extends StatelessWidget {
  const _IllustrationPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF3E5),
            Color(0xFFE0F1EA),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: -8,
            top: 34,
            child: _BlurBubble(
              size: 150,
              color: Color(0x66F0BFA0),
            ),
          ),
          const Positioned(
            right: -18,
            top: 10,
            child: _BlurBubble(
              size: 170,
              color: Color(0x6693C3B3),
            ),
          ),
          const Positioned(
            left: 24,
            top: 24,
            child: _MiniCard(
              label: 'Vaccino',
              color: AppColors.accentSoft,
              textColor: Color(0xFF315E55),
            ),
          ),
          const Positioned(
            left: 34,
            bottom: 22,
            child: _MiniCard(
              label: 'Referto PDF',
              color: Color(0xFFFFF5EC),
              textColor: Color(0xFF8B5B3E),
            ),
          ),
          Positioned(
            right: 34,
            top: 22,
            child: Container(
              width: 128,
              height: 168,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33163A35),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 108,
                  height: 148,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const _PetAvatar(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurBubble extends StatelessWidget {
  const _BlurBubble({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _PetAvatar extends StatelessWidget {
  const _PetAvatar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -4,
                top: -10,
                child: Transform.rotate(
                  angle: -0.5,
                  child: const Icon(
                    Icons.change_history,
                    size: 22,
                    color: Color(0xFFD88E68),
                  ),
                ),
              ),
              Positioned(
                right: -4,
                top: -10,
                child: Transform.rotate(
                  angle: 0.5,
                  child: const Icon(
                    Icons.change_history,
                    size: 22,
                    color: Color(0xFFD88E68),
                  ),
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF0B38F),
                ),
              ),
            ],
          ),
          Container(
            width: 62,
            height: 46,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0B38F),
              borderRadius: BorderRadius.circular(23),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inizia con il tuo primo profilo pet',
            style: AppTextStyles.title,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Ti bastano pochi passaggi per salvare dati, documenti e promemoria importanti.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(OnboardingRoutes.valueProposition());
              },
              child: const Text('Scopri di piu'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context)
                    .pushReplacement(OnboardingRoutes.authHub());
              },
              child: const Text('Ho gia un account'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Continuando accetti privacy, disclaimer medico e utilizzo responsabile dei suggerimenti IA.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
