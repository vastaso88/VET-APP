import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../design_system/tokens/app_colors.dart';
import '../../../../../design_system/tokens/app_radii.dart';
import '../../../../../design_system/tokens/app_spacing.dart';
import '../../../../../design_system/tokens/app_text_styles.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../shared/widgets/min_tap_target.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../../pets/presentation/widgets/pet_avatar.dart';
import '../../../../app/router/app_router.dart';
import '../../../notifications/presentation/notifications_off_banner.dart';
import '../../data/reminders_repository.dart';
import '../../../../shared/widgets/page_header.dart';

class ReminderPageShell extends StatelessWidget {
  const ReminderPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
    this.petName,
    this.showNotificationsBanner = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;
  final bool showNotificationsBanner;

  /// When set (and a matching pet exists), the header shows that pet's own
  /// avatar.
  final String? petName;

  @override
  Widget build(BuildContext context) {
    final pet = petName == null || petName!.isEmpty
        ? null
        : PetDemoStore.instance.byName(petName!);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            PageHeader.top,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                padding: EdgeInsets.zero,
                title: title,
                subtitle: subtitle,
                actions: actions,
                showBack: true,
                badge: pet == null
                    ? null
                    : PetRingAvatar(pet: pet, size: PetRingAvatar.headerSize),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Only on the reminders screens that list or edit them, where a
              // reminder that cannot ring matters.
              if (showNotificationsBanner) const NotificationsOffBanner(),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class ReminderKindChip extends StatelessWidget {
  const ReminderKindChip(
      {super.key, required this.label,
      required this.selected,
      required this.onTap,
      this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return MinTapTarget(
      onTap: onTap,
      child: Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 15,
                    color: selected ? AppColors.onPrimary : AppColors.text),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: selected ? AppColors.onPrimary : AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// Shows a reminder refusal even when the page that caused it has closed.
void showReminderFailure(String message) {
  AppRouter.scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
}

/// Saves and tells whether it worked; on a refusal (no network...) the message
/// is shown and the caller keeps the form open with everything typed.
Future<bool> saveReminderKeepingForm(RemindersRepository repository, ReminderEntry reminder) async {
  try {
    await repository.saveReminder(reminder);
    return true;
  } catch (error) {
    showReminderFailure(
      error is ReminderSyncException ? error.message : appL10n.remindersErrorSaveFailed,
    );
    return false;
  }
}

/// Saves without making the owner wait for the server: the change is already
/// on screen, and a refusal is shown rather than lost.
void saveReminderInBackground(RemindersRepository repository, ReminderEntry reminder) {
  unawaited(repository.saveReminder(reminder).catchError((Object error) {
    showReminderFailure(
      error is ReminderSyncException
          ? error.message
          : appL10n.remindersErrorSaveFailed,
    );
  }));
}
