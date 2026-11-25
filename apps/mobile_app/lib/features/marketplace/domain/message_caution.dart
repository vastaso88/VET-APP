// Whether a message of the Mercatino carries a contact or a code. Dart port of
// needs_caution in packages/core/domain/marketplace/message_text.py, same
// expressions, so the reminder comes while one is writing, before a code has
// left; for the messages already sent the backend says it. Nothing is blocked.
// Shared cases: tests/fixtures/marketplace_message_caution_cases.json.

import 'animal_policy.dart';
import 'content_policy.dart';

// Dates and times are long rows of digits too: "25/11/2026", "10.30 - 11.00".
// Day first, or month first with slashes as in the United States.
const _day = r'(?:(?:0?[1-9]|[12][0-9]|3[01])[./-](?:0?[1-9]|1[0-2])'
    r'|(?:0?[1-9]|1[0-2])/(?:0?[1-9]|[12][0-9]|3[01]))';
const _moment = '(?:$_day'
    r'[./-](?:(?:19|20)[0-9][0-9]|[0-9][0-9])|(?:19|20)[0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
    '|$_day'
    r'|(?:[01]?[0-9]|2[0-3])\.[0-5][0-9])';
final _when = RegExp('^$_moment(?:(?:\\s+|\\s*[/-]\\s*)$_moment)*\$');
final _clock = RegExp(r'(?<=[0-9]):(?=[0-9])');
final _edges = RegExp(r'^[ \n./-]+|[ \n./-]+$');
// A short link without "http": "bit.ly/abc", "t.me/name".
final _shortLink = RegExp(r'\b[a-z0-9-]{1,63}\.[a-z]{2,10}/[a-z0-9]', caseSensitive: false);

// The rules below read a normalised text: lowercase, no accents, one space
// between words.
const _code =
    r'(?<!zip )(?<!post )(?<!postal )(?<!discount )(?<!promo )(?<!item )(?<!product )'
    r'\b(?:codic[ei]|codes?|codigos?|pin|clave|password|passwort|kennwort|contrasena'
    r'|mot de passe)\b'
    r'(?! (?:postale?|articolo|prodotto|sconto|fiscale|a barre|article|articulo|producto|produit'
    r'|promo|descuento|de barras|barres|qr)\b)';
const _digits = r'\b[0-9](?: ?[0-9]){3,7}\b';
const _proof =
    r'(?:verif|conferm|confirm|sicurezza|securit|segurid|sicherheit|bestatig|sms\b|whatsapp\b'
    r'|accesso\b|access\b|acceso\b|acces\b|zugang)';
final _codes = RegExp(
  r'\b(?:otp|cv[vc]2?|passcodes?'
  r'|(?:bestatigungs|sicherheits|verifizierungs|zugangs|einmal|sms)codes?)\b'
  '|$_code [a-z ]{0,25}$_digits'
  '|$_digits [a-z ]{0,25}$_code'
  '|$_code [a-z ]{0,25}\\b$_proof'
  '|\\b$_proof[a-z]* [a-z ]{0,15}$_code',
);
// A message that is only six digits, as codes usually arrive.
final _bareCode = RegExp(r'^(?:[a-z] )?[0-9]{3} ?[0-9]{3}$');

/// True when [text] carries a phone number, an e-mail, a link or a social
/// handle, or a code or the request of one. On a browser too old for these
/// expressions there is no reminder while writing, and the field still works.
bool messageNeedsCaution(String text) {
  try {
    return _needsCaution(text);
  } on FormatException {
    return false;
  }
}

bool _needsCaution(String text) {
  if (containsAddress(text) || _shortLink.hasMatch(text)) return true;
  final runs = phoneCandidates(text.replaceAll(_clock, '.'));
  if (runs.any((run) => !_when.hasMatch(run.replaceAll(_edges, '')))) return true;
  final words = normalizeAnimalPolicyText(text);
  return _codes.hasMatch(words) || _bareCode.hasMatch(words);
}
