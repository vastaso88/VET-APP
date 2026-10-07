import 'package:flutter/material.dart';

import '../../local_activities/domain/local_activity.dart';
import '../domain/radar_place.dart';

/// The single category vocabulary of the radar page: every list row, map
/// marker, quick filter and legend entry reads its label, icon and color
/// from here, so a category always looks the same wherever it appears.
enum RadarCategory {
  veterinary('Veterinari', Icons.local_hospital, Color(0xFFB3261E)),
  shop('Negozi', Icons.storefront, Color(0xFF8A5A00)),
  dogPark('Aree cani', Icons.park, Color(0xFF2E7D32)),
  shelter('Rifugi e adozioni', Icons.cottage, Color(0xFF3949AB)),
  grooming('Toelettature', Icons.content_cut, Color(0xFF7B4FA3)),
  hotel('Pensioni', Icons.night_shelter, Color(0xFF1F6FA5)),
  school('Addestramento', Icons.school, Color(0xFF00796B)),
  petSitting('Pet sitter', Icons.volunteer_activism, Color(0xFFAD1457)),
  breeder('Allevamenti', Icons.pets, Color(0xFF6D4C41)),
  other('Altri servizi', Icons.place, Color(0xFF546E7A));

  const RadarCategory(this.label, this.icon, this.color);

  /// Plural label, used for filters and the legend.
  final String label;
  final IconData icon;

  /// Dark enough for a white icon on top (map markers) and for the icon
  /// itself on the app's light surfaces.
  final Color color;
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
  switch (type) {
    case RadarPlaceType.veterinary:
      return 'Veterinario';
    case RadarPlaceType.grooming:
      return 'Toelettatura';
    case RadarPlaceType.shop:
      return 'Negozio per animali';
    case RadarPlaceType.school:
      return 'Addestramento';
    case RadarPlaceType.petSitting:
      return 'Pet sitter';
    case RadarPlaceType.breeder:
      return 'Allevamento';
    case RadarPlaceType.hotel:
      return 'Pensione per animali';
    case RadarPlaceType.dogPark:
      return 'Area cani';
    case RadarPlaceType.shelter:
      return 'Rifugio per animali';
    case RadarPlaceType.other:
      return 'Servizio per animali';
  }
}

/// Turns OpenStreetMap's `opening_hours` shorthand into readable Italian
/// without interpreting it: day and keyword abbreviations only.
String formatOpeningHours(String raw) {
  if (raw.trim() == '24/7') {
    return 'Indicato come aperto 24 ore su 24';
  }
  const words = {
    'Mo': 'Lun',
    'Tu': 'Mar',
    'We': 'Mer',
    'Th': 'Gio',
    'Fr': 'Ven',
    'Sa': 'Sab',
    'Su': 'Dom',
    'PH': 'Festivi',
    'off': 'chiuso',
    'closed': 'chiuso',
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
