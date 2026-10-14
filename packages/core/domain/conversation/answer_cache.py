"""Which questions may share one answer, and under which key.

Only a general curiosity about the kind of animal ("i cani possono mangiare
le fragole?", "quanto vive un criceto?") qualifies: a question that is
answered the same for every owner of that species. Anything about THIS
animal — a symptom, something it did, its age or weight, its documents, a
follow-up — is answered fresh every time, with the pet's own context.

The key is the normalized question plus species and language: accents,
punctuation, fillers ("ciao", "una domanda") and spacing do not matter.
"""

from __future__ import annotations

import hashlib
import re
import unicodedata

from packages.core.domain.conversation.request_kind import RequestKind

MIN_QUESTION_CHARS = 8
MAX_QUESTION_CHARS = 200

# Openers that carry no topic (see also title.py).
_FILLERS = re.compile(
    r"^(?:(?:ciao|buongiorno|buonasera|salve|hey|scusa|scusami|senti|per favore|"
    r"una domanda|ho una domanda|avrei una domanda|volevo sapere|vorrei sapere|"
    r"mi dici|dimmi|secondo te)[\s,:]*)+"
)
# Words that make a question about this animal or this moment rather than
# the species in general. Matched as whole words.
_PERSONAL = re.compile(
    r"\b(?:mio|mia|miei|mie|nostro|nostra|nostri|nostre|mi|me|lui|lei|"
    r"questo|questa|questi|queste|suo|sua|suoi|sue|ha|sta|fa|"
    r"ieri|oggi|stamattina|stasera|stanotte|adesso|ora|ultimamente|"
    r"my|our|he|she|him|her|his|this|today|yesterday|now)\b"
)
_DIGIT = re.compile(r"\d")


def normalize_question(text: str) -> str:
    lowered = unicodedata.normalize("NFKD", text.strip().lower())
    without_accents = "".join(ch for ch in lowered if not unicodedata.combining(ch))
    without_punctuation = re.sub(r"[^\w\s]", " ", without_accents)
    collapsed = re.sub(r"\s+", " ", without_punctuation).strip()
    return _FILLERS.sub("", collapsed).strip()


def is_cacheable_question(
    message: str,
    *,
    kind: RequestKind,
    pet_name: str,
    has_attachment: bool,
    has_history: bool,
) -> bool:
    """True only for a general question, asked as the first message, with
    nothing that ties it to this animal."""
    if kind is not RequestKind.DIRECT or has_attachment or has_history:
        return False
    normalized = normalize_question(message)
    if not MIN_QUESTION_CHARS <= len(normalized) <= MAX_QUESTION_CHARS:
        return False
    if _DIGIT.search(normalized) or _PERSONAL.search(normalized):
        return False
    name = normalize_question(pet_name)
    if name and re.search(rf"\b{re.escape(name)}\b", normalized):
        return False
    return True


def cache_key(message: str, *, species: str, language: str) -> str:
    material = f"{language.strip().lower()}|{species.strip().lower()}|{normalize_question(message)}"
    return hashlib.sha256(material.encode("utf-8")).hexdigest()[:32]
