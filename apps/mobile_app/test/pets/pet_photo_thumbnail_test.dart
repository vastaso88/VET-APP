import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vet_app_mobile/features/pets/data/pet_photo_disk_cache.dart';
import 'package:vet_app_mobile/features/pets/data/pet_photo_repository.dart';

Uint8List _jpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 120, 40));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

class _MemoryDisk implements PetPhotoDiskCache {
  final Map<String, Uint8List> files = {};

  @override
  Future<Uint8List?> read(String storagePath) async => files[storagePath];

  @override
  Future<void> write(String storagePath, Uint8List bytes) async => files[storagePath] = bytes;

  @override
  Future<void> remove(String storagePath) async => files.remove(storagePath);

  @override
  Future<void> removeFolder(String prefix) async =>
      files.removeWhere((key, _) => key.startsWith('$prefix/'));

  @override
  Future<void> clear() async => files.clear();
}

class _FakeObjects implements PetPhotoObjectStore {
  final Map<String, Uint8List> objects = {};
  final List<String> downloads = [];
  final List<String> uploads = [];

  @override
  Future<Uint8List> download(String path) async {
    downloads.add(path);
    final found = objects[path];
    if (found == null) throw StateError('not found: $path');
    return found;
  }

  @override
  Future<void> upload(String path, Uint8List bytes, {required String contentType}) async {
    uploads.add(path);
    objects[path] = bytes;
  }

  @override
  Future<void> remove(List<String> paths) async => paths.forEach(objects.remove);
}

const _owner = 'owner-1';
const _photo = '$_owner/pet-1/photo-1.jpg';
const _thumb = '$_owner/pet-1/photo-1_t.jpg';

void main() {
  late _MemoryDisk disk;
  late _FakeObjects objects;
  late PetPhotoRepository repository;

  setUp(() {
    PetPhotoRepository.resetMemoryForTests();
    disk = _MemoryDisk();
    objects = _FakeObjects();
    repository = PetPhotoRepository(
      diskCache: disk,
      objects: objects,
      ownerIdResolver: () => _owner,
    );
  });

  group('thumbnail helpers', () {
    test('compressPetPhotoThumbnail shrinks the longest side and keeps it small', () {
      final out = compressPetPhotoThumbnail(_jpeg(1600, 1000));

      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, petPhotoThumbSide);
      expect(decoded.height, 320);
      expect(out.length, lessThan(_jpeg(1600, 1000).length));
    });

    test('a small picture is never enlarged', () {
      final decoded = img.decodeJpg(compressPetPhotoThumbnail(_jpeg(200, 100)))!;
      expect(decoded.width, 200);
      expect(decoded.height, 100);
    });

    test('bytes that are not an image are refused', () {
      expect(
        () => compressPetPhotoThumbnail(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });

    test('the thumbnail sits beside the photo with a _t.jpg ending', () {
      expect(petPhotoThumbPath('o/p/id.jpg'), 'o/p/id_t.jpg');
      expect(petPhotoThumbPath('o/p/id.v2.jpeg'), 'o/p/id.v2_t.jpg');
      expect(petPhotoThumbPath('o/p.d/id'), 'o/p.d/id_t.jpg');
    });
  });

  group('loadThumbnail', () {
    test('uses the thumbnail object when Storage has one: no full photo is downloaded', () async {
      final small = _jpeg(100, 100);
      objects.objects[_thumb] = small;
      objects.objects[_photo] = _jpeg(1600, 1200);

      final bytes = await repository.loadThumbnail(_photo);

      expect(bytes, small);
      expect(objects.downloads, [_thumb]);
      expect(disk.files[_thumb], small, reason: 'kept on the phone for the next launch');
    });

    test('a photo without a thumbnail is shrunk here, kept, and offered back to Storage', () async {
      objects.objects[_photo] = _jpeg(1600, 1200);

      final bytes = await repository.loadThumbnail(_photo);

      final decoded = img.decodeJpg(bytes!)!;
      expect(decoded.width, petPhotoThumbSide);
      expect(objects.downloads, [_thumb, _photo]);
      expect(disk.files[_thumb], bytes);
      await Future<void>.delayed(Duration.zero);
      expect(objects.uploads, [_thumb]);
      expect(disk.files.containsKey(_photo), isFalse, reason: 'the full photo is not kept for a tile');
    });

    test('a second ask is answered from memory, a later launch from disk', () async {
      objects.objects[_photo] = _jpeg(1600, 1200);
      final first = await repository.loadThumbnail(_photo);
      objects.downloads.clear();

      expect(await repository.loadThumbnail(_photo), first);
      expect(objects.downloads, isEmpty);

      PetPhotoRepository.resetMemoryForTests(); // a new launch: memory is empty
      expect(await repository.loadThumbnail(_photo), first);
      expect(objects.downloads, isEmpty);
    });

    test('a full photo already on the phone is shrunk without any download', () async {
      disk.files[_photo] = _jpeg(1600, 1200);

      final bytes = await repository.loadThumbnail(_photo);

      expect(img.decodeJpg(bytes!)!.width, petPhotoThumbSide);
      expect(objects.downloads, isEmpty);
    });

    test('many tiles asking for the same photo cost one download', () async {
      objects.objects[_thumb] = _jpeg(100, 100);

      final results = await Future.wait([
        for (var i = 0; i < 8; i++) repository.loadThumbnail(_photo),
      ]);

      expect(results.every((bytes) => bytes != null), isTrue);
      expect(objects.downloads, [_thumb]);
    });

    test('a photo that cannot be fetched answers null, not an error', () async {
      expect(await repository.loadThumbnail(_photo), isNull);
    });

    test("another account's photo is never read from or written to the disk cache", () async {
      const foreign = 'owner-2/pet-1/photo-9.jpg';
      objects.objects[petPhotoThumbPath(foreign)] = _jpeg(100, 100);

      await repository.loadThumbnail(foreign);

      expect(disk.files, isEmpty);
    });
  });

  group('loadBytes', () {
    test('many viewers of the same photo cost one download, then memory', () async {
      objects.objects[_photo] = _jpeg(1600, 1200);

      await Future.wait([for (var i = 0; i < 5; i++) repository.loadBytes(_photo)]);
      await repository.loadBytes(_photo);

      expect(objects.downloads, [_photo]);
      expect(disk.files[_photo], isNotNull);
    });
  });
}
