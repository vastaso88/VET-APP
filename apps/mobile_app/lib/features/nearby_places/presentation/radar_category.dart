import 'package:flutter/material.dart';

import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../../local_activities/domain/local_activity.dart';
import '../domain/radar_place.dart';

/// The single category vocabulary of the radar page: every list row, map
/// marker, quick filter and legend entry reads its label, icon and color
/// from here, so a category always looks the same wherever it appears.
enum RadarCategory {
  veterinary(Icons.local_hospital, Color(0xFFB3261E)),
  shop(Icons.storefront, Color(0xFF8A5A00)),
  dogPark(Icons.park, Color(0xFF2E7D32)),
  shelter(Icons.cottage, Color(0xFF3949AB)),
  grooming(Icons.content_cut, Color(0xFF7B4FA3)),
  hotel(Icons.night_shelter, Color(0xFF1F6FA5)),
  school(Icons.school, Color(0xFF00796B)),
  petSitting(Icons.volunteer_activism, Color(0xFFAD1457)),
  breeder(Icons.pets, Color(0xFF6D4C41)),
  other(Icons.place, Color(0xFF546E7A));

  const RadarCategory(this.icon, this.color);

  final IconData icon;

  /// Dark enough for a white icon on top (map markers) and for the icon
  /// itself on the app's light surfaces.
  final Color color;

  /// Plural label, used for filters and the legend.
  String get label {
    final l10n = appL10n;
    switch (this) {
      case RadarCategory.veterinary:
        return l10n.placesCategoryVeterinary;
      case RadarCategory.shop:
        return l10n.placesCategoryShop;
      case RadarCategory.dogPark:
        return l10n.placesCategoryDogPark;
      case RadarCategory.shelter:
        return l10n.placesCategoryShelter;
      case RadarCategory.grooming:
        return l10n.placesCategoryGrooming;
      case RadarCategory.hotel:
        return l10n.placesCategoryHotel;
      case RadarCategory.school:
        return l10n.placesCategorySchool;
      case RadarCategory.petSitting:
        return l10n.placesCategoryPetSitting;
      case RadarCategory.breeder:
        return l10n.placesCategoryBreeder;
      case RadarCategory.other:
        return l10n.placesCategoryOther;
    }
  }
}

RadarCategory radarCategoryForPlace(RadarPlaceType type) {
  switch (type) {
    case RadarPlaceType.veterinary:
      return RadarCategory.veterinary;
    case RadarPlaceType.grooming:
      return RadarCategory.grooming;
    case RadarPlaceType.shop:
      return RadarCategory.shop;
    case RadarPlaceType.school:
      return RadarCategory.school;
    case RadarPlaceType.petSitting:
      return RadarCategory.petSitting;
    case RadarPlaceType.breeder:
      return RadarCategory.breeder;
    case RadarPlaceType.hotel:
      return RadarCategory.hotel;
    case RadarPlaceType.dogPark:
      return RadarCategory.dogPark;
    case RadarPlaceType.shelter:
      return RadarCategory.shelter;
    case RadarPlaceType.other:
      return RadarCategory.other;
  }
}

/// A standing service a user submitted, sorted into the clinic category
/// when its free-text category says so. (Dated activities are events and
/// are not part of this page.)
RadarCategory radarCategoryForActivity(LocalActivity activity) {
  final category = activity.category?.toLowerCase() ?? '';
  const clinicHints = ['ambulator', 'veterin', 'clinic'];
  return clinicHints.any(category.contains) ? RadarCategory.veterinary : RadarCategory.other;
}

/// Singular label for one place ("Veterinario", not "Veterinari").
String radarPlaceTypeLabel(RadarPlaceType type) {
  final l10n = appL10n;
  switch (type) {
    case RadarPlaceType.veterinary:
      return l10n.placesTypeVeterinary;
    case RadarPlaceType.grooming:
      return l10n.placesTypeGrooming;
    case RadarPlaceType.shop:
      return l10n.placesTypeShop;
    case RadarPlaceType.school:
      return l10n.placesTypeSchool;
    case RadarPlaceType.petSitting:
      return l10n.placesTypePetSitting;
    case RadarPlaceType.breeder:
      return l10n.placesTypeBreeder;
    case RadarPlaceType.hotel:
      return l10n.placesTypeHotel;
    case RadarPlaceType.dogPark:
      return l10n.placesTypeDogPark;
    case RadarPlaceType.shelter:
      return l10n.placesTypeShelter;
    case RadarPlaceType.other:
      return l10n.placesTypeOther;
  }
}

/// Turns OpenStreetMap's `opening_hours` shorthand into readable text in
/// the app language without interpreting it: day and keyword abbreviations
/// only.
String formatOpeningHours(String raw) {
  final l10n = appL10n;
  if (raw.trim() == '24/7') {
    return l10n.placesHours247;
  }
  final weekdays = appShortWeekdaysMondayFirst()
      .map((day) => day.isEmpty ? day : '${day[0].toUpperCase()}${day.substring(1)}')
      .toList();
  final words = {
    'Mo': weekdays[0],
    'Tu': weekdays[1],
    'We': weekdays[2],
    'Th': weekdays[3],
    'Fr': weekdays[4],
    'Sa': weekdays[5],
    'Su': weekdays[6],
    'PH': l10n.placesHoursHolidays,
    'off': l10n.placesHoursClosed,
    'closed': l10n.placesHoursClosed,
  };
  return raw.replaceAllMapped(
    RegExp(r'\b(Mo|Tu|We|Th|Fr|Sa|Su|PH|off|closed)\b'),
    (match) => words[match.group(1)]!,
  );
}

/// Colored disc with the category icon: the leading of list rows. A
/// [pending] place (a user report nobody confirmed yet) is drawn hollow
/// with a question mark, so it is never mistaken for an established one.
class RadarCategoryBadge extends StatelessWidget {
  const RadarCategoryBadge(
      {super.key, required this.category, this.size = 40, this.pending = false});

  final RadarCategory category;
  final double size;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pending ? Colors.transparent : category.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.4),
        border: pending ? Border.all(color: category.color.withValues(alpha: 0.6)) : null,
      ),
      child: Icon(
        category.icon,
        color: category.color.withValues(alpha: pending ? 0.6 : 1),
        size: size * 0.5,
      ),
    );
    if (!pending) {
      return badge;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        badge,
        const Positioned(top: -4, right: -4, child: RadarPendingMark()),
      ],
    );
  }
}

/// The small "?" that marks a not-yet-confirmed user report.
class RadarPendingMark extends StatelessWidget {
  const RadarPendingMark({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFD8A35A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        '?',
        style: TextStyle(
          fontSize: size * 0.62,
          height: 1,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF213134),
        ),
      ),
    );
  }
}
