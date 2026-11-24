"""Photo reading off: one notice, said once (collaudo T10).

Reproduced on 24/11/2026 on today's chat: the English reply opened with the fixed notice and went
on with "I can't see photos, so I can't judge the bowl from the picture" (2 of 2), and the notice
spoke of a vaccination booklet for a photo of a bowl (6 of 6). No new words: the model's sentence
goes, and the notice's last clause is said only when the owner names a document. Deterministic,
five languages.
"""

from __future__ import annotations

import re

from packages.core.domain.knowledge.answer_validation import without_sentences
from packages.core.domain.safety.emergency_patterns import normalize_for_matching

_DOCUMENT = re.compile(
    r"\b(?:librett\w*|refert\w*|esam[ei]|analis\w*|document\w*|ricett\w*|vaccin\w*|certificat\w*|"
    r"report\w*|tests?|results?|booklet|passport|prescription\w*|"
    r"informe\w*|analitic\w*|cartilla\w*|receta\w*|"
    r"befund\w*|impfpass\w*|labor\w*|rezept\w*|"
    r"carnet\w*|compte rendu|ordonnance\w*|resultat\w*)\b"
)
_CANNOT_SEE = re.compile(
    r"\b(?:non (?:posso|riesco a|sono in grado di) (?:vedere|guardare|leggere)|"
    r"(?:can't|cannot|can not|unable to) (?:see|view|look at)|"
    r"no puedo (?:ver|mirar)|(?:kann|konnen) (?:\w+ ){0,4}nicht (?:sehen|anschauen)|"
    r"nicht (?:sehen|anschauen)|"
    r"ne peux pas (?:voir|regarder)|ne vois pas)\b"
)
_PICTURE = re.compile(
    r"\b(?:foto\w*|immagin\w*|photos?|pictures?|images?|imagen\w*|bild\w*|bilder|photo\w*)\b"
)
# A sentence that says more than that (a condition, a contrast, the vet, a time) is never cut:
# "I can't see the photo, but if it bleeds take it to the vet now".
_SAYS_MORE = re.compile(
    r"\b(?:ma|pero|but|aber|mais|se|if|si|wenn|falls|veterina\w*|vets?|tierarzt\w*|tieraerzt\w*|"
    r"clinic\w*|klinik\w*|urgen\w*|emergen\w*|subito|oggi|now|today|ahora|hoy|sofort|heute|"
    r"maintenant|aujourd'hui)\b"
)


def notice_for(message: str, notice: str) -> str:
    """The fixed notice; its clause on booklets and reports (after the last semicolon) only when
    the owner names one, or sends the photo with no words."""
    if not message.strip() or _DOCUMENT.search(normalize_for_matching(message)):
        return notice
    head, separator, _ = notice.rpartition(";")
    return f"{head.rstrip()}." if separator else notice


def without_repeated_notice(answer: str) -> str:
    """The reply without the sentences that only say again that it cannot see the photo."""
    kept = without_sentences(answer, _only_says_it_again)
    return kept if len(kept.strip()) >= 40 else answer


def _only_says_it_again(sentence: str) -> bool:
    text = normalize_for_matching(sentence)
    return bool(_CANNOT_SEE.search(text) and _PICTURE.search(text) and not _SAYS_MORE.search(text))
