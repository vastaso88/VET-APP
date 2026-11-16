import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/notifications/domain/memory_notifications.dart';
import 'package:vet_app_mobile/features/notifications/domain/notification_plan.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';

import 'notification_test_data.dart';

/// Ricordi (docs/product/17_ricordi_animali.md §4-5). Synthetic data only.
void main() {
  // Monday 16 November 2026, 08:00.
  final monday = DateTime(2026, 11, 16, 8);

  PetProfile memorial({
    String birth = '20 nov 2015',
    DateTime? loss,
    bool birthday = false,
    bool walks = false,
    bool photos = false,
  }) =>
      testPet('Moka', birth: birth, memorial: true).copyWith(
        memorialDate: loss ?? DateTime(2026, 11, 10),
        memorialBirthdayReminder: birthday,
        memorialWalksReminder: walks,
        memorialPhotosReminder: photos,
      );

  ReminderEntry vaccine(String id, {String petName = 'Moka', String? petId}) => ReminderEntry(
        id: id,
        petName: petName,
        petId: petId,
        title: 'Vaccino',
        kind: EventKind.spot,
        dueAt: DateTime(2026, 11, 25, 11),
      );

  group('a pet in Ricordi stops everything of a living pet', () {
    test('no vaccine, no course, no ordinary birthday, nothing when no memory is on', () {
      final plan = planNotifications(
        reminders: [
          vaccine('v1', petId: 'pet-Moka'),
          ReminderEntry(
            id: 'c1',
            petName: 'Moka',
            title: 'Antibiotico',
            kind: EventKind.course,
            dueAt: DateTime(2026, 11, 17, 8),
            courseDurationDays: 5,
            doseTimes: const ['08:00', '20:00'],
          ),
        ],
        pets: [memorial()],
        now: monday,
      );
      expect(plan, isEmpty);
    });

    test('an active pet with the same name keeps its own reminders', () {
      final old = memorial().copyWith(id: 'pet-Moka-old');
      final alive = testPet('Moka');
      final plan = planNotifications(
        reminders: [
          vaccine('of-the-old-one', petId: 'pet-Moka-old'),
          vaccine('just-created'), // no id yet: the active pet wins
        ],
        pets: [old, alive],
        now: monday,
      );
      expect(plan.map((n) => n.payload).toSet(), {'reminder:just-created', null});
      expect(plan.every((n) => n.petId == 'pet-Moka'), isTrue);
    });
  });

  group('memories', () {
    test('birthday: on the day at 10:00, text only, tapping opens the memorial page', () {
      final plan = planNotifications(
        reminders: const [],
        pets: [memorial(birthday: true)],
        now: monday,
      );
      expect(plan, hasLength(1));
      expect(plan.single.at, DateTime(2026, 11, 20, 10));
      expect(plan.single.title, 'Oggi è il compleanno di Moka');
      expect(plan.single.body, 'Se ti va, le sue foto sono qui.');
      expect(plan.single.category, NotificationCategory.memories);
      expect(plan.single.payload, 'memory:pet-Moka:birthday');
      expect(plan.single.title + plan.single.body, isNot(contains('regalo')));
    });

    test('never on or before the day of the loss', () {
      final onLossDay = memorialNotificationsFor(
        memorial(birthday: true, loss: DateTime(2026, 11, 20)),
        monday,
      );
      expect(onLossDay, isEmpty);
    });

    test('favourite walk anniversaries; the birthday wins a shared day', () {
      final plan = memoryNotifications(
        memorial(birthday: true, walks: true),
        now: monday,
        until: DateTime(2027, 1, 15),
        favouriteWalks: [
          MemoryWalk(id: 'w1', startedAt: DateTime(2024, 11, 25, 17)),
          MemoryWalk(id: 'w2', startedAt: DateTime(2025, 11, 20, 9)),
          MemoryWalk(id: 'w3', startedAt: DateTime(2026, 9, 1, 9)), // not a year yet
        ],
      );
      expect(plan.map((n) => n.at), [DateTime(2026, 11, 20, 10), DateTime(2026, 11, 25, 10)]);
      expect(plan[0].payload, 'memory:pet-Moka:birthday');
      expect(plan[1].title, '2 anni fa, una passeggiata con Moka');
      expect(plan[1].payload, 'memory:pet-Moka:walk:w1');
    });

    test('photos of this day: at most once a calendar week, stable across re-plans', () {
      final photos = [
        DateTime(2025, 11, 16, 12), // Monday of this week, already past
        DateTime(2024, 11, 19, 12), // same week: the week is used up
        DateTime(2023, 11, 24, 12), // next week
        DateTime(2022, 11, 26, 12), // same next week: skipped
      ];
      final wednesday = DateTime(2026, 11, 18, 8);
      final plan = memoryNotifications(
        memorial(photos: true),
        now: wednesday,
        until: DateTime(2026, 11, 30),
        photoDates: photos,
      );
      expect(plan.map((n) => n.at), [DateTime(2026, 11, 24, 10)]);
      expect(plan.single.title, '3 anni fa, con Moka');
      expect(plan.single.payload, 'memory:pet-Moka:photos');
    });

    test('nothing for a pet still in the Animali list', () {
      final alive = testPet('Rex').copyWith(memorialBirthdayReminder: true);
      expect(memorialNotificationsFor(alive, monday), isEmpty);
    });
  });

  group('MemoryTap', () {
    test('reads the three payloads and ignores the rest', () {
      final walk = MemoryTap.parse('memory:pet-1:walk:w9')!;
      expect((walk.petId, walk.kind, walk.walkId), ('pet-1', 'walk', 'w9'));
      expect(MemoryTap.parse('memory:pet-1:birthday')!.kind, 'birthday');
      expect(MemoryTap.parse('memory:pet-1:photos')!.walkId, isNull);
      expect(MemoryTap.parse('reminder:r1'), isNull);
      expect(MemoryTap.parse('memory:pet-1:party'), isNull);
      expect(MemoryTap.parse(null), isNull);
    });
  });
}

List<PlannedNotification> memorialNotificationsFor(PetProfile pet, DateTime now) =>
    memoryNotifications(pet, now: now, until: DateTime(now.year, now.month + 2, now.day));
