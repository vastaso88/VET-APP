"""English search keywords for the owner's question, from the light model.

The literature retrievers (PubMed, Europe PMC, Crossref, OpenAlex) index
English text; the owner writes Italian. Until now the Italian sentence
went out as the query and the relevance filter bridged a few stems. A
handful of English keywords is a better query and costs a short call on
the light model. On any failure the original text is used, as before.
"""

from __future__ import annotations

import json
import logging
import re

from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest
from packages.shared.errors.base import ProviderError

logger = logging.getLogger("vetgpt.evidence_query")

QUERY_MARKER = "veterinary literature search keywords"

SYSTEM_PROMPT = (
    f"You write {QUERY_MARKER} for a pet owner's question, in English, for PubMed-style "
    'databases. Reply with ONLY a JSON object: {"keywords": [string, ...]} with 3 to 6 '
    "short keywords or phrases: the species, the sign or topic, the body part or "
    "context. No sentences, no explanations, no Italian words."
)

_OBJECT = re.compile(r"\{.*\}", re.DOTALL)
_WORD = re.compile(r"[A-Za-z][A-Za-z\- ]{1,40}")


class EvidenceQueryNormalizer:
    def __init__(self, llm_client: LLMClient, *, timeout_seconds: int = 6) -> None:
        self._llm_client = llm_client
        self._timeout_seconds = timeout_seconds

    def keywords(self, question: str, species: str) -> str | None:
        """ "dog lameness hind limb exercise" for a question about a dog that
        limps after walks; None when nothing usable came back."""
        try:
            response = self._llm_client.generate(
                LLMGenerationRequest(
                    system_prompt=SYSTEM_PROMPT,
                    user_prompt=f"Species: {species}\nQuestion: {question[:1000]}",
                    temperature=0.0,
                    max_tokens=80,
                    purpose="evidence_query",
                    model_class="light",
                    json_mode=True,
                    timeout_seconds=self._timeout_seconds,
                )
            )
        except ProviderError as exc:
            logger.warning("evidence query normalizer unavailable (%s): using the question", exc)
            return None
        return self.parse(response.content)

    @staticmethod
    def parse(content: str) -> str | None:
        match = _OBJECT.search(content or "")
        if match is None:
            return None
        try:
            payload = json.loads(match.group(0))
        except json.JSONDecodeError:
            return None
        raw = payload.get("keywords") if isinstance(payload, dict) else None
        if not isinstance(raw, list):
            return None
        keywords: list[str] = []
        for item in raw:
            text = str(item).strip().lower()
            if text and _WORD.fullmatch(text) and text not in keywords:
                keywords.append(text)
        return " ".join(keywords[:6]) or None
