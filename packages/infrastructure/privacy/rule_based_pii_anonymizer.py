import re
from dataclasses import dataclass

from packages.core.application.ports.pii_anonymizer import (
    PiiAnonymizationRequest,
    PiiAnonymizationResult,
)

# A separator inside a phone number as people actually write it.
_SEP = r"[\s./-]?"
# A number is only a phone number when it is not part of a longer one: not
# glued to other digits, and not the tail of a decimal ("12,3331234567").
_NOT_AFTER_NUMBER = r"(?<![\d,.])"
_NOT_BEFORE_NUMBER = r"(?![\s./-]?\d)"

_CAPITALIZED = r"[A-ZÀ-Ý][\w'’À-ÿ]*"
_NAME_WORD = r"[A-ZÀ-Ý][a-zà-ÿ'’]+"

# Street words that are also everyday words ("in corso da 3 giorni", "largo
# spettro", "per via orale 2 volte"): an address is only recognised when a
# proper noun, a saint/particle, a roman numeral or a date-style number
# follows — never a lowercase common word.
_STREET_KEYWORD = (
    r"(?:via|viale|v\.le|piazza|p\.zza|piazzale|p\.le|corso|c\.so|largo|vicolo|"
    r"strada|contrada|località|loc\.|lungomare|borgo|salita)"
)
_STREET_NAME = (
    rf"(?:(?:dei|degli|delle|della|dello|del|di|d'|san|santa|sant'|s\.)\s*)?"
    rf"(?:{_CAPITALIZED}|[IVXLC]+\b|\d{{1,2}}\b)"
    rf"(?:\s+(?:(?:dei|degli|delle|della|dello|del|di|d')\s*)?{_CAPITALIZED}){{0,3}}"
)
_CIVIC = r"(?:,?\s*(?:n\.?|n°|civico)?\s*\d{1,4}(?:\s?/?\s?[a-zA-Z]\b)?)"
_CAP_AND_TOWN = (
    rf"(?:,?\s*\d{{5}}(?:\s+{_CAPITALIZED}(?:\s+{_CAPITALIZED})?)?)?"
    r"(?:\s*\([A-Z]{2}\))?"
)


@dataclass(frozen=True)
class _Rule:
    entity: str
    pattern: re.Pattern[str]
    # Which regex group is the personal data (0 = the whole match). Lets a
    # rule keep its label ("Proprietario:") and replace only the value.
    group: int = 0
    # A protecting rule claims its span so that no later rule can redact
    # any part of it, and leaves the text untouched.
    protect: bool = False


_RULES: tuple[_Rule, ...] = (
    # --- protected first: clinically needed, must survive intact ---------
    # ISO microchip: 15 digits, sometimes written in groups of three.
    _Rule("MICROCHIP", re.compile(r"(?<!\d)\d{15}(?!\d)"), protect=True),
    _Rule("MICROCHIP", re.compile(r"(?<!\d)\d{3}(?:[ .]\d{3}){4}(?!\d)"), protect=True),
    # Dates, so no digit rule can ever bite into one.
    _Rule("DATA", re.compile(r"(?<!\d)\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}(?!\d)"), protect=True),
    # --- personal data ---------------------------------------------------
    _Rule("EMAIL", re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")),
    _Rule("URL", re.compile(r"(?:https?://|www\.)[^\s<>\"')]+", re.IGNORECASE)),
    _Rule(
        "URL",
        re.compile(
            r"\b[\w-]+(?:\.[\w-]+)*\.(?:it|com|org|net|eu|info|vet)\b(?:/[^\s<>\"')]*)?",
            re.IGNORECASE,
        ),
    ),
    _Rule("IBAN", re.compile(r"\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){3,7}(?: ?[A-Z0-9]{1,3})?\b")),
    _Rule(
        "CODICE_FISCALE",
        re.compile(r"\b[A-Za-z]{6}\d{2}[ABCDEHLMPRSTabcdehlmprst]\d{2}[A-Za-z]\d{3}[A-Za-z]\b"),
    ),
    # An 11-digit run is a partita IVA (a microchip has 15, an Italian
    # phone number at most 10 plus prefix, and no lab value has 11).
    _Rule("PARTITA_IVA", re.compile(r"(?<![\dA-Za-z])(?:IT)?\d{11}(?!\d)")),
    _Rule(
        "TELEFONO",
        re.compile(
            rf"{_NOT_AFTER_NUMBER}(?:(?:\+|00)39{_SEP})?3\d{{2}}{_SEP}\d{{3}}{_SEP}\d{{3,4}}"
            rf"{_NOT_BEFORE_NUMBER}"
        ),
    ),
    _Rule(
        "TELEFONO",
        re.compile(
            rf"{_NOT_AFTER_NUMBER}(?:(?:\+|00)39{_SEP})?0\d{{1,3}}{_SEP}\d{{5,8}}"
            rf"{_NOT_BEFORE_NUMBER}"
        ),
    ),
    _Rule(
        "INDIRIZZO",
        re.compile(
            rf"\b(?i:{_STREET_KEYWORD})\s+{_STREET_NAME}{_CIVIC}{_CAP_AND_TOWN}",
        ),
    ),
    # A person's name introduced by a label or a title, as it appears on a
    # clinical report. The label stays, only the name goes.
    _Rule(
        "NOME",
        re.compile(
            r"\b(?:Proprietari[oa]|Propr\.|Cliente|Intestatari[oa]|Sig\.ra|Sig\.na|Sig\.|"
            r"Signora|Signor|Dott\.ssa|Dott\.|Dr\.ssa|Dr\.|Medico veterinario|"
            r"Veterinari[oa] curante)"
            # "Medico veterinario: Dott.ssa Laura Bianchi" — label, then title.
            r"\s*:?\s+(?:(?:Sig\.ra|Sig\.na|Sig\.|Dott\.ssa|Dott\.|Dr\.ssa|Dr\.)\s+)?"
            rf"({_NAME_WORD}(?:\s+{_NAME_WORD}){{0,2}})"
        ),
        group=1,
    ),
)

# Too short or too common to be safely replaced as "a known name".
_MIN_NAME_TOKEN_LENGTH = 3
_NAME_STOPWORDS = frozenset(
    {"dei", "del", "della", "delle", "degli", "dello", "van", "von", "the", "san", "santa"}
)


class RuleBasedPiiAnonymizer:
    """Lightweight, dependency-free anonymizer: regular expressions for
    data with a recognisable shape, plus targeted replacement of names
    already known for the request. Runs in-process (nothing leaves for a
    third party) and has no model to load, so it fits a serverless
    runtime — the default backend.

    It deliberately does NOT do name recognition: a person's name that is
    neither known in advance nor introduced by a label/title is left as
    it is. See docs/compliance/02_pii_anonymization.md for the full list
    of what is and is not covered.

    Rules are applied in order and never overlap: clinically needed
    values (microchip numbers, dates) are claimed first, so that no later
    rule can redact part of them.
    """

    def anonymize(self, request: PiiAnonymizationRequest) -> PiiAnonymizationResult:
        text = request.text
        rules = (*_RULES, *self._known_name_rules(request.known_person_names))

        claimed: list[tuple[int, int]] = []
        replacements: list[tuple[int, int, str]] = []
        for rule in rules:
            for match in rule.pattern.finditer(text):
                start, end = match.span(rule.group)
                overlaps = any(start < taken[1] and taken[0] < end for taken in claimed)
                if start == end or overlaps:
                    continue
                claimed.append((start, end))
                if not rule.protect:
                    replacements.append((start, end, rule.entity))

        for start, end, entity in sorted(replacements, reverse=True):
            text = f"{text[:start]}[{entity}]{text[end:]}"
        return PiiAnonymizationResult(
            anonymized_text=text,
            redaction_count=len(replacements),
            entity_types_found=sorted({entity for _, _, entity in replacements}),
        )

    @staticmethod
    def _known_name_rules(names: list[str]) -> list[_Rule]:
        """One rule for each full name and for each of its meaningful
        words, longest first so "Maria Rossi" is replaced as a whole
        before "Rossi" alone."""
        candidates: set[str] = set()
        for name in names:
            cleaned = " ".join(name.split())
            if len(cleaned) >= _MIN_NAME_TOKEN_LENGTH:
                candidates.add(cleaned)
            for token in cleaned.split(" "):
                if (
                    len(token) >= _MIN_NAME_TOKEN_LENGTH
                    and token.lower() not in _NAME_STOPWORDS
                    and not token.isdigit()
                ):
                    candidates.add(token)
        return [
            _Rule("NOME", re.compile(rf"(?<!\w){re.escape(candidate)}(?!\w)", re.IGNORECASE))
            for candidate in sorted(candidates, key=len, reverse=True)
        ]
