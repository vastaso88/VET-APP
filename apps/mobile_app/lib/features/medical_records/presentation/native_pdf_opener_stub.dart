import 'dart:typed_data';

import 'pdf_open_outcome.dart';

/// No native viewer on web: the caller falls back to the browser/share path.
Future<PdfOpenOutcome> openPdfNatively(Uint8List bytes, String name) async =>
    PdfOpenOutcome.unsupported;
