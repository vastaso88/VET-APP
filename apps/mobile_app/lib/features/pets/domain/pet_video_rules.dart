/// What a pet's gallery accepts as a video, in one place.
///
/// The ceilings come from the Supabase free plan the app runs on: a single
/// upload is capped at 50 MB and the whole project has 1 GB of Storage.
/// Nothing transcodes on the phone (no heavy native dependency), so the file
/// is stored as the camera wrote it and the limits are what keep it small:
///
/// * 30 s of a phone's default 1080p30 (about 10-13 Mbit/s) is 37-49 MB, so
///   it fits under the 50 MB cap; 60 s would not (75-100 MB). 4K never fits.
/// * 1 GB / 50 MB is only 20 maximal videos for the whole project - the
///   reason to move to a paid plan (or add per-user quotas) before the video
///   feature is opened to everyone, not a reason for tighter limits here.
const petVideoMaxSeconds = 30;
const petVideoMaxBytes = 50 * 1000 * 1000;

/// Containers whose metadata [stripVideoLocationMetadata] knows how to clean
/// and every phone camera produces (Android: mp4, iOS: mov).
const petVideoExtensions = {'mp4', 'm4v', 'mov'};

enum PetMediaKind { photo, video }

/// Lower-case extension without the dot, '' when there is none.
String fileExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}

const _videoLikeExtensions = {
  'mp4', 'm4v', 'mov', '3gp', '3g2', 'webm', 'mkv', 'avi', 'mpg', 'mpeg', 'wmv', 'flv',
};

/// Photo or video for something the picker returned. The MIME type wins when
/// the platform provides one (web blobs often carry none, so the name decides).
PetMediaKind classifyPickedMedia({required String fileName, String? mimeType}) {
  final mime = mimeType?.toLowerCase() ?? '';
  if (mime.startsWith('video/')) return PetMediaKind.video;
  if (mime.startsWith('image/')) return PetMediaKind.photo;
  return _videoLikeExtensions.contains(fileExtension(fileName))
      ? PetMediaKind.video
      : PetMediaKind.photo;
}

String petVideoContentType(String extension) =>
    extension == 'mov' ? 'video/quicktime' : 'video/mp4';

enum PetVideoRejection { unsupportedFormat, tooBig, tooLong, unreadable }

class PetVideoCheck {
  const PetVideoCheck.ok()
      : rejection = null,
        message = null;

  const PetVideoCheck.rejected(PetVideoRejection this.rejection, String this.message);

  final PetVideoRejection? rejection;

  /// Italian, ready for a SnackBar; null when accepted.
  final String? message;

  bool get isOk => rejection == null;
}

/// Checks a picked video against the limits above. [duration] is null when
/// the player could not read it - treated as unreadable, never as "short".
PetVideoCheck checkPetVideo({
  required String fileName,
  required int sizeBytes,
  required Duration? duration,
}) {
  if (!petVideoExtensions.contains(fileExtension(fileName))) {
    return const PetVideoCheck.rejected(
      PetVideoRejection.unsupportedFormat,
      'Formato video non supportato: usa un file MP4 o MOV.',
    );
  }
  if (sizeBytes > petVideoMaxBytes) {
    final megabytes = (sizeBytes / 1000000).round();
    return PetVideoCheck.rejected(
      PetVideoRejection.tooBig,
      'Video troppo pesante ($megabytes MB): il massimo è ${petVideoMaxBytes ~/ 1000000} MB. '
      'Registra un clip più breve o a risoluzione più bassa.',
    );
  }
  if (duration == null) {
    return const PetVideoCheck.rejected(
      PetVideoRejection.unreadable,
      'Non riesco a leggere questo video.',
    );
  }
  if (duration.inMilliseconds > petVideoMaxSeconds * 1000) {
    return const PetVideoCheck.rejected(
      PetVideoRejection.tooLong,
      'Video troppo lungo: il massimo è $petVideoMaxSeconds secondi.',
    );
  }
  return const PetVideoCheck.ok();
}

/// "0:07", "0:30" - for the badge on a video tile.
String petVideoDurationLabel(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  return '${safe ~/ 60}:${(safe % 60).toString().padLeft(2, '0')}';
}
