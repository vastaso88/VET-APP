import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../location/domain/coordinates.dart';
import '../../../settings/data/unit_settings_store.dart';
import '../../../settings/domain/unit_conversion.dart';
import '../widgets/radar_map.dart';
import '../../../../l10n/l10n.dart';

/// Full-screen version of the radar map preview: same markers, pan and
/// zoom enabled, legend pinned at the bottom.
class RadarMapPage extends StatelessWidget {
  const RadarMapPage({
    super.key,
    required this.center,
    required this.radiusKm,
    required this.items,
  });

  final Coordinates center;
  final double radiusKm;
  final List<RadarMapItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(
          context.l10n.placesMapTitle(
            formatKilometersIn(radiusKm, UnitSettingsStore.instance.system),
          ),
          style: AppTextStyles.title,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: RadarMap(center: center, radiusKm: radiusKm, items: items)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: RadarLegend(categories: items.map((item) => item.category).toSet()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
