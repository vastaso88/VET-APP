import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/body_condition.dart';
import '../../domain/body_condition_guide.dart';
import '../../domain/body_condition_guide_texts.dart';
import 'body_condition_bar.dart';
import 'body_condition_illustration.dart';

/// What the owner decided in the guide: a level, or "remove the assessment".
/// The dialog returns null when it is simply dismissed.
class BodyConditionChoice {
  const BodyConditionChoice(this.condition);

  final BodyCondition? condition;
}

/// Opens the "Valuta la corporatura" popup: how to look at and touch THIS
/// species, an illustration of each level and, at the end, the choice of the
/// level. The body condition is never picked from a bare list.
Future<BodyConditionChoice?> showBodyConditionGuide(
  BuildContext context, {
  required BodyConditionGuideKind kind,
  required String petName,
  BodyCondition? current,
}) {
  return showDialog<BodyConditionChoice>(
    context: context,
    builder: (_) => BodyConditionGuideDialog(
      kind: kind,
      petName: petName,
      current: current,
    ),
  );
}

class BodyConditionGuideDialog extends StatefulWidget {
  const BodyConditionGuideDialog({
    required this.kind,
    required this.petName,
    this.current,
    super.key,
  });

  final BodyConditionGuideKind kind;
  final String petName;
  final BodyCondition? current;

  @override
  State<BodyConditionGuideDialog> createState() =>
      _BodyConditionGuideDialogState();
}

class _BodyConditionGuideDialogState extends State<BodyConditionGuideDialog> {
  late BodyCondition _viewing = widget.current ?? BodyCondition.normal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final texts = bodyConditionGuideTexts(widget.kind, _viewing);
    final caveat = bodyConditionGuideCaveat(widget.kind);
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xl),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: ConstrainedBox(
        key: const ValueKey('bcs-guide'),
        constraints: BoxConstraints(maxWidth: 540, maxHeight: size.height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.sm, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.monitoringBcsGuideTitle,
                      style: AppTextStyles.title,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('bcs-guide-close'),
                    tooltip: l10n.commonClose,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.monitoringBcsGuideIntro(widget.petName),
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _Steps(),
                    const SizedBox(height: AppSpacing.lg),
                    _InfographicCard(
                      kind: widget.kind,
                      condition: _viewing,
                      onSelected: (condition) =>
                          setState(() => _viewing = condition),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _LevelDescription(condition: _viewing, text: texts),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      bodyConditionGuideTip(widget.kind),
                      key: const ValueKey('bcs-guide-tip'),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (caveat != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        caveat,
                        key: const ValueKey('bcs-guide-caveat'),
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.monitoringBcsGuideAdviceTitle,
                      key: const ValueKey('bcs-guide-advice-title'),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    for (final advice in [
                      l10n.monitoringBcsGuideAdvice1(widget.petName),
                      l10n.monitoringBcsGuideAdvice2,
                      l10n.monitoringBcsGuideAdvice3,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: AppTextStyles.bodySmall),
                            Expanded(
                              child: Text(advice, style: AppTextStyles.bodySmall),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.monitoringBcsGuideDisclaimer,
                      style: AppTextStyles.caption
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.monitoringBcsGuideSource(
                          bodyConditionGuideSource(widget.kind)),
                      key: const ValueKey('bcs-guide-source'),
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('bcs-guide-confirm'),
                      onPressed: () => Navigator.of(context)
                          .pop(BodyConditionChoice(_viewing)),
                      child: Text(
                        l10n.monitoringBcsGuideChoose(_viewing.label),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  if (widget.current != null)
                    TextButton(
                      key: const ValueKey('bcs-guide-clear'),
                      onPressed: () => Navigator.of(context)
                          .pop(const BodyConditionChoice(null)),
                      child: Text(l10n.monitoringBcsGuideClear),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three things to do with the animal, in order: touch, look from above,
/// look from the side.
class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget step(int number, IconData icon, String label) => Expanded(
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(icon, color: AppColors.secondaryStrong, size: 22),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$number. $label',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

    return Row(
      key: const ValueKey('bcs-guide-steps'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        step(1, Icons.back_hand_outlined, l10n.monitoringBcsStepTouch),
        step(2, Icons.arrow_downward_rounded, l10n.monitoringBcsStepAbove),
        step(3, Icons.arrow_forward_rounded, l10n.monitoringBcsStepSide),
      ],
    );
  }
}

/// The two drawings of the level being looked at and, under them, the five
/// levels to move between.
class _InfographicCard extends StatelessWidget {
  const _InfographicCard({
    required this.kind,
    required this.condition,
    required this.onSelected,
  });

  final BodyConditionGuideKind kind;
  final BodyCondition condition;
  final ValueChanged<BodyCondition> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(l10n.monitoringBcsViewAbove,
                    textAlign: TextAlign.center, style: AppTextStyles.caption),
              ),
              Expanded(
                flex: 7,
                child: Text(l10n.monitoringBcsViewSide,
                    textAlign: TextAlign.center, style: AppTextStyles.caption),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          BodyConditionIllustration(kind: kind, condition: condition),
          const SizedBox(height: AppSpacing.md),
          BodyConditionBar(selected: condition, onSelected: onSelected),
        ],
      ),
    );
  }
}

class _LevelDescription extends StatelessWidget {
  const _LevelDescription({required this.condition, required this.text});

  final BodyCondition condition;
  final BodyConditionLevelText text;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.secondaryStrong),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$label: ',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: value),
                    ],
                  ),
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
        );

    return Container(
      key: const ValueKey('bcs-guide-description'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: condition.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: condition.color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${condition.score}/5 · ${condition.label}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            l10n.monitoringBcsGuideScale(text.scaleRange, text.scaleMax),
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500),
          ),
          row(Icons.back_hand_outlined, l10n.monitoringBcsRowTouch, text.touch),
          row(Icons.arrow_downward_rounded, l10n.monitoringBcsRowAbove,
              text.above),
          row(Icons.arrow_forward_rounded, l10n.monitoringBcsRowSide, text.side),
        ],
      ),
    );
  }
}
