import '../../location/domain/coordinates.dart';

enum LocalActivityKind { event, service }

enum LocalActivitySource { userSubmitted, seeded }

enum LocalActivityStatus { active, removed }

class LocalActivity {
  const LocalActivity({
    required this.id,
    required this.kind,
    required this.title,
    this.description,
    this.category,
    // Never fuzzed: public venues/events that already advertise their own
    // location, unlike marketplace listings.
    required this.location,
    this.addressLabel,
    this.startsAt,
    this.endsAt,
    this.source = LocalActivitySource.userSubmitted,
    this.submittedByOwnerId,
    this.status = LocalActivityStatus.active,
    this.reportCount = 0,
  });

  final String id;
  final LocalActivityKind kind;
  final String title;
  final String? description;
  final String? category;
  final Coordinates location;
  final String? addressLabel;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final LocalActivitySource source;
  final String? submittedByOwnerId;
  final LocalActivityStatus status;
  final int reportCount;
}
