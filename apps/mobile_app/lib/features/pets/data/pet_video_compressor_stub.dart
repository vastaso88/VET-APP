import 'package:image_picker/image_picker.dart';

import 'pet_video_compressor.dart';

/// Browser: no native encoder, the original is uploaded as it is.
PetVideoCompressor createPlatformPetVideoCompressor() => const _UnavailableVideoCompressor();

class _UnavailableVideoCompressor implements PetVideoCompressor {
  const _UnavailableVideoCompressor();

  @override
  bool get isAvailable => false;

  @override
  Future<XFile?> compress(XFile video, {void Function(double fraction)? onProgress}) async =>
      null;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> releaseTemporaryFiles() async {}

  @override
  Future<void> discardPickedCopy(XFile file) async {}
}
