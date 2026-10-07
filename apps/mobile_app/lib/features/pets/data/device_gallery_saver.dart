import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

import '../../settings/data/gallery_save_settings_store.dart';

/// Name of the album created in the phone's gallery.
const deviceGalleryAlbum = 'VetApp';

/// Copies what the in-app camera just captured into the phone's "VetApp"
/// album (MediaStore on Android, so no storage permission from Android 10 on).
///
/// Only for camera captures: files picked from the gallery are already there.
/// The copy is the untouched original, GPS included - location data is removed
/// only from what is uploaded (see PetMediaImporter).
class DeviceGallerySaver {
  const DeviceGallerySaver({
    bool Function()? isEnabled,
    Future<void> Function(String path)? putImage,
    Future<void> Function(String path)? putVideo,
    Future<bool> Function()? ensureAccess,
  })  : _isEnabled = isEnabled ?? _settingEnabled,
        _ensureAccess = ensureAccess ?? _galEnsureAccess,
        _putImage = putImage ?? _galPutImage,
        _putVideo = putVideo ?? _galPutVideo;

  final bool Function() _isEnabled;
  final Future<void> Function(String path) _putImage;
  final Future<void> Function(String path) _putVideo;
  final Future<bool> Function() _ensureAccess;

  static bool _settingEnabled() => GallerySaveSettingsStore.instance.enabled;

  /// Android 9 and older treat WRITE_EXTERNAL_STORAGE as a runtime permission:
  /// without asking, the save would always fail silently. From Android 10 (and
  /// on iOS for adding to an album) access is already granted, so no extra popup.
  static Future<bool> _galEnsureAccess() async {
    if (await Gal.hasAccess(toAlbum: true)) return true;
    return Gal.requestAccess(toAlbum: true);
  }

  static Future<void> _galPutImage(String path) =>
      Gal.putImage(path, album: deviceGalleryAlbum);

  static Future<void> _galPutVideo(String path) =>
      Gal.putVideo(path, album: deviceGalleryAlbum);

  /// Returns true when a copy was written; false when disabled or access is
  /// denied. Never throws: a failed local copy
  /// must not get in the way of the upload that follows.
  Future<bool> save(XFile file, {required bool isVideo}) async {
    if (kIsWeb || !_isEnabled()) return false;
    try {
      if (!await _ensureAccess()) return false;
      await (isVideo ? _putVideo(file.path) : _putImage(file.path));
      return true;
    } catch (_) {
      return false;
    }
  }
}
