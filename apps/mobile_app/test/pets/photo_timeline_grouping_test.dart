import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/data/pet_photo_repository.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/photo_timeline_view.dart';

PetPhotoEntry _photo(String id, DateTime when) => PetPhotoEntry(
      id: id,
      petId: 'pet-1',
      storagePath: 'owner/pet-1/$id.jpg',
      createdAt: when,
      isProfile: false,
    );

void main() {
  test('photos are grouped by day, newest day first, newest photo first within a day', () {
    final photos = [
      _photo('a', DateTime(2026, 3, 10, 9)),
      _photo('b', DateTime(2026, 3, 12, 8)),
      _photo('c', DateTime(2026, 3, 12, 18)),
      _photo('d', DateTime(2026, 1, 2, 12)),
    ];

    final groups = groupPhotosByDay(photos);

    expect(groups.map((g) => g.label), ['12 marzo 2026', '10 marzo 2026', '2 gennaio 2026']);
    expect(groups.first.photos.map((p) => p.id), ['c', 'b']);
  });

  test('an empty gallery has no day headings', () {
    expect(groupPhotosByDay(const []), isEmpty);
  });
}
