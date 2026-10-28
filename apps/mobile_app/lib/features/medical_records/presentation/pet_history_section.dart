import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_text_styles.dart';
import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/date/calendar_days.dart';
import '../domain/history_event.dart';
import 'history_labels.dart';

/// "Storico": a month calendar with every event of the pet (entries of the
/// cartella clinica on the day they happened, illnesses on the day they
/// started), drawn with the category symbols of the page. Tapping a day lists
/// that day's events; tapping one opens it. Not for reminders.
class PetHistorySection extends StatefulWidget {
  const PetHistorySection({
    required this.events,
    required this.onOpenEvent,
    this.onExport,
    this.now,
    super.key,
  });

  final List<HistoryEvent> events;
  final ValueChanged<HistoryEvent> onOpenEvent;

  /// "Invia storico": null hides the button.
  final VoidCallback? onExport;

  /// The current time; only tests set it.
  final DateTime Function()? now;

  @override
  State<PetHistorySection> createState() => _PetHistorySectionState();
}

class _PetHistorySectionState extends State<PetHistorySection> {
  late DateTime _month = _firstOfMonth(_today);
  DateTime? _selected;

  DateTime get _today => dayOnly(widget.now?.call() ?? DateTime.now());

  static DateTime _firstOfMonth(DateTime date) =>
      DateTime(date.year, date.month);

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final byDay = groupEventsByDay(widget.events);
    final cells = monthGridCells(_month);
    final weekdays = appShortWeekdaysMondayFirst();
    final selected = _selected;
    final monthLabel = formatAppDate(_month, 'LLLL y');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child:
                      Text(l10n.medHistoryTitle, style: AppTextStyles.title)),
              if (widget.onExport != null)
                TextButton.icon(
                  onPressed: widget.onExport,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(l10n.medHistorySend),
                ),
            ],
          ),
          Text(l10n.medHistorySubtitle, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              IconButton(
                tooltip: l10n.medHistoryPrevMonth,
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.secondaryStrong,
              ),
              Expanded(
                child: Text(
                  _capitalized(monthLabel),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.medHistoryNextMonth,
                onPressed: () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.secondaryStrong,
              ),
            ],
          ),
          Row(
            children: [
              for (final name in weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: AppTextStyles.caption,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var start = 0; start < cells.length; start += 7)
            Row(
              children: [
                for (final day in cells.sublist(start, start + 7))
                  Expanded(
                    child: day == null
                        ? const SizedBox(height: _cellHeight)
                        : _DayCell(
                            day: day,
                            events: byDay[day] ?? const [],
                            isToday: day == _today,
                            isSelected: day == selected,
                            onTap: () => setState(() => _selected = day),
                          ),
                  ),
              ],
            ),
          if (widget.events.isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.medHistoryEmpty, style: AppTextStyles.bodySmall),
          ],
          if (selected != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.medHistoryDayTitle(formatAppDate(selected, 'd MMM y')),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if ((byDay[selected] ?? const []).isEmpty)
              Text(l10n.medHistoryDayEmpty, style: AppTextStyles.caption)
            else
              for (final event in byDay[selected]!) ...[
                _EventTile(
                    event: event, onTap: () => widget.onOpenEvent(event)),
                const SizedBox(height: AppSpacing.xs),
              ],
          ],
        ],
      ),
    );
  }
}

String _capitalized(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

const _cellHeight = 48.0;

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.events,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final List<HistoryEvent> events;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // At most three symbols fit: the distinct kinds of the day, the rest as "+n".
    final symbols = <IconData>[];
    for (final event in events) {
      if (!symbols.contains(event.icon)) symbols.add(event.icon);
    }
    final shown = symbols.length > 3 ? symbols.take(2).toList() : symbols;
    final extra = symbols.length - shown.length;

    return Semantics(
      button: true,
      selected: isSelected,
      label:
          l10n.medHistoryDayA11y(formatAppDate(day, 'd MMM y'), events.length),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        onTap: onTap,
        child: Container(
          height: _cellHeight,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondarySoft : null,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            border: isSelected || isToday
                ? Border.all(
                    color: AppColors.primary, width: isSelected ? 1.5 : 1)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${day.day}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.text,
                    fontWeight: isToday || events.isNotEmpty
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(
                height: 13,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final icon in shown)
                        Icon(icon, size: 11, color: AppColors.secondaryStrong),
                      if (extra > 0)
                        Text(
                          '+$extra',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 9,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onTap});

  final HistoryEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = [
      event.categoryLabel(l10n),
      if (event.subtypeLabel(l10n) != null) event.subtypeLabel(l10n)!,
    ].join(' · ');
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.secondarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(event.icon, size: 17, color: AppColors.secondaryStrong),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}
