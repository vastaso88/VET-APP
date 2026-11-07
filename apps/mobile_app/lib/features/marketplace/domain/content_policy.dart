// What a Mercatino ad may not contain besides animals (see animal_policy.dart):
// contact details in the public text. Dart port of
// packages/core/domain/marketplace/content_policy.py, same expressions, so
// the form can say it before the photos are uploaded - the backend is still
// the one that decides.

/// What the backend answers (400) when it refuses contact details.
const contactPolicyBackendMessage =
    "Nell'annuncio non inserire telefoni, email, siti web o profili social.";

/// What the backend answers (400) when it refuses a medicine.
const medicinePolicyBackendMessage =
    'Sul Mercatino non si possono vendere farmaci o medicinali veterinari, '
    'nemmeno senza ricetta.';

// Seven or more digits with spaces, dots, slashes or dashes in between.
final _phone = RegExp(r'(?:\d[\s./-]*){7,}');
final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
final _handle = RegExp(r'(?<![\w.])@[A-Za-z0-9_.]{2,}');
final _web = RegExp(
  r'https?://|www\.|\b[a-z0-9-]+\.(?:it|com|net|org|eu|info|de|fr|es|uk|us|au|ch|at|be|ie|io|app)\b',
  caseSensitive: false,
);

/// True when [text] carries a phone number, an e-mail, a web address or a
/// social handle.
bool containsContactDetails(String? text) {
  if (text == null || text.isEmpty) return false;
  return _email.hasMatch(text) ||
      _handle.hasMatch(text) ||
      _web.hasMatch(text) ||
      _phone.hasMatch(text);
}
