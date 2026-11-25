import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/date/calendar_days.dart';
import '../../../notifications/application/notification_availability.dart';
import '../../../notifications/domain/notification_plan.dart';
import '../../data/reminders_repository.dart';
import '../../domain/clock_time.dart';
import '../../domain/reminder_postponement.dart';

/// "Quando vuoi che te lo ricordi?": asks for the moment [reminder] is postponed
/// to. Null when closed without choosing; otherwise always after [now].
///
/// When nothing can ring here (notifications not allowed, this kind switched off
/// in Impostazioni, web or iOS) a line says so: the question still comes back in
/// the app.
Future<DateTime?> askPostponeMoment(
  BuildContext context,
  ReminderEntry reminder, {
  DateTime Function() now = DateTime.now,
  Future<bool> Function(ReminderEntry reminder)? alertsCanRing,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
    ),
    builder: (_) => _PostponeSheet(
      now: now,
      alertsCanRing: () => (alertsCanRing ?? _alertsCanRing)(reminder),
    ),
  );
}

Future<bool> _alertsCanRing(ReminderEntry reminder) =>
    NotificationAvailability.instance.canRing(reminderNotificationCategory(reminder));

/// "15:23" today, "gio 26 nov, 09:00" any other day.
String postponeMomentLabel(DateTime at, DateTime now) {
  final time = formatClockTime(at.hour, at.minute);
  if (isSameDay(at, now)) return time;
  return '${formatAppDate(at, 'EEE')} ${formatAppDate(at, 'd MMM')}, $time';
}

class _PostponeSheet extends StatefulWidget {
  const _PostponeSheet({required this.now, required this.alertsCanRing});

  final DateTime Function() now;
  final Future<bool> Function() alertsCanRing;

  @override
  State<_PostponeSheet> createState() => _PostponeSheetState();
}

class _PostponeSheetState extends State<_PostponeSheet> {
  bool _canRing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAlerts();
  }

  Future<void> _checkAlerts() async {
    final canRing = await widget.alertsCanRing();
    if (mounted && !canRing) setState(() => _canRing = false);
  }

  /// Closes with the moment of [choice], counted from the tap: the sheet may have
  /// been open for a while. An evening gone meanwhile is refused, not scheduled
  /// in the past.
  void _choose(PostponeChoice choice) => _close(postponeMoment(choice, widget.now()));

  Future<void> _pick() async {
    final now = widget.now();
    final today = dayOnly(now);
    final day = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: addCalendarDays(today, kPostponeMaxDays),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (day == null || !mounted) return;
    final inAnHour = now.add(const Duration(hours: 1));
    final time = await showTimePicker(
      context: context,
      initialTime: isSameDay(day, inAnHour)
          ? TimeOfDay.fromDateTime(inAnHour)
          : const TimeOfDay(hour: kDefaultNotificationHour, minute: 0),
    );
    if (time == null || !mounted) return;
    _close(DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  void _close(DateTime at) {
    if (!at.isAfter(widget.now())) {
      setState(() => _error = context.l10n.remindersTimePast);
      return;
    }
    Navigator.of(context).pop(at);
  }

  String _label(AppLocalizations l10n, PostponeChoice choice) => switch (choice) {
        PostponeChoice.oneHour => l10n.remindersPostponeOneHour,
        PostponeChoice.evening => l10n.remindersPostponeEvening,
        PostponeChoice.tomorrowMorning => l10n.remindersPostponeTomorrow,
      };

  IconData _icon(PostponeChoice choice) => switch (choice) {
        PostponeChoice.oneHour => Icons.schedule_rounded,
        PostponeChoice.evening => Icons.nights_stay_outlined,
        PostponeChoice.tomorrowMorning => Icons.wb_sunny_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = widget.now();
    final error = _error;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(l10n.remindersPostponeTitle, style: AppTextStyles.heading),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!_canRing)
              _Line(
                icon: Icons.notifications_off_outlined,
                color: AppColors.warning,
                text: l10n.remindersPostponeNoAlerts,
              ),
            if (error != null)
              _Line(icon: Icons.error_outline_rounded, color: AppColors.danger, text: error),
            for (final option in postponeChoices(now))
              _Option(
                icon: _icon(option.choice),
                label: _label(l10n, option.choice),
                when: postponeMomentLabel(option.at, now),
                onTap: () => _choose(option.choice),
              ),
            _Option(
              icon: Icons.calendar_today_outlined,
              label: l10n.remindersPostponePick,
              onTap: _pick,
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.label, required this.onTap, this.when});

  final IconData icon;
  final String label;
  final String? when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final when = this.when;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: AppTextStyles.body.copyWith(color: AppColors.text)),
      subtitle: when == null ? null : Text(when, style: AppTextStyles.bodySmall),
      onTap: onTap,
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text)),
          ),
        ],
      ),
    );
  }
}
