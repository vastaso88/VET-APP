import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/data/pet_photo_disk_cache_io.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('pet_photo_cache_test'));
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Uint8List bytes(int size, [int fill = 1]) => Uint8List(size)..fillRange(0, size, fill);

  test('a written photo is read back across instances (i.e. across launches)', () async {
    await FilePetPhotoDiskCache(root: root).write('owner/pet/a.jpg', bytes(10, 7));

    final read = await FilePetPhotoDiskCache(root: root).read('owner/pet/a.jpg');

    expect(read, bytes(10, 7));
    expect(await FilePetPhotoDiskCache(root: root).read('owner/pet/missing.jpg'), isNull);
  });

  test('remove, removeFolder and clear forget what they cover', () async {
    final cache = FilePetPhotoDiskCache(root: root);
    await cache.write('owner/pet1/a.jpg', bytes(4));
    await cache.write('owner/pet1/b.jpg', bytes(4));
    await cache.write('owner/pet2/c.jpg', bytes(4));

    await cache.remove('owner/pet1/a.jpg');
    expect(await cache.read('owner/pet1/a.jpg'), isNull);
    expect(await cache.read('owner/pet1/b.jpg'), isNotNull);

    await cache.removeFolder('owner/pet1');
    expect(await cache.read('owner/pet1/b.jpg'), isNull);
    expect(await cache.read('owner/pet2/c.jpg'), isNotNull);

    await cache.clear();
    expect(await cache.read('owner/pet2/c.jpg'), isNull);
    expect(root.existsSync(), isFalse);
  });

  test('paths that could leave the cache folder are never written or read', () async {
    final cache = FilePetPhotoDiskCache(root: root);

    for (final path in ['../escape.jpg', 'owner/../../x.jpg', '/abs.jpg', r'a\b.jpg', 'a//b.jpg']) {
      await cache.write(path, bytes(4));
      expect(await cache.read(path), isNull, reason: path);
    }
    expect(File('${root.parent.path}/escape.jpg').existsSync(), isFalse);
  });

  test('past the size cap the oldest photos are dropped first', () async {
    // Seed 5 x 100 bytes with increasing ages, then a new instance (= a new
    // session) trims on its first write.
    final seed = FilePetPhotoDiskCache(root: root, maxBytes: 1 << 30);
    for (var i = 0; i < 5; i++) {
      await seed.write('o/p/$i.jpg', bytes(100));
      File('${root.path}/o/p/$i.jpg')
          .setLastModifiedSync(DateTime(2026, 1, 1).add(Duration(days: i)));
    }

    final cache = FilePetPhotoDiskCache(root: root, maxBytes: 400);
    await cache.write('o/p/new.jpg', bytes(100));

    // 600 bytes > 400: trimmed to <= 320, oldest first.
    expect(await cache.read('o/p/0.jpg'), isNull);
    expect(await cache.read('o/p/1.jpg'), isNull);
    expect(await cache.read('o/p/2.jpg'), isNull);
    expect(await cache.read('o/p/3.jpg'), isNotNull);
    expect(await cache.read('o/p/new.jpg'), isNotNull);
  });
}
