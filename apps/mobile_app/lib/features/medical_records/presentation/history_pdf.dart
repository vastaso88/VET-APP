import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../l10n/app_localizations.dart';
import '../../../l10n/date_formats.dart';
import '../../pets/domain/pet_format.dart';
import '../../pets/domain/pet_models.dart';
import '../../pets/domain/pet_value_labels.dart';
import '../domain/history_event.dart';
import 'history_labels.dart';

/// One line of the exported history: "Data – categoria – Titolo – Note".
class HistoryPdfRow {
  const HistoryPdfRow({
    required this.symbolKey,
    required this.date,
    required this.category,
    required this.title,
    required this.notes,
    this.subtype,
  });

  /// Which rendered symbol goes before the category (see [historySymbolKey]).
  final String symbolKey;
  final String date;
  final String category;
  final String? subtype;
  final String title;
  final String notes;

  /// The row as one line of text, in the order the columns have.
  String get line =>
      [date, category, title, if (notes.isNotEmpty) notes].join(' – ');
}

/// The rows of the export: every event, oldest first, undated ones first.
List<HistoryPdfRow> buildHistoryPdfRows(
    List<HistoryEvent> events, AppLocalizations l10n) {
  final sorted = [...events]..sort(compareHistoryEvents);
  return [
    for (final event in sorted)
      HistoryPdfRow(
        symbolKey: historySymbolKey(event),
        date: event.date == null
            ? l10n.medPdfNoDate
            : formatAppDate(event.date!, 'd MMM y'),
        category: event.categoryLabel(l10n),
        subtype: event.subtypeLabel(l10n),
        title: event.title.trim(),
        notes: event.notesText(l10n),
      ),
  ];
}

/// The file name of the export, e.g. "Storico_Moka_2026-10-21.pdf".
String historyPdfFileName(String petName, DateTime exportedAt) {
  final ascii = petName
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final day = '${exportedAt.year.toString().padLeft(4, '0')}-'
      '${exportedAt.month.toString().padLeft(2, '0')}-'
      '${exportedAt.day.toString().padLeft(2, '0')}';
  return 'Storico_${ascii.isEmpty ? 'pet' : ascii}_$day.pdf';
}

/// [input] with only what the PDF's built-in font can draw (Latin-1): typographic
/// punctuation is turned into its plain form and anything else into "?", so a
/// stray emoji in a title cannot break the export or print a blank.
String pdfSafeText(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    switch (rune) {
      case 0x0A:
        out.write('\n');
      case 0x09:
      case 0x0D:
      case 0xA0:
      case 0x2009:
      case 0x202F:
        out.write(' ');
      case 0x2013:
      case 0x2014:
      case 0x2212:
        out.write('-');
      case 0x2018:
      case 0x2019:
        out.write("'");
      case 0x201C:
      case 0x201D:
        out.write('"');
      case 0x2026:
        out.write('...');
      case 0x20AC:
        out.write('EUR');
      case 0x2022:
        out.write('-');
      default:
        final isControl = rune < 0x20 || (rune >= 0x7F && rune <= 0x9F);
        if ((rune >= 0x20 && rune <= 0x7E) || (rune >= 0xA1 && rune <= 0xFF)) {
          out.writeCharCode(rune);
        } else if (!isControl) {
          // Other scripts and emoji: shown as "?" (control characters vanish).
          out.write('?');
        }
    }
  }
  return out.toString();
}

String _clip(String text, int max) =>
    text.length <= max ? text : '${text.substring(0, max - 3)}...';

const _maxTitleLength = 300;
const _maxNotesLength = 1200;

/// The PDF with the whole history of [pet]: a header (name, species and
/// breed, birth date, export date) and every event in ascending date order.
///
/// Built entirely on the device; [symbols] are the PNGs of the category icons
/// by [HistoryPdfRow.symbolKey] (a missing one just leaves the symbol out).
Future<Uint8List> buildHistoryPdf({
  required PetProfile pet,
  required List<HistoryEvent> events,
  required DateTime exportedAt,
  required AppLocalizations l10n,
  Map<String, Uint8List> symbols = const {},
  bool compress = true,
}) async {
  final rows = buildHistoryPdfRows(events, l10n);
  final images = <String, pw.MemoryImage>{
    for (final entry in symbols.entries) entry.key: pw.MemoryImage(entry.value),
  };

  final speciesBreed = [
    localizedSpeciesLabel(pet.species),
    if (pet.isAquarium || pet.breed.trim().isNotEmpty) pet.breedLabel,
  ].join(' · ');
  final birth = petBirthDateDisplayLabel(pet.birthDateLabel);
  final exportDate = formatAppDate(exportedAt, 'd MMM y');

  const ink = PdfColor.fromInt(0xFF1F2A24);
  const muted = PdfColor.fromInt(0xFF5F6B64);
  const rule = PdfColor.fromInt(0xFFD5DBD7);

  final regular = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();
  final doc = pw.Document(
    compress: compress,
    title: pdfSafeText(l10n.medPdfTitle(pet.name)),
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  pw.Widget headerLine(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 3),
        child: pw.RichText(
          text: pw.TextSpan(
            style: const pw.TextStyle(fontSize: 10, color: ink),
            children: [
              pw.TextSpan(
                text: '${pdfSafeText(label)}: ',
                style: pw.TextStyle(font: bold, color: muted),
              ),
              pw.TextSpan(text: pdfSafeText(value)),
            ],
          ),
        ),
      );

  pw.Widget cell(pw.Widget child) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: child);

  pw.Widget headCell(String text) => cell(
        pw.Text(
          pdfSafeText(text),
          style: pw.TextStyle(font: bold, fontSize: 9, color: muted),
        ),
      );

  pw.Widget categoryCell(HistoryPdfRow row) {
    final image = images[row.symbolKey];
    return cell(
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (image != null) ...[
            pw.Image(image, width: 11, height: 11),
            pw.SizedBox(width: 4),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  pdfSafeText(row.category),
                  style: pw.TextStyle(font: bold, fontSize: 9.5, color: ink),
                ),
                if (row.subtype != null)
                  pw.Text(
                    pdfSafeText(row.subtype!),
                    style: const pw.TextStyle(fontSize: 8, color: muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.TableRow dataRow(HistoryPdfRow row) => pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.top,
        children: [
          cell(
            pw.Text(
              pdfSafeText(row.date),
              style: const pw.TextStyle(fontSize: 9.5, color: ink),
            ),
          ),
          categoryCell(row),
          cell(
            pw.Text(
              pdfSafeText(_clip(row.title, _maxTitleLength)),
              style: pw.TextStyle(font: bold, fontSize: 9.5, color: ink),
            ),
          ),
          cell(
            pw.Text(
              pdfSafeText(_clip(row.notes, _maxNotesLength)),
              style: const pw.TextStyle(fontSize: 9, color: ink),
            ),
          ),
        ],
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      // A long history is many pages; the default stops at 20.
      maxPages: 1000,
      margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 44),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          pdfSafeText(l10n.medPdfPage(context.pageNumber, context.pagesCount)),
          style: const pw.TextStyle(fontSize: 8, color: muted),
        ),
      ),
      build: (context) => [
        pw.Text(
          pdfSafeText(l10n.medPdfTitle(pet.name)),
          style: pw.TextStyle(font: bold, fontSize: 18, color: ink),
        ),
        pw.SizedBox(height: 6),
        headerLine(l10n.medPdfSpeciesBreed, speciesBreed),
        if (birth.isNotEmpty) headerLine(l10n.medPdfBirthDate, birth),
        headerLine(l10n.medPdfExportDate, exportDate),
        pw.SizedBox(height: 10),
        pw.Divider(color: rule, thickness: 1),
        pw.SizedBox(height: 4),
        if (rows.isEmpty)
          pw.Text(
            pdfSafeText(l10n.medPdfEmpty),
            style: const pw.TextStyle(fontSize: 10, color: muted),
          )
        else
          pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(66),
              1: pw.FixedColumnWidth(92),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(3),
            },
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: rule, width: 0.5),
              bottom: pw.BorderSide(color: rule, width: 0.5),
            ),
            children: [
              pw.TableRow(
                repeat: true,
                children: [
                  headCell(l10n.medPdfColDate),
                  headCell(l10n.medPdfColCategory),
                  headCell(l10n.medPdfColTitle),
                  headCell(l10n.medPdfColNotes),
                ],
              ),
              for (final row in rows) dataRow(row),
            ],
          ),
      ],
    ),
  );

  return doc.save();
}
