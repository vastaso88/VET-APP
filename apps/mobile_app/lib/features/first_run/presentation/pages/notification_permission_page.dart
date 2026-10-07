import 'package:flutter/material.dart';

import '../../../../shared/widgets/pet_loader.dart';

import 'package:permission_handler/permission_handler.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../notifications/application/notification_scheduler.dart';

/// Asks for the OS notification permission right after the tutorial — the
/// natural moment, since the tutorial just explained reminders/vaccine
/// alerts. Optional: "Non ora" pops without requesting anything, so a
/// denial (or an unsupported platform) never blocks the first-run flow.
class NotificationPermissionPage extends StatefulWidget {
  const NotificationPermissionPage({super.key});

  @override
  State<NotificationPermissionPage> createState() => _NotificationPermissionPageState();
}

class _NotificationPermissionPageState extends State<NotificationPermissionPage> {
  bool _requesting = false;

  Future<void> _requestPermission() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      await Permission.notification.request();
    } catch (_) {
      // Some platforms/targets don't support a native prompt at all — the
      // toggle in Impostazioni still reflects whatever the OS allows.
    }
    NotificationScheduler.instance.requestResync();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.xxl),
                ),
                child: const Icon(Icons.notifications_active_outlined, size: 44, color: AppColors.info),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Non perderti i promemoria',
                style: AppTextStyles.title.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Attiva le notifiche per essere avvisato su vaccini, farmaci e visite in scadenza. '
                'Puoi cambiare idea in qualsiasi momento da Impostazioni.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _requesting ? null : _requestPermission,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
                  ),
                  child: _requesting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: PetLoader.small(),
                        )
                      : const Text('Attiva notifiche'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Non ora'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
