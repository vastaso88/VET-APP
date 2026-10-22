import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_text_styles.dart';
import '../../../l10n/l10n.dart';
import '../application/notification_availability.dart';

/// "Le notifiche sono disattivate: i promemoria non suoneranno" with an
/// "Attiva" button, shown above the reminders while the phone does not let them
/// ring. It looks again whenever it appears and whenever the app comes back to
/// the foreground (e.g. from the system settings), and disappears by itself as
/// soon as notifications are allowed. Nothing is drawn on web and iOS.
class NotificationsOffBanner extends StatefulWidget {
  const NotificationsOffBanner({this.availability, super.key});

  /// Overridable for tests.
  final NotificationAvailability? availability;

  @override
  State<NotificationsOffBanner> createState() => _NotificationsOffBannerState();
}

class _NotificationsOffBannerState extends State<NotificationsOffBanner> {
  late final NotificationAvailability _availability =
      widget.availability ?? NotificationAvailability.instance;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _availability.refresh();
    _lifecycle = AppLifecycleListener(onResume: _availability.refresh);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _availability.disabled,
      builder: (context, disabled, _) {
        if (!disabled) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.large),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_off_outlined, size: 20, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.l10n.remindersNotifOffBanner,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _availability.activate,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  ),
                  child: Text(context.l10n.remindersNotifOffAction),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
