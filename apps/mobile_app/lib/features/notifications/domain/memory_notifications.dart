import '../../../l10n/l10n.dart';
import '../../../shared/date/calendar_days.dart';
import '../../pets/domain/pet_format.dart';
import '../../pets/domain/pet_models.dart';
import 'notification_plan.dart';

/// A favourite walk of a pet in Ricordi: its anniversary can bring a memory.
class MemoryWalk {
  const MemoryWalk({required this.id, required this.startedAt});

  final String id;
  final DateTime startedAt;
}

/// The memory notifications of one pet in Ricordi between [now] and [until]
/// (docs/product/17_ricordi_animali.md §5.1). Pure.
///
/// - Only what the owner switched on for this pet (all off by default).
/// - Never on or before the day of the loss.
/// - At most one a day: the birthday wins, then a favourite walk, then photos.
/// - "Foto di questo giorno" at most once per calendar week (Monday to
///   Sunday). The week's day is picked from the whole week, past days
///   included, so re-planning on Wednesday never adds a second one to a week
///   whose Monday already had it.
/// - Text only: no photo and no place ever appears on the lock screen.
List<PlannedNotification> memoryNotifications(
  PetProfile pet, {
  required DateTime now,
  required DateTime until,
  List<MemoryWalk> favouriteWalks = const [],
  List<DateTime> photoDates = const [],
}) {
  if (!pet.isMemorial) return const [];
  final wantsAny =
      pet.memorialBirthdayReminder || pet.memorialWalksReminder || pet.memorialPhotosReminder;
  if (!wantsAny) return const [];

  final l10n = appL10n;
  final today = dayOnly(now);
  final lastDay = dayOnly(until);
  final rangeStart = addCalendarDays(today, -(today.weekday - DateTime.monday));
  final loss = pet.memorialDate == null ? null : dayOnly(pet.memorialDate!);

  bool inRange(DateTime day) =>
      !day.isBefore(rangeStart) && !day.isAfter(lastDay) && (loss == null || day.isAfter(loss));

  PlannedNotification at(
    DateTime day,
    String title,
    String body,
    String payload,
  ) =>
      PlannedNotification(
        at: DateTime(day.year, day.month, day.day, kMemoryNotificationHour),
        title: title,
        body: body,
        category: NotificationCategory.memories,
        payload: '$kMemoryPayloadPrefix${pet.id}:$payload',
        petId: pet.id,
      );

  // Insertion order is priority order: the first memory of a day keeps it.
  final byDay = <DateTime, PlannedNotification>{};

  if (pet.memorialBirthdayReminder) {
    final birth = parsePetBirthdayLabel(pet.birthDateLabel);
    if (birth != null) {
      final day = nextBirthday(birth, rangeStart);
      if (day.year > birth.year && inRange(day)) {
        byDay.putIfAbsent(
          day,
          () => at(
            day,
            l10n.notificationsMemoryBirthdayTitle(pet.name),
            l10n.notificationsMemoryBirthdayBody,
            'birthday',
          ),
        );
      }
    }
  }

  if (pet.memorialWalksReminder) {
    final walks = [...favouriteWalks]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    for (final walk in walks) {
      final walked = dayOnly(walk.startedAt);
      final day = nextBirthday(walked, rangeStart);
      final years = day.year - walked.year;
      if (years < 1 || !inRange(day)) continue;
      byDay.putIfAbsent(
        day,
        () => at(
          day,
          l10n.notificationsMemoryWalkTitle(years, pet.name),
          l10n.notificationsMemoryWalkBody,
          'walk:${walk.id}',
        ),
      );
    }
  }

  if (pet.memorialPhotosReminder && photoDates.isNotEmpty) {
    // month*100+day -> the years photos were taken on that day.
    final yearsByDay = <int, List<int>>{};
    for (final date in photoDates) {
      yearsByDay.putIfAbsent(date.month * 100 + date.day, () => []).add(date.year);
    }
    var weekStart = rangeStart;
    while (!weekStart.isAfter(lastDay)) {
      for (var offset = 0; offset < 7; offset++) {
        final day = addCalendarDays(weekStart, offset);
        if (!inRange(day)) continue;
        final years = yearsByDay[day.month * 100 + day.day];
        if (years == null) continue;
        final past = years.where((year) => year < day.year);
        if (past.isEmpty) continue;
        // A day already holding the birthday or a walk uses up the week too:
        // the owner still gets one memory that week, not two.
        final ago = day.year - past.reduce((a, b) => a > b ? a : b);
        byDay.putIfAbsent(
          day,
          () => at(
            day,
            l10n.notificationsMemoryPhotosTitle(ago, pet.name),
            l10n.notificationsMemoryPhotosBody,
            'photos',
          ),
        );
        break;
      }
      weekStart = addCalendarDays(weekStart, 7);
    }
  }

  final planned = [
    for (final entry in byDay.entries)
      if (!entry.key.isBefore(today)) entry.value,
  ]..sort((a, b) => a.at.compareTo(b.at));
  return planned;
}

/// What a memory notification's payload points at.
class MemoryTap {
  const MemoryTap({required this.petId, required this.kind, this.walkId});

  final String petId;

  /// `birthday`, `walk` or `photos`.
  final String kind;
  final String? walkId;

  /// Null when [payload] is not a memory payload.
  static MemoryTap? parse(String? payload) {
    if (payload == null || !payload.startsWith(kMemoryPayloadPrefix)) return null;
    final parts = payload.substring(kMemoryPayloadPrefix.length).split(':');
    if (parts.length < 2 || parts[0].isEmpty) return null;
    final kind = parts[1];
    if (kind != 'birthday' && kind != 'walk' && kind != 'photos') return null;
    return MemoryTap(
      petId: parts[0],
      kind: kind,
      walkId: kind == 'walk' && parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
    );
  }
}
