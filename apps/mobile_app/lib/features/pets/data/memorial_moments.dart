import '../../../shared/auth/current_user.dart';
import '../../dog_walks/data/dog_walks_repository.dart';
import '../../dog_walks/domain/walk_session.dart';
import 'pet_photo_repository.dart';

/// What a pet in Ricordi left behind that a memory can point at: its
/// completed walks (the favourites among them) and its photos. Read only
/// from the owner's own data, nothing leaves the phone
/// (docs/product/17_ricordi_animali.md §5.4).
class MemorialMoments {
  const MemorialMoments({this.walks = const [], this.photos = const []});

  /// Completed walks, newest first, without their GPS route.
  final List<WalkSession> walks;

  /// Photos and videos of the gallery, newest first.
  final List<PetPhotoEntry> photos;

  List<WalkSession> get favouriteWalks => [
        for (final walk in walks)
          if (walk.isFavorite) walk,
      ];

  double get totalDistanceMeters => walks.fold(0, (sum, walk) => sum + walk.distanceMeters);

  /// Photos with a shooting date: the only ones that can belong to a day.
  List<PetPhotoEntry> get datedPhotos => [
        for (final photo in photos)
          if (photo.takenAt != null) photo,
      ];

  static Future<MemorialMoments> load(String petId) async {
    final ownerId = CurrentUser.get()?.id;
    var walks = const <WalkSession>[];
    var photos = const <PetPhotoEntry>[];
    if (ownerId != null) {
      try {
        walks = [
          for (final walk in await DogWalksRepository().loadWalkSummaries(
            ownerId,
          ))
            if (walk.petId == petId && walk.status == WalkStatus.completed) walk,
        ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      } catch (_) {
        // Offline: the page shows what it can.
      }
    }
    try {
      photos = await PetPhotoRepository().list(petId);
    } catch (_) {}
    return MemorialMoments(walks: walks, photos: photos);
  }
}

/// Photos taken within [windowDays] days of [day]'s month and day, in any
/// year before [day]'s: e.g. the photos of past birthdays.
List<PetPhotoEntry> photosAroundAnniversary(
  List<PetPhotoEntry> photos,
  DateTime day, {
  int windowDays = 3,
}) {
  final result = <PetPhotoEntry>[];
  for (final photo in photos) {
    final taken = photo.takenAt?.toLocal();
    if (taken == null || taken.year >= day.year) continue;
    final sameDayThatYear = _sameMonthDay(day, taken.year);
    final takenDay = DateTime(taken.year, taken.month, taken.day);
    if (takenDay.difference(sameDayThatYear).inDays.abs() <= windowDays) result.add(photo);
  }
  return result;
}

/// Photos taken on [day]'s month and day in an earlier year.
List<PetPhotoEntry> photosOnThisDay(List<PetPhotoEntry> photos, DateTime day) =>
    photosAroundAnniversary(photos, day, windowDays: 0);

/// Photos taken while [walk] was going on.
List<PetPhotoEntry> photosDuringWalk(
  List<PetPhotoEntry> photos,
  WalkSession walk,
) {
  final start = walk.startedAt.toUtc();
  final end =
      (walk.endedAt ?? walk.startedAt.add(Duration(seconds: walk.durationSeconds ?? 0))).toUtc();
  return [
    for (final photo in photos)
      if (photo.takenAt != null &&
          !photo.takenAt!.toUtc().isBefore(start) &&
          !photo.takenAt!.toUtc().isAfter(end))
        photo,
  ];
}

DateTime _sameMonthDay(DateTime day, int year) {
  // 29 February in a year without it: 28 February, as for birthdays.
  final lastDay = DateTime(year, day.month + 1, 0).day;
  return DateTime(year, day.month, day.day > lastDay ? lastDay : day.day);
}
