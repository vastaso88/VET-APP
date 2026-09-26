import re

from pydantic import BaseModel, Field

CITATION_PATTERN = re.compile(r"\[(\d+)\]")

# Deliberately conservative and Italian-specific (the app answers in
# Italian). Not exhaustive — a CitationVerifier/AnswerValidator is a
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
)


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

    lowered = answer.lower()
    matched_markers = [marker for marker in ABSOLUTE_CLAIM_MARKERS if marker in lowered]
    if matched_markers:
        violations.append("unsupported_absolute_claim: " + ", ".join(matched_markers))

    return AnswerValidationResult(
        is_valid=not violations, violations=violations, cited_indexes=cited_indexes
    )
