import re
from collections.abc import Callable

from pydantic import BaseModel, Field

CITATION_PATTERN = re.compile(r"\[(\d+)\]")

# Deliberately conservative and multilingual. Not exhaustive — a
# CitationVerifier/AnswerValidator is a
# safety net, not a substitute for a well-instructed prompt.
ABSOLUTE_CLAIM_MARKERS: tuple[str, ...] = (
    "sicuramente",
    "cura definitiva",
    "guarigione garantita",
    "sempre risolve",
    "elimina completamente",
    "senza alcun dubbio",
    "risolve al 100%",
    "nessun rischio",
    "garantito al 100%",
    "definitely",
    "guaranteed cure",
    "always resolves",
    "completely eliminates",
    "without any doubt",
    "100% guaranteed",
    "no risk",
    "definitivamente",
    "cura garantizada",
    "siempre lo resuelve",
    "elimina por completo",
    "sin ninguna duda",
    "garantizado al 100%",
    "sin riesgo",
)


# "Definitivamente no le des cebolla", "sicuramente non va dato", "definitely not":
# an adverb that reinforces a warning is not an overclaim (test 2, 20/11: a Spanish
# answer on leftovers was blocked whole). Only the adverbs, never "nessun rischio".
_ADVERB_MARKERS = ("sicuramente", "definitely", "definitivamente", "senza alcun dubbio")
_WARNING_AFTER = re.compile(
    r"\s*[,:]?\s*(?:\w+\s+){0,2}?(?:non|no|not|never|mai|nunca|nicht|nie|jamais|pas|avoid|evita\w*)\b"
)


def absolute_claims(text: str) -> list[str]:
    """The overclaiming markers in [text], whole words only; an adverb followed by a
    negation or "avoid" reinforces a warning and does not count."""
    lowered = text.lower()
    found = []
    for marker in ABSOLUTE_CLAIM_MARKERS:
        for match in re.finditer(rf"(?<!\w){re.escape(marker)}(?!\w)", lowered):
            after = lowered[match.end() : match.end() + 40]
            if marker in _ADVERB_MARKERS and _WARNING_AFTER.match(after):
                continue
            found.append(marker)
            break
    return found


_SENTENCES = re.compile(r"(?<=[.!?;])\s+")


def without_absolute_claims(answer: str) -> str:
    """The answer without the sentences that overclaim, layout kept (plan 08, v2: one
    word must not leave the owner with no answer at all)."""
    return without_sentences(answer, lambda s: bool(absolute_claims(s)))


# Normativa doc 20 §20.13 (20/11): the model never writes a phone number, not even an
# emergency one; any number the app gives is a fixed text of the code, never the model's.
_PHONE_NUMBER = re.compile(
    r"(?<![\d/-])(?<!\d[.,])(?:112|113|115|118|911|999|116\s?117|1500)(?!\d|[.,/-]\d)"
    r"(?!\s*(?:%|°|min\w*|or[ae]\b|hours?|giorn\w*|days?|kg|g\b|grammi|grams?|ml|anni|years?|"
    r"euro|€|\$|km|m\b|cm|mg|settiman\w*|weeks?|mesi|months?))"
    r"|\+\d{2,3}[\s.-]?\d[\d\s.-]{6,}\d"
    r"|(?<!\d)0\d{1,4}[\s.-]?\d{5,8}(?!\d)"
)


def has_phone_number(text: str) -> bool:
    return bool(_PHONE_NUMBER.search(text))


def without_phone_numbers(answer: str) -> str:
    """The model's answer without the sentences that carry a phone number."""
    return without_sentences(answer, has_phone_number)


def without_sentences(answer: str, drop: Callable[[str], bool]) -> str:
    kept_lines: list[str] = []
    for line in answer.split("\n"):
        sentences = _SENTENCES.split(line)
        kept = [s for s in sentences if not drop(s)]
        if len(kept) == len(sentences):
            kept_lines.append(line)
        elif kept:
            kept_lines.append(" ".join(kept))
    return re.sub(r"\n{3,}", "\n\n", "\n".join(kept_lines)).strip()


class AnswerValidationResult(BaseModel):
    """Spec v3 §28-29: citations must be verifiable against what was
    actually retrieved, and overclaiming must never reach the owner —
    both checked deterministically here, not trusted to the LLM's
    instruction-following alone."""

    is_valid: bool
    violations: list[str] = Field(default_factory=list)
    cited_indexes: list[int] = Field(default_factory=list)


def validate_answer(answer: str, *, sources_count: int) -> AnswerValidationResult:
    violations: list[str] = []

    cited_indexes = sorted({int(match) for match in CITATION_PATTERN.findall(answer)})
    invalid_citations = [index for index in cited_indexes if index < 1 or index > sources_count]
    if invalid_citations:
        violations.append(
            "citation_out_of_range: cites " + ", ".join(f"[{i}]" for i in invalid_citations)
        )

    matched_markers = absolute_claims(answer)
    if matched_markers:
        violations.append("unsupported_absolute_claim: " + ", ".join(matched_markers))

    return AnswerValidationResult(
        is_valid=not violations, violations=violations, cited_indexes=cited_indexes
    )
