import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/files/attachment_media_type.dart';
import '../data/medical_records_repository.dart';
import 'history_pdf.dart';
import 'record_file_actions.dart';

/// What the documents of a pet become when they are sent as ONE PDF: pages that
/// go inside it, files that could not and travel beside it, and how many
/// documents could not even be read.
class CollectedDocuments {
  const CollectedDocuments({
    this.pages = const [],
    this.separate = const [],
    this.separateNames = const [],
    this.missing = 0,
  });

  final List<HistoryPdfAttachmentPage> pages;
  final List<XFile> separate;

  /// The names of [separate], in the same order.
  final List<String> separateNames;
  final int missing;
}

/// Reading size of a rasterised PDF page: sharp enough to read a printed
/// report, light enough for a mail attachment.
const documentRasterDpi = 150.0;

/// Pages of documents accepted in one PDF; whatever is past it goes beside.
const maxDocumentPages = 80;

typedef DocumentRasterizer = Future<List<Uint8List>> Function(Uint8List pdf);

Future<List<Uint8List>> _rasterizePdf(Uint8List pdf) async {
  final pages = <Uint8List>[];
  await for (final page in Printing.raster(pdf, dpi: documentRasterDpi)) {
    pages.add(await page.toPng());
  }
  return pages;
}

/// Puts the files of [records] in the order of the list: a photo becomes a
/// page, a PDF becomes one page per sheet. A file that cannot go inside (a
/// protected or broken PDF, an unknown format, no room left) is kept as it is
/// to be sent beside the PDF. Never throws for a single bad file.
Future<CollectedDocuments> collectDocumentPages(
  List<MedicalRecordEntry> records, {
  Future<Uint8List?> Function(MedicalRecordEntry record)? loadBytes,
  DocumentRasterizer? rasterize,
  int maxPages = maxDocumentPages,
}) async {
  final load = loadBytes ?? loadRecordBytes;
  final raster = rasterize ?? _rasterizePdf;
  final pages = <HistoryPdfAttachmentPage>[];
  final separate = <XFile>[];
  final separateNames = <String>[];
  var missing = 0;

  for (final record in records) {
    if (!recordHasFile(record)) continue;
    final Uint8List? bytes;
    try {
      bytes = await load(record);
    } catch (_) {
      missing++;
      continue;
    }
    if (bytes == null || bytes.isEmpty) {
      missing++;
      continue;
    }
    final type = attachmentMediaType(bytes, record.title);
    final mime = type.toString();
    final List<Uint8List>? images = await _imagesOf(type.type, type.subtype, bytes, raster);
    if (images == null || images.isEmpty || pages.length + images.length > maxPages) {
      separate.add(XFile.fromData(bytes, name: record.title, mimeType: mime));
      separateNames.add(record.title);
      continue;
    }
    for (var i = 0; i < images.length; i++) {
      pages.add(HistoryPdfAttachmentPage(
        title: images.length == 1 ? record.title : '${record.title} (${i + 1}/${images.length})',
        imageBytes: images[i],
      ));
    }
  }
  return CollectedDocuments(
    pages: pages,
    separate: separate,
    separateNames: separateNames,
    missing: missing,
  );
}

/// The page images of one file, or null when it cannot be put in the PDF.
Future<List<Uint8List>?> _imagesOf(
  String type,
  String subtype,
  Uint8List bytes,
  DocumentRasterizer raster,
) async {
  try {
    if (type == 'image') {
      if (subtype == 'jpeg' || subtype == 'png') return [bytes];
      // Other formats (webp, heic...): redrawn as PNG when the app can read them.
      final decoded = img.decodeImage(bytes);
      return decoded == null ? null : [Uint8List.fromList(img.encodePng(decoded))];
    }
    if (subtype == 'pdf') return await raster(bytes);
  } catch (_) {
    return null;
  }
  return null;
}
