import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';

class _TutorialSlide {
  const _TutorialSlide({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;
}

List<_TutorialSlide> _slidesFor(AppLocalizations l10n) => [
      _TutorialSlide(
        icon: Icons.pets_rounded,
        title: l10n.firstRunTutorialPetsTitle,
        description: l10n.firstRunTutorialPetsBody,
      ),
      _TutorialSlide(
        icon: Icons.chat_bubble_outline_rounded,
        title: l10n.firstRunTutorialAssistantTitle,
        description: l10n.firstRunTutorialAssistantBody,
      ),
      _TutorialSlide(
        icon: Icons.event_available_outlined,
        title: l10n.firstRunTutorialRemindersTitle,
        description: l10n.firstRunTutorialRemindersBody,
      ),
    ];

/// Short, skippable walkthrough shown once after signup. Pops when the
/// owner is done (Salta or Inizia sull'ultima slide).
class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _slidesFor(context.l10n).length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slidesFor(context.l10n);
    final isLast = _index == slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.commonSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (value) => setState(() => _index = value),
                children: [for (final slide in slides) _SlideView(slide: slide)],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slides.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
                  ),
                  child: Text(isLast ? context.l10n.firstRunTutorialStart : context.l10n.commonNext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _TutorialSlide slide;

  @override
  Widget build(BuildContext context) {
    // Scrolls instead of overflowing on a small phone or a large system text scale.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.xxl),
                ),
                child: Icon(slide.icon, size: 44, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                slide.title,
                style: AppTextStyles.title.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                slide.description,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
