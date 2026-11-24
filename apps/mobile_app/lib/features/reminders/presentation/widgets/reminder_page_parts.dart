import '../../../../shared/widgets/pet_loader.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../design_system/tokens/app_colors.dart';
import '../../../../../design_system/tokens/app_radii.dart';
import '../../../../../design_system/tokens/app_spacing.dart';
import '../../../../../design_system/tokens/app_text_styles.dart';
import '../../../../../l10n/l10n.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../../pets/presentation/widgets/pet_avatar.dart';
import '../../../../app/router/app_router.dart';
import '../../../notifications/presentation/notifications_off_banner.dart';
import '../../data/reminders_repository.dart';

class ReminderPageShell extends StatelessWidget {
  const ReminderPageShell({super.key, 
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.petName,
    this.showNotificationsBanner = false,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;
  final bool showNotificationsBanner;

  /// When set (and a matching pet exists), the header shows that pet's own
  /// avatar in place of the generic "VET APP" brand pill.
  final String? petName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  title: title,
                  subtitle: subtitle,
                  actionLabel: actionLabel,
                  onAction: onAction,
                  petName: petName,
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.petName,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? petName;

  @override
  Widget build(BuildContext context) {
    final pet = petName == null || petName!.isEmpty
        ? null
        : PetDemoStore.instance.byName(petName!);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: context.l10n.commonBack,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.onPrimary,
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryStrong),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (pet != null)
                    PetAvatar(
                      label: pet.avatarEmoji,
                      backgroundColor: pet.accentColor,
                      identityColor: pet.identityColor,
                      photoBytes: pet.photoBytes,
                      photoPath: pet.photoPath,
                      size: 36,
                    )
                  else
                    const Flexible(child: _BrandPill()),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle, style: AppTextStyles.body),
            ],
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: AppSpacing.md),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: Size.zero),
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_active_outlined,
              size: 14, color: AppColors.secondaryStrong),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              context.l10n.appTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class ReminderStatePanel extends StatelessWidget {
  const ReminderStatePanel({super.key, 
    required this.label,
    required this.title,
    required this.body,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  final String label;
  final String title;
  final String body;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _Card(
      label: label,
      title: title,
      body: body,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class ReminderLoadingPanel extends StatelessWidget {
  const ReminderLoadingPanel({super.key, 
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _Card(
      label: context.l10n.remindersLoadingLabel,
      title: title,
      body: body,
      icon: Icons.hourglass_empty_outlined,
      actionLabel: context.l10n.remindersWait,
      onAction: null,
      loading: true,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.label,
    required this.title,
    required this.body,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    this.loading = false,
  });

  final String label;
  final String title;
  final String body;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AccentPill(label: label),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 28, color: AppColors.secondaryStrong),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          if (loading) ...[
            // The spinning animal, like everywhere else something loads.
            const Center(child: PetLoader()),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccentPill extends StatelessWidget {
  const _AccentPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.secondaryStrong,
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
    return Material(
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
                color: selected ? AppColors.primary : AppColors.border),
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
