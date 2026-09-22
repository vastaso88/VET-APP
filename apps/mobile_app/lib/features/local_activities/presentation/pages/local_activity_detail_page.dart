import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../../location/presentation/distance_label.dart';
import '../../domain/local_activity.dart';
import '../local_activity_labels.dart';

class LocalActivityDetailPage extends StatelessWidget {
  const LocalActivityDetailPage({super.key, required this.activity, this.distanceMeters});

  final LocalActivity activity;
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    final dateLabel = localActivityDateRangeLabel(activity);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(activity.title, style: AppTextStyles.title, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                DashboardBadge(
                  label: localActivityKindLabel(activity.kind),
                  tone: activity.kind == LocalActivityKind.event
                      ? DashboardTone.info
                      : DashboardTone.success,
                ),
                if (activity.category != null)
                  DashboardBadge(label: activity.category!, tone: DashboardTone.neutral),
                if (distanceMeters != null)
                  DashboardBadge(
                    label: formatDistance(distanceMeters!),
                    icon: Icons.location_on_outlined,
                    tone: DashboardTone.primary,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (dateLabel != null) ...[
              Text(dateLabel, style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (activity.addressLabel != null)
              Text(activity.addressLabel!, style: AppTextStyles.bodySmall),
            if (activity.description != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(activity.description!, style: AppTextStyles.body),
            ],
          ],
        ),
      ),
    );
  }
}
