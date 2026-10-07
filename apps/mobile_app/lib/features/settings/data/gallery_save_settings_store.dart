import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted on/off switch for "Salva le foto nella galleria": when on, photos
/// and videos taken with the in-app camera also get a copy in the phone's
/// "VetApp" album. On by default. Same singleton + [ChangeNotifier] pattern as
/// [LayoutSettingsStore], so the Settings switch and the camera flow agree.
class GallerySaveSettingsStore extends ChangeNotifier {
  GallerySaveSettingsStore._();

  static final GallerySaveSettingsStore instance = GallerySaveSettingsStore._();

  static const _storageKey = 'vet_app.save_camera_media_to_gallery';

  bool _enabled = true;
  bool get enabled => _enabled;

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getBool(_storageKey);
      if (stored != null && stored != _enabled) {
        _enabled = stored;
        notifyListeners();
      }
    } catch (_) {
      // Keep the default - an unreadable preference isn't fatal.
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_storageKey, value);
    } catch (_) {
      // Best-effort: the in-memory value already applies for this session.
    }
  }
}
