import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../l10n/l10n.dart';

/// THE definition of the pet's body condition ("corporatura"), five levels.
/// Used by the pet profile (stored as [code], `pet_profiles.body_condition`)
/// and by the weighings (stored as [score], 1..5,
/// `pet_weight_measurements.body_condition`). Backend mirror:
/// `packages/core/domain/pet_profile/body_condition.py`; labels are the
/// `monitoringBcs*` strings, nowhere else.
enum BodyCondition {
  veryThin('very_thin'),
  thin('thin'),
  normal('normal'),
  slightlyOverweight('slightly_overweight'),
  overweight('overweight');

  const BodyCondition(this.code);

  /// Language-independent code stored in the pet profile.
  final String code;

  /// Level stored in a weighing, 1 (very thin) to 5 (overweight).
  int get score => index + 1;

  /// The codes thinnest to heaviest (the profile dropdown order).
  static List<String> get codes => [for (final c in values) c.code];

  static BodyCondition? fromScore(Object? score) {
    final value = score is num ? score.toInt() : int.tryParse('$score');
    if (value == null || value < 1 || value > BodyCondition.values.length) {
      return null;
    }
    return BodyCondition.values[value - 1];
  }

  static BodyCondition? fromCode(String? code) {
    for (final condition in values) {
      if (condition.code == code) return condition;
    }
    return null;
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
