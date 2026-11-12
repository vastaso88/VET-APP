import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

import 'pet_video_compressor.dart';

PetVideoCompressor createPlatformPetVideoCompressor() => const _NativeVideoCompressor();

/// video_compress: Transcoder (MediaCodec) on Android, AVAssetExportSession
/// on iOS - hardware encoders, no FFmpeg, no extra permission needed for
/// its output folder (app-private).
class _NativeVideoCompressor implements PetVideoCompressor {
  const _NativeVideoCompressor();

  @override
  bool get isAvailable => Platform.isAndroid || Platform.isIOS;

  @override
  Future<XFile?> compress(XFile video, {void Function(double fraction)? onProgress}) async {
    if (!isAvailable) return null;
    final progress = VideoCompress.compressProgress$.subscribe((percent) {
      onProgress?.call((percent / 100).clamp(0.0, 1.0));
    });
    try {
      // The original is never deleted here: the copy in the phone's album
      // (DeviceGallerySaver) must stay the untouched original.
      final info = await VideoCompress.compressVideo(
        video.path,
        quality: VideoQuality.Res1280x720Quality,
        includeAudio: true,
      );
      final path = info?.path;
      if (info == null || info.isCancel == true || path == null) return null;
      if (!await File(path).exists()) return null;
      return XFile(path, mimeType: 'video/mp4');
    } catch (_) {
      return null;
    } finally {
      progress.unsubscribe();
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await VideoCompress.cancelCompression();
    } catch (_) {
      // Nothing running, or the plugin is gone: nothing to stop.
    }
  }

  @override
  Future<void> releaseTemporaryFiles() async {
    if (!isAvailable) return;
    try {
      // The plugin's own output folder - only re-encoded files live there.
      await VideoCompress.deleteAllCache();
    } catch (_) {
      // Best effort; the folder is app-private and cleared on uninstall.
    }
  }

  @override
  Future<void> discardPickedCopy(XFile file) async {
    if (!isAvailable || file.path.isEmpty) return;
    try {
      final temporary = (await getTemporaryDirectory()).path;
      if (!file.path.startsWith('$temporary${Platform.pathSeparator}')) return;
      final copy = File(file.path);
      if (await copy.exists()) await copy.delete();
    } catch (_) {
      // Best effort: the OS clears this folder when space runs low.
    }
  }
}
