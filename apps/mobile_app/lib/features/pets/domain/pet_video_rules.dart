import '../../../l10n/l10n.dart';

/// What a pet's gallery accepts as a video, in one place.
///
/// Storage plan approved 2026-10-07: on the phone every video is re-encoded
/// to 720p before upload (PetVideoCompressor) - roughly 8-15 MB for 30 s
/// instead of 40-75 MB in Full HD, and 4K clips become usable at all. The
/// browser cannot re-encode, so there the file goes up as it is and must
/// already be small.
///
/// * [petVideoMaxBytes] is what may be stored, whatever the platform; the
///   `pet-photos` bucket's file_size_limit matches it.
/// * [petVideoMaxSourceBytes] only bounds what the phone agrees to re-encode
///   (30 s of 4K is ~150-200 MB), so a mistaken pick of a huge file is
///   refused at once instead of after minutes of work.
const petVideoMaxSeconds = 30;
const petVideoMaxBytes = 20 * 1000 * 1000;
const petVideoMaxSourceBytes = 500 * 1000 * 1000;

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

  /// In the app language, ready for a SnackBar; null when accepted.
  final String? message;

  bool get isOk => rejection == null;
}

int _megabytes(int bytes) => (bytes / 1000000).ceil();

const _maxMegabytes = petVideoMaxBytes ~/ 1000000;

/// Checks a picked video against the limits above. [duration] is null when
/// the player could not read it - treated as unreadable, never as "short".
/// [willCompress] is true on the phone, where the file is re-encoded before
/// upload and may therefore start out larger than [petVideoMaxBytes].
PetVideoCheck checkPetVideo({
  required String fileName,
  required int sizeBytes,
  required Duration? duration,
  bool willCompress = false,
}) {
  if (!petVideoExtensions.contains(fileExtension(fileName))) {
    return PetVideoCheck.rejected(
      PetVideoRejection.unsupportedFormat,
      appL10n.petsMediaVideoUnsupportedFormat,
    );
  }
  if (willCompress && sizeBytes > petVideoMaxSourceBytes) {
    return PetVideoCheck.rejected(
      PetVideoRejection.tooBig,
      appL10n.petsMediaVideoTooBigSource(_megabytes(sizeBytes), petVideoMaxSourceBytes ~/ 1000000),
    );
  }
  if (!willCompress && sizeBytes > petVideoMaxBytes) {
    return PetVideoCheck.rejected(
      PetVideoRejection.tooBig,
      appL10n.petsMediaVideoTooBigBrowser(_megabytes(sizeBytes), _maxMegabytes),
    );
  }
  if (duration == null) {
    return PetVideoCheck.rejected(
      PetVideoRejection.unreadable,
      appL10n.petsMediaVideoUnreadable,
    );
  }
  if (duration.inMilliseconds > petVideoMaxSeconds * 1000) {
    return PetVideoCheck.rejected(
      PetVideoRejection.tooLong,
      appL10n.petsMediaVideoTooLong(petVideoMaxSeconds),
    );
  }
  return const PetVideoCheck.ok();
}

/// Last check on the phone, on the file that would actually be uploaded:
/// the re-encoded one, or the original when re-encoding failed.
PetVideoCheck checkPetVideoUploadSize({required int sizeBytes, required bool wasCompressed}) {
  if (sizeBytes <= petVideoMaxBytes) return const PetVideoCheck.ok();
  final megabytes = _megabytes(sizeBytes);
  return PetVideoCheck.rejected(
    PetVideoRejection.tooBig,
    wasCompressed
        ? appL10n.petsMediaVideoTooBigReduced(megabytes, _maxMegabytes)
        : appL10n.petsMediaVideoTooBigNotReduced(megabytes, _maxMegabytes),
  );
}

/// "0:07", "0:30" - for the badge on a video tile.
String petVideoDurationLabel(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  return '${safe ~/ 60}:${(safe % 60).toString().padLeft(2, '0')}';
}
