import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../shared/date/calendar_days.dart';
import '../../pets/domain/pet_models.dart';
import '../data/reminders_repository.dart';

PetProfile? petByName(List<PetProfile> pets, String name) {
  for (final pet in pets) {
    if (pet.name == name) return pet;
  }
  return null;
}

/// True when [reminder] should show a calendar marker on [day]: the exact
/// due date for spot/recurring events, or any day within the course's
/// start..start+duration-1 span for courses (so an ongoing treatment shows
/// as a visible band rather than a single day).
bool reminderActiveOnDay(ReminderEntry reminder, DateTime day) {
  if (reminder.kind == EventKind.course) {
    final start = DateTime(reminder.dueAt.year, reminder.dueAt.month, reminder.dueAt.day);
    final end = addCalendarDays(start, (reminder.courseDurationDays ?? 1) - 1);
    return !day.isBefore(start) && !day.isAfter(end);
  }
  return isSameDay(reminder.dueAt, day);
}

enum MarkerShape { dot, pill }

class DayMarker {
  const DayMarker({required this.color, required this.shape, this.initial = ''});
  final Color color;
  final MarkerShape shape;

  /// First letter of the animal's name; empty when the marker has no letter.
  final String initial;
}

/// The animal [reminder] is about: by id, or by name for one just created on
/// this phone (it has no id yet).
PetProfile? petOfReminder(List<PetProfile> pets, ReminderEntry reminder) {
  final id = reminder.petId;
  if (id != null) {
    for (final pet in pets) {
      if (pet.id == id) return pet;
    }
  }
  return petByName(pets, reminder.petName);
}

/// One marker per activity of [day], with the animal's initial: what Home and
/// the reminders calendar count. An activity whose animal is not known here
/// still counts.
List<DayMarker> activityMarkersForDay(
  List<ReminderEntry> reminders,
  List<PetProfile> pets,
  DateTime day,
) {
  return [
    for (final reminder in reminders)
      if (reminderActiveOnDay(reminder, day)) _activityMarker(reminder, petOfReminder(pets, reminder)),
  ];
}

DayMarker _activityMarker(ReminderEntry reminder, PetProfile? pet) {
  final name = (pet?.name ?? reminder.petName).trim();
  return DayMarker(
    color: pet?.identityColor ?? AppColors.secondary,
    shape: reminder.kind == EventKind.course ? MarkerShape.pill : MarkerShape.dot,
    initial: name.isEmpty ? '' : name.characters.first.toUpperCase(),
  );
}

/// The mark of a day: one activity shows the animal's initial in a ring of its
/// colour (round, or longer for a course), more than one how many they are.
/// Never the colour alone: the letter, the number and the shape say it too.
class DayMark extends StatelessWidget {
  const DayMark({super.key, required this.markers, this.size});

  final List<DayMarker> markers;

  /// Height of the mark; by default it grows with the text it holds.
  final double? size;

  /// What a mark takes at the text size in use, within what a calendar column
  /// can take at 320 px.
  static double sizeOf(BuildContext context) =>
      math.min(MediaQuery.textScalerOf(context).scale(12) * 1.9, 34);

  @override
  Widget build(BuildContext context) {
    final height = size ?? sizeOf(context);
    final single = markers.length == 1 ? markers.single : null;
    final initial = single?.initial ?? '';
    final counted = initial.isEmpty;
    final course = single?.shape == MarkerShape.pill && !counted;
    return Container(
      width: course ? height * 1.3 : height,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: course ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: course ? BorderRadius.circular(height * 0.28) : null,
        color: AppColors.secondarySoft,
        border: Border.all(
          color: counted ? AppColors.borderStrong : single!.color,
          width: counted ? 1 : 2,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          counted ? '${markers.length}' : initial,
          maxLines: 1,
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w700,
            color: counted ? AppColors.secondaryStrong : AppColors.text,
          ),
        ),
      ),
    );
  }
}

/// The same mark next to the animal's name (a filter, a legend).
class PetInitialMark extends StatelessWidget {
  const PetInitialMark({super.key, required this.pet});

  final PetProfile pet;

  @override
  Widget build(BuildContext context) {
    final name = pet.name.trim();
    return ExcludeSemantics(
      child: DayMark(
        markers: [
          DayMarker(
            color: pet.identityColor,
            shape: MarkerShape.dot,
            initial: name.isEmpty ? '' : name.characters.first.toUpperCase(),
          ),
        ],
      ),
    );
  }
}
