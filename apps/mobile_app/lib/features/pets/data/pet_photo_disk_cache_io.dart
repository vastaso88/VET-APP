import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'pet_photo_disk_cache.dart';

PetPhotoDiskCache createPlatformPetPhotoDiskCache() => FilePetPhotoDiskCache();

/// Files under `<app cache>/pet_photos/<storage path>`. The app cache folder
/// is private to VetApp and the OS may empty it when space runs low - fine
/// for a cache. Android/iOS only unless a [root] is given (tests).
class FilePetPhotoDiskCache implements PetPhotoDiskCache {
  FilePetPhotoDiskCache({Directory? root, this.maxBytes = defaultMaxBytes})
      : _root = root == null ? null : Future.value(root);

  /// ~500 photos at ~0.4 MB: enough for every pet of a normal account.
  static const defaultMaxBytes = 200 * 1000 * 1000;

  final int maxBytes;
  Future<Directory?>? _root;
  bool _trimmed = false;

  Future<Directory?> _directory() => _root ??= _open();

  static Future<Directory?> _open() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return null;
    try {
      final base = await getApplicationCacheDirectory();
      return Directory('${base.path}${Platform.pathSeparator}pet_photos');
    } catch (_) {
      return null;
    }
  }

  /// Storage paths come from our own code ('<owner>/<pet>/<id>.jpg'); one that
  /// could point outside the folder is simply not cached.
  static bool _isSafe(String relative) =>
      relative.isNotEmpty &&
      !relative.startsWith('/') &&
      !relative.contains('\\') &&
      !relative.split('/').any((part) => part.isEmpty || part == '.' || part == '..');

  Future<File?> _file(String storagePath) async {
    final root = await _directory();
    if (root == null || !_isSafe(storagePath)) return null;
    return File('${root.path}/$storagePath');
  }

  @override
  Future<Uint8List?> read(String storagePath) async {
    try {
      final file = await _file(storagePath);
      if (file == null || !await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String storagePath, Uint8List bytes) async {
    try {
      final file = await _file(storagePath);
      if (file == null) return;
      await file.parent.create(recursive: true);
      // Written aside then renamed: a crash mid-write never leaves a
      // truncated photo that would be served as if it were complete.
      final partial = File('${file.path}.part');
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(file.path);
      if (!_trimmed) {
        _trimmed = true;
        await _trim();
      }
    } catch (_) {
      // Best effort.
    }
  }

  @override
  Future<void> remove(String storagePath) async {
    try {
      final file = await _file(storagePath);
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {
      // Best effort.
    }
  }

  @override
  Future<void> removeFolder(String prefix) async {
    try {
      final root = await _directory();
      if (root == null || !_isSafe(prefix)) return;
      final folder = Directory('${root.path}/$prefix');
      if (await folder.exists()) await folder.delete(recursive: true);
    } catch (_) {
      // Best effort.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final root = await _directory();
      if (root != null && await root.exists()) await root.delete(recursive: true);
    } catch (_) {
      // Best effort.
    } finally {
      _trimmed = false;
    }
  }

  /// Once per session: past [maxBytes], drops the oldest files until the
  /// cache is back to 80% of it.
  Future<void> _trim() async {
    final root = await _directory();
    if (root == null || !await root.exists()) return;
    final files = <(File, FileStat)>[];
    var total = 0;
    await for (final entity in root.list(recursive: true)) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      files.add((entity, stat));
      total += stat.size;
    }
    if (total <= maxBytes) return;
    files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    final target = maxBytes * 0.8;
    for (final (file, stat) in files) {
      if (total <= target) break;
      await file.delete();
      total -= stat.size;
    }
  }
}
