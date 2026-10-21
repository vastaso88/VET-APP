import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';
import 'package:vet_app_mobile/features/medical_records/domain/history_event.dart';
import 'package:vet_app_mobile/features/medical_records/domain/pet_condition.dart';
import 'package:vet_app_mobile/features/medical_records/domain/record_category.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/history_export.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/history_pdf.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

MedicalRecordEntry _record(
  String id,
  String title,
  RecordCategory category,
  DateTime? eventDate, {
  String notes = '',
  String? subtype,
}) => MedicalRecordEntry(
  id: id,
  petName: 'Moka',
  title: title,
  subtitle: '',
  meta: '',
  badge: '',
  detailSource: '',
  createdAt: '',
  category: category,
  subtype: subtype,
  eventDate: eventDate,
  notes: notes,
  timeline: const [],
);

/// The words the PDF draws, in drawing order, separated by one space (the page
/// numbers at the foot excluded).
String _pdfText(Uint8List bytes) {
  final content = latin1.decode(bytes);
  final words = RegExp(r'\[\(((?:\\.|[^\\)])*)\)\]TJ')
      .allMatches(content)
      .map((m) => m.group(1)!.replaceAllMapped(RegExp(r'\\(.)'), (e) => e.group(1)!))
      .toList();
  // The footer is drawn first ("Pagina 1 di 1").
  final footer = words.indexOf('Pagina');
  if (footer != -1) words.removeRange(footer, footer + 4);
  return words.join(' ');
}

void main() {
  final l10n = appL10n;
  final moka = samplePets.firstWhere((pet) => pet.name == 'Moka');

  // Deliberately out of order, with an illness among the records.
  final events = buildHistoryEvents(
    records: [
      _record('3', 'Richiamo rabbia', RecordCategory.vaccine, DateTime(2026, 9, 3), notes: 'Lotto 42'),
      _record('1', 'Visita di controllo', RecordCategory.visit, DateTime(2026, 1, 15)),
      _record('2', 'Emocromo', RecordCategory.exam, DateTime(2026, 5, 20), subtype: 'blood'),
      _record('4', 'Antibiotico', RecordCategory.therapy, DateTime(2026, 5, 20), notes: 'Due volte al giorno'),
    ],
    conditions: [
      PetConditionEntry(
        id: 'c',
        petId: 'pet-moka',
        name: 'Otite',
        startedOn: DateTime(2026, 5, 18),
        therapy: 'Gocce auricolari',
        notes: 'Orecchio destro',
      ),
    ],
  );

  group('rows', () {
    test('every event once, oldest first, whatever order they come in', () {
      final shuffled = events.reversed.toList();

      final rows = buildHistoryPdfRows(shuffled, l10n);

      expect(rows.map((r) => r.title), [
        'Visita di controllo',
        'Otite',
        'Emocromo',
        'Antibiotico',
        'Richiamo rabbia',
      ]);
    });

    test('each row reads "data – categoria – titolo – note"', () {
      final rows = buildHistoryPdfRows(events, l10n);

      expect(rows[0].line, '15 gen 2026 – Visita – Visita di controllo');
      expect(rows[1].line, '18 mag 2026 – Patologia – Otite – In corso · Terapia: Gocce auricolari · Orecchio destro');
      expect(rows[2].line, '20 mag 2026 – Esame – Emocromo');
      expect(rows[2].subtype, 'Analisi del sangue');
      expect(rows[3].line, '20 mag 2026 – Terapia – Antibiotico – Due volte al giorno');
      expect(rows[4].line, '3 set 2026 – Vaccino – Richiamo rabbia – Lotto 42');
    });

    test('an entry with no date goes first and says so', () {
      final rows = buildHistoryPdfRows(
        buildHistoryEvents(
          records: [
            _record('a', 'Con data', RecordCategory.visit, DateTime(2026, 2, 2)),
            _record('b', 'Senza data', RecordCategory.document, null),
          ],
          conditions: const [],
        ),
        l10n,
      );

      expect(rows.first.title, 'Senza data');
      expect(rows.first.date, 'Senza data');
    });

    test('a resolved illness says when it ended', () {
      final rows = buildHistoryPdfRows(
        buildHistoryEvents(
          records: const [],
          conditions: [
            PetConditionEntry(
              id: 'r',
              petId: 'pet-moka',
              name: 'Gastrite',
              startedOn: DateTime(2025, 11, 2),
              ongoing: false,
              endedOn: DateTime(2025, 11, 20),
            ),
          ],
        ),
        l10n,
      );

      expect(rows.single.notes, 'Risolta il 20 nov 2025');
    });
  });

  group('the file', () {
    test('is a PDF with the pet and the export date in its header', () async {
      final bytes = await buildHistoryPdf(
        pet: moka,
        events: events,
        exportedAt: DateTime(2026, 10, 21),
        l10n: l10n,
        compress: false,
      );

      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
      final text = _pdfText(bytes);
      expect(
        text,
        startsWith(
          'Storico clinico di Moka '
          'Specie e razza: Cane · Meticcio di taglia media '
          'Data di nascita: mag 2021 '
          'Data di esportazione: 21 ott 2026 '
          'Data Categoria Titolo Note ',
        ),
      );
    });

    test('lists every event in ascending date order, each as date, category, title, notes', () async {
      final bytes = await buildHistoryPdf(
        pet: moka,
        events: events.reversed.toList(),
        exportedAt: DateTime(2026, 10, 21),
        l10n: l10n,
        compress: false,
      );

      final text = _pdfText(bytes);
      final rows = [
        '15 gen 2026 Visita Visita di controllo',
        '18 mag 2026 Patologia Otite In corso · Terapia: Gocce auricolari · Orecchio destro',
        '20 mag 2026 Esame Analisi del sangue Emocromo',
        '20 mag 2026 Terapia Antibiotico Due volte al giorno',
        '3 set 2026 Vaccino Richiamo rabbia Lotto 42',
      ];
      var from = 0;
      for (final row in rows) {
        final at = text.indexOf(row, from);
        expect(at, isNonNegative, reason: row);
        from = at + row.length;
      }
    });

    test('is still valid with no events and with a very long list', () async {
      final empty = await buildHistoryPdf(
        pet: moka,
        events: const [],
        exportedAt: DateTime(2026, 10, 21),
        l10n: l10n,
      );
      expect(latin1.decode(empty.sublist(0, 5)), '%PDF-');

      final many = buildHistoryEvents(
        records: [
          for (var i = 0; i < 200; i++)
            _record('m$i', 'Voce $i', RecordCategory.values[i % 5], DateTime(2025, 1, 1 + i % 28), notes: 'nota ' * 80),
        ],
        conditions: const [],
      );
      final long = await buildHistoryPdf(
        pet: moka,
        events: many,
        exportedAt: DateTime(2026, 10, 21),
        l10n: l10n,
      );
      expect(long.length, greaterThan(empty.length));
    });

    test('names with accents, quotes and emoji cannot break it', () async {
      final tricky = buildHistoryEvents(
        records: [_record('x', 'Perché “così” – 🐶 ƒ', RecordCategory.visit, DateTime(2026, 1, 1))],
        conditions: const [],
      );
      final bytes = await buildHistoryPdf(
        pet: moka.copyWith(name: 'Fido 🐕'),
        events: tricky,
        exportedAt: DateTime(2026, 10, 21),
        l10n: l10n,
      );
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('pdfSafeText keeps Latin-1 and tames the rest', () {
      expect(pdfSafeText('Perché è già così'), 'Perché è già così');
      expect(pdfSafeText('“a” – ‘b’ … 5 €'), '"a" - \'b\' ... 5 EUR');
      expect(pdfSafeText('cane 🐶'), 'cane ?');
      expect(pdfSafeText('a\tb\u0000c\nd'), 'a bc\nd');
    });

    test('is named after the pet and the day', () {
      expect(historyPdfFileName('Moka', DateTime(2026, 10, 21)), 'Storico_Moka_2026-10-21.pdf');
      expect(historyPdfFileName('Fido Il Grande ✨', DateTime(2026, 1, 2)), 'Storico_Fido-Il-Grande_2026-01-02.pdf');
      expect(historyPdfFileName('🐕', DateTime(2026, 1, 2)), 'Storico_pet_2026-01-02.pdf');
    });
  });

  group('sharing', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('history_export_test'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('writes a temporary file for the share sheet and deletes it afterwards', () async {
      final bytes = Uint8List.fromList(utf8.encode('%PDF-test'));
      String? seenPath;
      Uint8List? seenContent;
      String? seenMime;

      await sharePdfThenDelete(
        bytes,
        'Storico_Moka_2026-10-21.pdf',
        tempDir: () async => temp,
        grace: Duration.zero,
        share: (XFile file) async {
          seenPath = file.path;
          seenMime = file.mimeType;
          seenContent = File(file.path).readAsBytesSync();
        },
      );

      expect(seenContent, bytes);
      expect(seenMime, 'application/pdf');
      expect(seenPath, startsWith(temp.path));
      expect(File(seenPath!).existsSync(), isFalse);
    });

    test('deletes the file even when sharing fails, and clears older leftovers', () async {
      final folder = Directory('${temp.path}${Platform.pathSeparator}vetapp_export')..createSync();
      File('${folder.path}${Platform.pathSeparator}vecchio.pdf').writeAsStringSync('old');

      await expectLater(
        sharePdfThenDelete(
          Uint8List.fromList([1, 2, 3]),
          'nuovo.pdf',
          tempDir: () async => temp,
          grace: Duration.zero,
          share: (_) async => throw StateError('no share target'),
        ),
        throwsStateError,
      );

      expect(folder.listSync(), isEmpty);
    });
  });

  testWidgets('the category icons of the page are drawn as PNGs for the PDF', (tester) async {
    final symbols = (await tester.runAsync(renderHistorySymbols))!;

    expect(symbols.keys, containsAll(['visit', 'exam', 'vaccine', 'therapy', 'document', 'condition']));
    for (final png in symbols.values) {
      expect(png.sublist(1, 4), 'PNG'.codeUnits);
    }

    // And the PDF carries them.
    final withSymbols = await tester.runAsync(
      () => buildHistoryPdf(
        pet: moka,
        events: events,
        exportedAt: DateTime(2026, 10, 21),
        l10n: l10n,
        symbols: symbols,
      ),
    );
    final without = await buildHistoryPdf(
      pet: moka,
      events: events,
      exportedAt: DateTime(2026, 10, 21),
      l10n: l10n,
    );
    expect(withSymbols!.length, greaterThan(without.length));
  });
}
