import 'dart:typed_data';

import 'pet_photo_disk_cache_stub.dart'
    if (dart.library.io) 'pet_photo_disk_cache_io.dart';

/// Pet photos kept on the phone between launches, keyed by their Storage
/// path, so the gallery and avatars stop re-downloading the same files
/// (Storage egress is billed). Phone only: the browser keeps the in-memory
/// session cache of PetPhotoRepository and nothing else.
///
/// Private data: [clear] runs on sign-out (bootstrap.dart). Every method is
/// best effort - a cache problem never fails a load or an upload.
abstract class PetPhotoDiskCache {
  static final PetPhotoDiskCache instance = createPlatformPetPhotoDiskCache();

  Future<Uint8List?> read(String storagePath);

  Future<void> write(String storagePath, Uint8List bytes);

  Future<void> remove(String storagePath);

  /// Removes everything under `<prefix>/` (e.g. `<owner>/<pet>`).
  Future<void> removeFolder(String prefix);

  /// Removes every cached photo, of every account.
  Future<void> clear();
}
