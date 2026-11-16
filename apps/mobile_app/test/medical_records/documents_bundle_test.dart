import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/documents_bundle.dart';

MedicalRecordEntry _record(String id, String title) => MedicalRecordEntry(
      id: id,
      petName: 'Micio',
      title: title,
      subtitle: '',
      meta: '',
      badge: '',
      detailSource: '',
      createdAt: '2026-11-01',
      timeline: const [],
      attachmentId: 'att-$id',
    );

Uint8List _png() => Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

Uint8List _pdf() => Uint8List.fromList('%PDF-1.4 fake'.codeUnits);

void main() {
  test('a photo is one page, a PDF is one page per sheet', () async {
    final files = {'1': _png(), '2': _pdf()};
    final result = await collectDocumentPages(
      [_record('1', 'Foto.png'), _record('2', 'Esami.pdf')],
      loadBytes: (record) async => files[record.id],
      rasterize: (_) async => [_png(), _png(), _png()],
    );

    expect(result.pages.map((page) => page.title),
        ['Foto.png', 'Esami.pdf (1/3)', 'Esami.pdf (2/3)', 'Esami.pdf (3/3)']);
    expect(result.separate, isEmpty);
    expect(result.missing, 0);
  });

  test('a PDF that cannot be drawn goes beside, the rest still goes in', () async {
    final files = {'1': _pdf(), '2': _png()};
    final result = await collectDocumentPages(
      [_record('1', 'Protetto.pdf'), _record('2', 'Foto.png')],
      loadBytes: (record) async => files[record.id],
      rasterize: (_) async => throw StateError('protected'),
    );

    expect(result.pages.map((page) => page.title), ['Foto.png']);
    expect(result.separateNames, ['Protetto.pdf']);
  });

  test('an unreadable file is counted, not fatal', () async {
    final result = await collectDocumentPages(
      [_record('1', 'Assente.pdf')],
      loadBytes: (_) async => null,
      rasterize: (_) async => [_png()],
    );

    expect(result.missing, 1);
    expect(result.pages, isEmpty);
    expect(result.separate, isEmpty);
  });

  test('past the page limit a whole document goes beside, never cut', () async {
    final result = await collectDocumentPages(
      [_record('1', 'Uno.pdf'), _record('2', 'Due.pdf')],
      loadBytes: (_) async => _pdf(),
      rasterize: (_) async => [_png(), _png()],
      maxPages: 3,
    );

    expect(result.pages, hasLength(2));
    expect(result.separateNames, ['Due.pdf']);
  });

  test('an unknown format goes beside', () async {
    final result = await collectDocumentPages(
      [_record('1', 'Cartella.zip')],
      loadBytes: (_) async => Uint8List.fromList([1, 2, 3, 4]),
      rasterize: (_) async => [_png()],
    );

    expect(result.pages, isEmpty);
    expect(result.separate, hasLength(1));
  });
}
