import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/marketplace/domain/content_policy.dart';

void main() {
  test('phone numbers, e-mails, websites and handles are contact details', () {
    for (final text in [
      'Chiamami al 3331234567 o scrivi a davide@example.com',
      'Tel. 333 123 4567',
      '+39 02 1234567 dopo le 18',
      'instagram @milo_il_beagle',
      'vedi www.esempio.it',
      'https://esempio.com/annuncio',
      'sito esempio.it per le foto',
    ]) {
      expect(containsContactDetails(text), isTrue, reason: text);
    }
  });

  test('sizes, prices and dates are not', () {
    for (final text in [
      'Cuccia 60x40x36 cm, usata nel 2024',
      'Prezzo 25,90, trattabile',
      'Guinzaglio 1.5 m, taglia M',
      'Sacco da 12 kg scadenza 03/2027',
      null,
      '',
    ]) {
      expect(containsContactDetails(text), isFalse, reason: '$text');
    }
  });
}
