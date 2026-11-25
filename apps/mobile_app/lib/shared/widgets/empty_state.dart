import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_text_styles.dart';
import 'app_card.dart';
import 'quokka_logo.dart';

/// The one empty state of the app: in a card, a figure, a title or a sentence and
/// at most one command, all centred. The figure is the light Quokka; the species (or the face)
/// of the animal where the page is about one; a plain icon next to an error,
/// health, or Ricordi, where the mascot never goes.
class EmptyState extends StatelessWidget {
  /// Nothing to show yet, and it is not about one animal.
  const EmptyState({super.key, this.title, this.text, this.action, this.padding = defaultPadding})
      : figure = const QuokkaHeadRound(size: figureSize),
        assert(title != null || text != null);

  /// Nothing to show about one animal (or one kind): its own figure.
  const EmptyState.figure({
    super.key,
    required this.figure,
    this.title,
    this.text,
    this.action,
    this.padding = defaultPadding,
  }) : assert(title != null || text != null);

  /// An error, health, a closed page: an icon, no mascot.
  EmptyState.icon({
    super.key,
    required IconData icon,
    this.title,
    this.text,
    this.action,
    this.padding = defaultPadding,
  })  : figure = StateIcon(icon),
        assert(title != null || text != null);

  static const figureSize = 72.0;

  static const defaultPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.page,
    vertical: AppSpacing.xl,
  );

  /// Where the page already keeps the margin from the edge.
  static const insidePage = EdgeInsets.symmetric(vertical: AppSpacing.lg);

  final Widget figure;
  final String? title;
  final String? text;

  /// One command (a FilledButton when it is the thing to do, an OutlinedButton for
  /// "Riprova").
  final Widget? action;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AppCard(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(child: figure),
                if (title != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(title!, textAlign: TextAlign.center, style: AppTextStyles.title),
                ],
                if (text != null) ...[
                  SizedBox(height: title == null ? AppSpacing.lg : AppSpacing.sm),
                  Text(text!, textAlign: TextAlign.center, style: AppTextStyles.body),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An [EmptyState] (or another block) in the middle of the page when there is
/// room, scrolling when there is not (large text, small phone).
class CenteredPageState extends StatelessWidget {
  const CenteredPageState({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(child: SingleChildScrollView(primary: false, child: child));
  }
}

/// A flat icon in the soft circle where a figure would be.
class StateIcon extends StatelessWidget {
  const StateIcon(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: EmptyState.figureSize,
      height: EmptyState.figureSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.secondarySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 32, color: AppColors.secondaryStrong),
    );
  }
}
