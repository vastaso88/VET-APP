import 'dart:typed_data';

import 'pet_photo_disk_cache.dart';

/// Browser: no disk cache.
PetPhotoDiskCache createPlatformPetPhotoDiskCache() => const _NoPhotoDiskCache();

class _NoPhotoDiskCache implements PetPhotoDiskCache {
  const _NoPhotoDiskCache();

  @override
  Future<Uint8List?> read(String storagePath) async => null;

  @override
  Future<void> write(String storagePath, Uint8List bytes) async {}

  @override
  Future<void> remove(String storagePath) async {}

  @override
  Future<void> removeFolder(String prefix) async {}

  @override
  Future<void> clear() async {}
}
