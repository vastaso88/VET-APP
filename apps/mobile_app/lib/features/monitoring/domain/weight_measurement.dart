import '../../pets/domain/pet_models.dart';
import 'body_condition.dart';

/// Pets that get the weight monitoring: every species except fish (an
/// aquarium has no single animal to weigh).
bool supportsWeightMonitoring(PetProfile pet) =>
    !pet.isAquarium && pet.species.trim().toLowerCase() != 'pesce';

/// One weighing of one pet. The weight is always kept in kilograms; the
/// owner's unit system only changes how it is typed and shown.
class WeightMeasurement {
  const WeightMeasurement({
    required this.id,
    required this.petId,
    required this.ownerId,
    required this.measuredOn,
    required this.weightKg,
    this.bodyCondition,
    this.note = '',
    this.createdAt,
  });

  final String id;
  final String petId;
  final String ownerId;

  /// The day of the weighing (time of day is always midnight).
  final DateTime measuredOn;
  final double weightKg;
  final BodyCondition? bodyCondition;
  final String note;

  /// When the row was created: only breaks the tie between two weighings of
  /// the same day.
  final DateTime? createdAt;

  WeightMeasurement copyWith({
    DateTime? measuredOn,
    double? weightKg,
    BodyCondition? bodyCondition,
    bool clearBodyCondition = false,
    String? note,
  }) =>
      WeightMeasurement(
        id: id,
        petId: petId,
        ownerId: ownerId,
        measuredOn: measuredOn ?? this.measuredOn,
        weightKg: weightKg ?? this.weightKg,
        bodyCondition:
            clearBodyCondition ? null : (bodyCondition ?? this.bodyCondition),
        note: note ?? this.note,
        createdAt: createdAt,
      );

  Map<String, dynamic> toRow() => {
        'id': id,
        'pet_id': petId,
        'owner_id': ownerId,
        'measured_at': dateToIso(measuredOn),
        'weight_kg': weightKg,
        'body_condition': bodyCondition?.score,
        'note': note.trim().isEmpty ? null : note.trim(),
      };

  /// Null for a row that cannot be read (missing id/date/weight), so one bad
  /// row never hides the others.
  static WeightMeasurement? fromRow(Map<String, dynamic> row) {
    final id = (row['id'] ?? '').toString();
    final petId = (row['pet_id'] ?? '').toString();
    final date = DateTime.tryParse((row['measured_at'] ?? '').toString());
    final weight = row['weight_kg'];
    final kg = weight is num ? weight.toDouble() : double.tryParse('$weight');
    if (id.isEmpty || petId.isEmpty || date == null || kg == null || kg <= 0) {
      return null;
    }
    return WeightMeasurement(
      id: id,
      petId: petId,
      ownerId: (row['owner_id'] ?? '').toString(),
      measuredOn: DateTime(date.year, date.month, date.day),
      weightKg: kg,
      bodyCondition: BodyCondition.fromScore(row['body_condition']),
      note: (row['note'] ?? '').toString(),
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
    );
  }
}

/// `2026-10-14`: the date format of the `measured_at` column.
String dateToIso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Oldest first; two weighings of the same day keep their creation order.
List<WeightMeasurement> sortedByDate(Iterable<WeightMeasurement> measurements) {
  final list = measurements.toList();
  list.sort((a, b) {
    final byDay = a.measuredOn.compareTo(b.measuredOn);
    if (byDay != 0) return byDay;
    final aCreated = a.createdAt;
    final bCreated = b.createdAt;
    if (aCreated == null || bCreated == null) return 0;
    return aCreated.compareTo(bCreated);
  });
  return list;
}

/// The most recent weighing, or null when there is none.
WeightMeasurement? latestMeasurement(Iterable<WeightMeasurement> measurements) {
  final sorted = sortedByDate(measurements);
  return sorted.isEmpty ? null : sorted.last;
}

/// The most recent weighing that also recorded a body condition.
WeightMeasurement? latestWithBodyCondition(
    Iterable<WeightMeasurement> measurements) {
  final sorted =
      sortedByDate(measurements).where((m) => m.bodyCondition != null);
  return sorted.isEmpty ? null : sorted.last;
}
