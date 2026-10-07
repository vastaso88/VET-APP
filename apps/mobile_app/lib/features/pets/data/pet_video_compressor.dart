import 'package:image_picker/image_picker.dart';

import 'pet_video_compressor_stub.dart'
    if (dart.library.io) 'pet_video_compressor_io.dart';

/// Re-encodes a picked video to 720p before upload, so a 30 s clip costs
/// ~8-15 MB of Storage instead of 40-75 MB (see pet_video_rules.dart).
///
/// Phone only: the browser build gets a no-op ([isAvailable] false) and the
/// importer then uploads the original within the stricter browser limit.
abstract class PetVideoCompressor {
  /// The implementation for the running platform.
  factory PetVideoCompressor() => createPlatformPetVideoCompressor();

  bool get isAvailable;

  /// The re-encoded copy, or null when it failed or was [cancel]led.
  /// [onProgress] receives 0..1.
  Future<XFile?> compress(XFile video, {void Function(double fraction)? onProgress});

  /// Stops the running [compress], which then returns null.
  Future<void> cancel();

  /// Deletes every re-encoded file still on disk (they are only needed
  /// until the upload ends, whatever its outcome).
  Future<void> releaseTemporaryFiles();

  /// Deletes the private copy the picker/camera left in the app's temporary
  /// folder. Anything outside that folder is never touched.
  Future<void> discardPickedCopy(XFile file);
}
