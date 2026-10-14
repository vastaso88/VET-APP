import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../l10n/l10n.dart';

/// Body condition on five levels, shared with the "Corporatura" of the pet
/// profile (very thin, thin, normal, slightly overweight, overweight). The
/// stored value is [score], 1..5.
enum BodyCondition {
  veryThin,
  thin,
  normal,
  slightlyOverweight,
  overweight;

  int get score => index + 1;

  static BodyCondition? fromScore(Object? score) {
    final value = score is num ? score.toInt() : int.tryParse('$score');
    if (value == null || value < 1 || value > BodyCondition.values.length) {
      return null;
    }
    return BodyCondition.values[value - 1];
  }

  String get label => switch (this) {
        BodyCondition.veryThin => appL10n.monitoringBcsVeryThin,
        BodyCondition.thin => appL10n.monitoringBcsThin,
        BodyCondition.normal => appL10n.monitoringBcsNormal,
        BodyCondition.slightlyOverweight =>
          appL10n.monitoringBcsSlightlyOverweight,
        BodyCondition.overweight => appL10n.monitoringBcsOverweight,
      };

  /// Cool tones for too thin, the app's green for normal, warm tones for too
  /// heavy: all taken from the app palette (the thin step sits halfway between
  /// the blue and the green).
  Color get color => switch (this) {
        BodyCondition.veryThin => AppColors.info,
        BodyCondition.thin =>
          Color.lerp(AppColors.info, AppColors.success, 0.5)!,
        BodyCondition.normal => AppColors.success,
        BodyCondition.slightlyOverweight => AppColors.warning,
        BodyCondition.overweight => AppColors.danger,
      };
}
