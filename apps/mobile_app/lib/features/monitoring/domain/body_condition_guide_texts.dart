import '../../../l10n/l10n.dart';
import 'body_condition.dart';
import 'body_condition_guide.dart';

/// What the guide says for one level of one species: what to feel, what to see
/// from above and from the side. Written for owners, in our own words from the
/// sources named by [bodyConditionGuideSource] (see
/// docs/monitoring/corporatura_fonti.md); the original charts are not copied.
class BodyConditionLevelText {
  const BodyConditionLevelText({
    required this.touch,
    required this.above,
    required this.side,
    required this.scaleRange,
    required this.scaleMax,
  });

  final String touch;
  final String above;
  final String side;

  /// The points of the source scale this level stands for ("4–5").
  final String scaleRange;

  /// The top of the source scale ("9", or "5" for the rabbit).
  final String scaleMax;
}

BodyConditionLevelText bodyConditionGuideTexts(
    BodyConditionGuideKind kind, BodyCondition condition) {
  final l10n = appL10n;
  return switch (kind) {
    BodyConditionGuideKind.dog => switch (condition) {
        BodyCondition.veryThin => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideDog1Touch,
            above: l10n.monitoringBcsGuideDog1Above,
            side: l10n.monitoringBcsGuideDog1Side,
            scaleRange: '1–2',
            scaleMax: '9',
          ),
        BodyCondition.thin => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideDog2Touch,
            above: l10n.monitoringBcsGuideDog2Above,
            side: l10n.monitoringBcsGuideDog2Side,
            scaleRange: '3',
            scaleMax: '9',
          ),
        BodyCondition.normal => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideDog3Touch,
            above: l10n.monitoringBcsGuideDog3Above,
            side: l10n.monitoringBcsGuideDog3Side,
            scaleRange: '4–5',
            scaleMax: '9',
          ),
        BodyCondition.slightlyOverweight => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideDog4Touch,
            above: l10n.monitoringBcsGuideDog4Above,
            side: l10n.monitoringBcsGuideDog4Side,
            scaleRange: '6–7',
            scaleMax: '9',
          ),
        BodyCondition.overweight => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideDog5Touch,
            above: l10n.monitoringBcsGuideDog5Above,
            side: l10n.monitoringBcsGuideDog5Side,
            scaleRange: '8–9',
            scaleMax: '9',
          ),
      },
    BodyConditionGuideKind.cat => switch (condition) {
        BodyCondition.veryThin => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideCat1Touch,
            above: l10n.monitoringBcsGuideCat1Above,
            side: l10n.monitoringBcsGuideCat1Side,
            scaleRange: '1–2',
            scaleMax: '9',
          ),
        BodyCondition.thin => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideCat2Touch,
            above: l10n.monitoringBcsGuideCat2Above,
            side: l10n.monitoringBcsGuideCat2Side,
            scaleRange: '3–4',
            scaleMax: '9',
          ),
        BodyCondition.normal => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideCat3Touch,
            above: l10n.monitoringBcsGuideCat3Above,
            side: l10n.monitoringBcsGuideCat3Side,
            scaleRange: '5',
            scaleMax: '9',
          ),
        BodyCondition.slightlyOverweight => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideCat4Touch,
            above: l10n.monitoringBcsGuideCat4Above,
            side: l10n.monitoringBcsGuideCat4Side,
            scaleRange: '6–7',
            scaleMax: '9',
          ),
        BodyCondition.overweight => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideCat5Touch,
            above: l10n.monitoringBcsGuideCat5Above,
            side: l10n.monitoringBcsGuideCat5Side,
            scaleRange: '8–9',
            scaleMax: '9',
          ),
      },
    BodyConditionGuideKind.rabbit => switch (condition) {
        BodyCondition.veryThin => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideRabbit1Touch,
            above: l10n.monitoringBcsGuideRabbit1Above,
            side: l10n.monitoringBcsGuideRabbit1Side,
            scaleRange: '1',
            scaleMax: '5',
          ),
        BodyCondition.thin => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideRabbit2Touch,
            above: l10n.monitoringBcsGuideRabbit2Above,
            side: l10n.monitoringBcsGuideRabbit2Side,
            scaleRange: '2',
            scaleMax: '5',
          ),
        BodyCondition.normal => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideRabbit3Touch,
            above: l10n.monitoringBcsGuideRabbit3Above,
            side: l10n.monitoringBcsGuideRabbit3Side,
            scaleRange: '3',
            scaleMax: '5',
          ),
        BodyCondition.slightlyOverweight => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideRabbit4Touch,
            above: l10n.monitoringBcsGuideRabbit4Above,
            side: l10n.monitoringBcsGuideRabbit4Side,
            scaleRange: '4',
            scaleMax: '5',
          ),
        BodyCondition.overweight => BodyConditionLevelText(
            touch: l10n.monitoringBcsGuideRabbit5Touch,
            above: l10n.monitoringBcsGuideRabbit5Above,
            side: l10n.monitoringBcsGuideRabbit5Side,
            scaleRange: '5',
            scaleMax: '5',
          ),
      },
  };
}

/// The reference line shown at the bottom of the popup.
String bodyConditionGuideSource(BodyConditionGuideKind kind) => switch (kind) {
      BodyConditionGuideKind.dog => appL10n.monitoringBcsSourceDog,
      BodyConditionGuideKind.cat => appL10n.monitoringBcsSourceCat,
      BodyConditionGuideKind.rabbit => appL10n.monitoringBcsSourceRabbit,
    };

/// A hint about not trusting the eyes alone.
String bodyConditionGuideTip(BodyConditionGuideKind kind) => switch (kind) {
      BodyConditionGuideKind.rabbit => appL10n.monitoringBcsGuideTipRabbit,
      _ => appL10n.monitoringBcsGuideTipFurry,
    };

/// A warning about the reliability of the scale itself, when it has one.
String? bodyConditionGuideCaveat(BodyConditionGuideKind kind) =>
    kind == BodyConditionGuideKind.rabbit
        ? appL10n.monitoringBcsGuideCaveatRabbit
        : null;
