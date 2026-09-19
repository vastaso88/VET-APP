import 'package:flutter/material.dart';

import '../../../../design_system/responsive.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../pets/domain/pet_models.dart';
import '../data/reminders_repository.dart';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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
    final end = start.add(Duration(days: (reminder.courseDurationDays ?? 1) - 1));
    return !day.isBefore(start) && !day.isAfter(end);
  }
  return isSameDay(reminder.dueAt, day);
}

enum MarkerShape { dot, pill }

class DayMarker {
  const DayMarker({required this.color, required this.shape});
  final Color color;
  final MarkerShape shape;
}

/// Distinct per-pet markers for [day]: a dot for spot/recurring reminders
/// due that day, a pill for courses active that day (one marker per pet
/// per shape, even if the pet has several matching reminders).
List<DayMarker> markersForDay(
  List<ReminderEntry> reminders,
  List<PetProfile> pets,
  DateTime day,
) {
  final markers = <DayMarker>[];
  final seenDots = <String>{};
  final seenPills = <String>{};
  for (final reminder in reminders) {
    if (!reminderActiveOnDay(reminder, day)) continue;
    final pet = petByName(pets, reminder.petName);
    if (pet == null) continue;

    final isCourse = reminder.kind == EventKind.course;
    final seen = isCourse ? seenPills : seenDots;
    if (!seen.add(pet.id)) continue;

    markers.add(DayMarker(
      color: pet.identityColor,
      shape: isCourse ? MarkerShape.pill : MarkerShape.dot,
    ));
  }
  return markers;
}

/// A small colored marker: a plain dot for spot/recurring reminders, or a
/// pill-shaped icon (standing in for a "medicine pill" emoji, which can't
/// be recolored) for an active course — both filled with the pet's
/// identity color so they read consistently with its avatar badge.
class MarkerGlyph extends StatelessWidget {
  const MarkerGlyph({super.key, required this.marker, this.size = 9});

  final DayMarker marker;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scaledSize = size * appScaleOf(context);

    if (marker.shape == MarkerShape.dot) {
      return Container(
        width: scaledSize,
        height: scaledSize,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: marker.color,
          border: Border.all(color: AppColors.surfaceElevated, width: 1),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Icon(Icons.medication_rounded, size: scaledSize * 1.3, color: marker.color),
    );
  }
}
