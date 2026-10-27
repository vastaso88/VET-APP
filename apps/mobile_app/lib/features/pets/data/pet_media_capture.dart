import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/l10n.dart';
import '../../settings/data/gallery_save_settings_store.dart';
import '../domain/pet_video_rules.dart';
import 'device_gallery_saver.dart';
import 'pet_media_importer.dart';

/// Takes a photo or records a video with the system camera (or picks files
/// from the phone gallery) and sends them to a pet's gallery: the one flow
/// behind the gallery page's "Aggiungi" menu and the camera button of a walk
/// in progress (owner request, 2026-10-12).
///
/// It uses the system picker only, so no camera or storage permission is
/// needed. Every shot is marked as taken at the moment the camera returned it,
/// which is what lets the gallery caption it "Passeggiata del ..." and the
/// walk map pin it. Progress (and the Annulla of a video being reduced) is
/// exposed for the screen to show; messages are left to the caller.
class PetMediaCapture extends ChangeNotifier {
  PetMediaCapture({
    ImagePicker? picker,
    PetMediaImporter Function()? importerFactory,
    Future<void> Function(XFile file, {required bool isVideo})? saveCopy,
    DateTime Function()? now,
  })  : _picker = picker ?? ImagePicker(),
        _importerFactory = importerFactory ?? PetMediaImporter.new,
        _saveCopy = saveCopy ?? _saveCopyToDeviceGallery,
        _now = now ?? DateTime.now;

  final ImagePicker _picker;
  final PetMediaImporter Function() _importerFactory;
  final Future<void> Function(XFile file, {required bool isVideo}) _saveCopy;
  final DateTime Function() _now;

  PetMediaImporter? _importer;
  String? _progress;
  double? _compressFraction;
  bool _cancelling = false;
  bool _disposed = false;

  /// "Carico 2 di 5..." while something is being handled, null otherwise. Set
  /// the moment the picker returns, so the screen answers before any file is
  /// read.
  String? get progress => _progress;

  /// 0..1 while a video is being reduced on the phone, else null.
  double? get compressFraction => _compressFraction;

  bool get busy => _progress != null;

  /// Whether "Annulla" makes sense (an import is running).
  bool get canCancel => _importer != null;

  bool get cancelling => _cancelling;

  /// Stops the video being reduced and skips the files not started yet.
  void cancel() {
    final importer = _importer;
    if (importer == null || _cancelling) return;
    _cancelling = true;
    _compressFraction = null;
    _progress = appL10n.petsMediaCancelling;
    _changed();
    unawaited(importer.cancel());
  }

  /// The phone gallery, any number of photos and videos. Null when nothing was
  /// picked.
  Future<PetMediaImportResult?> importFromGallery(String petId) async {
    // No imageQuality: with it the picker re-encodes the photo on the phone
    // (and may lose its EXIF shooting time, which the walk caption and the walk
    // map pin depend on); compressPetPhoto re-encodes once, after the time is read.
    final files = await _picker.pickMultipleMedia();
    return importFiles(petId, files);
  }

  /// The system camera, one photo. Null when the owner backed out.
  Future<PetMediaImportResult?> takePhoto(String petId) async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    return _importCaptured(petId, file, isVideo: false);
  }

  /// The system camera, one video of at most [petVideoMaxSeconds]. Null when
  /// the owner backed out.
  Future<PetMediaImportResult?> recordVideo(String petId) async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: petVideoMaxSeconds),
    );
    return _importCaptured(petId, file, isVideo: true);
  }

  Future<PetMediaImportResult?> _importCaptured(
    String petId,
    XFile? file, {
    required bool isVideo,
  }) async {
    if (file == null || _disposed || busy) return null;
    // The camera returns right after the shot: that moment is when it was taken.
    final capturedAt = _now();
    _progress = appL10n.petsMediaPreparingFile;
    _changed();
    // Runs before the upload so the copy in the Quokka album exists even if the
    // upload fails; never throws.
    await _saveCopy(file, isVideo: isVideo);
    return importFiles(petId, [file], capturedAt: capturedAt);
  }

  /// Uploads [files] to the pet's gallery; [capturedAt] is for a shot just
  /// taken, imported files leave it null. Null when there was nothing to do.
  Future<PetMediaImportResult?> importFiles(
    String petId,
    List<XFile> files, {
    DateTime? capturedAt,
  }) async {
    if (files.isEmpty || _disposed) {
      _reset();
      return null;
    }
    final importer = _importerFactory();
    _importer = importer;
    _progress = appL10n.petsMediaPreparingFiles(files.length);
    _changed();
    // Which file of how many is being handled; null for a single file.
    ({int current, int total})? step;
    try {
      return await importer.importAll(
        petId: petId,
        files: files,
        capturedAt: capturedAt,
        onProgress: (current, total) {
          if (_disposed || _cancelling) return;
          step = total == 1 ? null : (current: current, total: total);
          _compressFraction = null;
          _progress = total == 1
              ? appL10n.petsMediaUploadingFile
              : appL10n.petsMediaUploadingProgress(current, total);
          _changed();
        },
        onCompressProgress: (fraction) {
          if (_disposed || _cancelling) return;
          _compressFraction = fraction;
          final percent = (fraction * 100).round();
          final l10n = appL10n;
          final of = step;
          _progress = fraction >= 1
              ? (of == null
                  ? l10n.petsMediaUploadingVideo
                  : l10n.petsMediaUploadingVideoOf(of.current, of.total))
              : (of == null
                  ? l10n.petsMediaReducingVideo(percent)
                  : l10n.petsMediaReducingVideoOf(of.current, of.total, percent));
          _changed();
        },
      );
    } finally {
      _reset();
    }
  }

  void _reset() {
    _progress = null;
    _compressFraction = null;
    _importer = null;
    _cancelling = false;
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Camera captures only (gallery imports are already on the phone).
  static Future<void> _saveCopyToDeviceGallery(XFile file, {required bool isVideo}) async {
    await GallerySaveSettingsStore.instance.ensureLoaded();
    await const DeviceGallerySaver().save(file, isVideo: isVideo);
  }
}
