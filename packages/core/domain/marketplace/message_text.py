"""The text of a private message of the Mercatino (owner decision 2026-11-25, F27).

* [clean_message_text] takes out what nobody can see: zero-width characters, the ones
  that turn the writing direction around, control characters, blank fillers. It runs
  before a message is saved and again before it is shown, for what was saved earlier.
  Visible text is never changed: `<b>` stays `<b>`, and the app shows it as text.
* [needs_caution] says whether a message carries a contact (phone, e-mail, link) or a
  code. It never blocks: contacts between the two are allowed (owner decision
  2026-11-08), the app only adds a reminder. Nothing is stored, and the answer is a yes
  or no, never the part of the text that matched.

Fixed rules, no provider. The Dart port of [needs_caution] is in
apps/mobile_app/lib/features/marketplace/domain/message_caution.dart; the cases both must
agree on are in tests/fixtures/marketplace_message_caution_cases.json.
"""

from __future__ import annotations

import re
import unicodedata

from packages.core.domain.marketplace.animal_policy import normalize_text
from packages.core.domain.marketplace.content_policy import contains_address, phone_candidates

# --- hidden characters -------------------------------------------------------

_ZWJ = "\u200d"
_VARIATION = frozenset("\ufe0e\ufe0f")
# Invisible although Unicode does not call them format characters: grapheme joiner,
# Hangul, Khmer and Braille blanks, the object placeholder.
_BLANKS = frozenset("\u034f\u115f\u1160\u17b4\u17b5\u2800\u3164\uffa0\ufffc")
_SPACING = frozenset("\t\n\r\x0b\x0c\x85\u2028\u2029")
_LINE_ENDS = re.compile("\r\n?|[\x0b\x0c\x85\u2028\u2029]")
# Nearly every message: letters, signs and new lines with nothing to take out.
_PLAIN = re.compile("[\n\x20-\x7e\xa0-\xac\xae-\u024f\u2013-\u2026\u20ac]*")
# The only good use of tag characters: the flags of England, Scotland and Wales.
_TAGGED_FLAG = re.compile("\U0001f3f4[\U000e0030-\U000e0039\U000e0061-\U000e007a]{2,6}\U000e007f")


def clean_message_text(text: str) -> str:
    """[text] without the characters nobody can see. Emoji made of several characters
    stay whole. Running it twice changes nothing more."""
    if _PLAIN.fullmatch(text):
        return text.strip()
    flags = {
        at for match in _TAGGED_FLAG.finditer(text) for at in range(match.start(), match.end())
    }
    visible = [
        char for at, char in enumerate(text) if at in flags or char in _SPACING or not _hidden(char)
    ]
    kept: list[str] = []
    for at, char in enumerate(visible):
        following = visible[at + 1] if at + 1 < len(visible) else ""
        if char == _ZWJ and not (kept and _emoji_part(kept[-1]) and _pictograph(following)):
            continue
        if char in _VARIATION and not (kept and _takes_variation(kept[-1])):
            continue
        kept.append(char)
    return _LINE_ENDS.sub("\n", "".join(kept)).replace("\t", " ").strip()


def _hidden(char: str) -> bool:
    code = ord(char)
    if char == _ZWJ or char in _VARIATION:
        return False  # it depends on what stands next to them
    if char in _BLANKS or 0xFE00 <= code <= 0xFE0D or 0xE0100 <= code <= 0xE01EF:
        return True
    if 0x180B <= code <= 0x180F or 0xFDD0 <= code <= 0xFDEF or code & 0xFFFE == 0xFFFE:
        return True
    return unicodedata.category(char) in {"Cc", "Cf", "Cs"}


def _pictograph(char: str) -> bool:
    # From 1F000 on also the ones this Python does not know yet.
    return bool(char) and (unicodedata.category(char) == "So" or 0x1F000 <= ord(char) <= 0x1FAFF)


def _emoji_part(char: str) -> bool:
    return char in _VARIATION or _pictograph(char)


def _takes_variation(char: str) -> bool:
    # A symbol or a digit of a keycap: never a letter, a blank or another variation.
    return _pictograph(char) or unicodedata.category(char)[0] in "SNP"


# --- contacts and codes ------------------------------------------------------

# Dates and times are long rows of digits too: "25/11/2026", "10.30 - 11.00". An ad has
# none, a message that fixes a meeting does.
# Day first, or month first with slashes as in the United States.
_DAY = (
    r"(?:(?:0?[1-9]|[12][0-9]|3[01])[./-](?:0?[1-9]|1[0-2])"
    r"|(?:0?[1-9]|1[0-2])/(?:0?[1-9]|[12][0-9]|3[01]))"
)
_MOMENT = (
    rf"(?:{_DAY}[./-](?:(?:19|20)[0-9][0-9]|[0-9][0-9])|(?:19|20)[0-9][0-9]-[0-9][0-9]-[0-9][0-9]"
    rf"|{_DAY}|(?:[01]?[0-9]|2[0-3])\.[0-5][0-9])"
)
# At most eight of them: "10.10" reads both as a day and as a time, so without a limit the
# ways to read a row double at every step and one message keeps the server busy for hours.
_WHEN = re.compile(rf"{_MOMENT}(?:(?:\s+|\s*[/-]\s*){_MOMENT}){{0,7}}")
_CLOCK = re.compile(r"(?<=[0-9]):(?=[0-9])")
# A short link without "http": "bit.ly/abc", "t.me/name".
_SHORT_LINK = re.compile(r"\b[a-z0-9-]{1,63}\.[a-z]{2,10}/[a-z0-9]", re.IGNORECASE)

# The rules below read a normalised text: lowercase, no accents, one space between words.
_CODE = (
    r"(?<!zip )(?<!post )(?<!postal )(?<!discount )(?<!promo )(?<!item )(?<!product )"
    r"\b(?:codic[ei]|codes?|codigos?|pin|clave|password|passwort|kennwort|contrasena"
    r"|mot de passe)\b"
    r"(?! (?:postale?|articolo|prodotto|sconto|fiscale|a barre|article|articulo|producto|produit"
    r"|promo|descuento|de barras|barres|qr)\b)"
)
_DIGITS = r"\b[0-9](?: ?[0-9]){3,7}\b"
_PROOF = (
    r"(?:verif|conferm|confirm|sicurezza|securit|segurid|sicherheit|bestatig|sms\b|whatsapp\b"
    r"|accesso\b|access\b|acceso\b|acces\b|zugang)"
)
_CODES = re.compile(
    r"\b(?:otp|cv[vc]2?|passcodes?"
    r"|(?:bestatigungs|sicherheits|verifizierungs|zugangs|einmal|sms)codes?)\b"
    rf"|{_CODE} [a-z ]{{0,25}}{_DIGITS}"
    rf"|{_DIGITS} [a-z ]{{0,25}}{_CODE}"
    rf"|{_CODE} [a-z ]{{0,25}}\b{_PROOF}"
    rf"|\b{_PROOF}[a-z]* [a-z ]{{0,15}}{_CODE}"
)
# A message that is only six digits, as codes usually arrive: "482 913", "G-482913".
_BARE_CODE = re.compile(r"(?:[a-z] )?[0-9]{3} ?[0-9]{3}")


def needs_caution(text: str) -> bool:
    """True when [text] carries a phone number, an e-mail, a link or a social handle, or a
    code or the request of one. Card and IBAN numbers are long enough to count as numbers."""
    # Digits in other shapes (full width, keycaps) read as plain ones.
    plain = unicodedata.normalize("NFKC", clean_message_text(text))
    plain = plain.replace("\ufe0f", "").replace("\u20e3", "")
    if contains_address(plain) or _SHORT_LINK.search(plain):
        return True
    runs = phone_candidates(_CLOCK.sub(".", plain))
    if any(not _WHEN.fullmatch(run.strip(" \n./-")) for run in runs):
        return True
    words = normalize_text(plain)
    return bool(_CODES.search(words) or _BARE_CODE.fullmatch(words))
