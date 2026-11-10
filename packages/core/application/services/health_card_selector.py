"""Picks at most three approved cards for a health question (plan stage 2).

The store returns up to ten candidates by species and words. When more than
three come back, the light model (Haiku) chooses the ones that really answer
the question; anything it cannot do in time, or any id it invents, falls
back to the store's own order. No reranking provider (plan: no Cohere).
"""

from __future__ import annotations

import json
import logging
import re

from packages.core.application.ports.health_card_repository import HealthCardRepository
from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest
from packages.core.domain.knowledge.health_cards import HealthCard
from packages.shared.errors.base import ProviderError

logger = logging.getLogger("vetgpt.health_cards")

MAX_CARDS = 3
CANDIDATES = 10
SELECTOR_MARKER = "choose the approved health cards"
SYSTEM_PROMPT = (
    f"You {SELECTOR_MARKER} that answer a pet owner's question. You receive the question "
    "and a numbered list of cards (id, title, topic, first lines). Reply with ONLY a JSON "
    'object {"ids": [string, ...]} with the ids of at most three cards that are about '
    "this question, the most useful first; an empty list when none is. Never invent an id."
)
IDS_SCHEMA: dict[str, object] = {
    "type": "object",
    "properties": {"ids": {"type": "array", "items": {"type": "string"}}},
    "required": ["ids"],
    "additionalProperties": False,
}
_OBJECT = re.compile(r"\{.*\}", re.DOTALL)


class HealthCardSelector:
    def __init__(
        self,
        repository: HealthCardRepository,
        llm_client: LLMClient | None = None,
        *,
        timeout_seconds: int = 6,
    ) -> None:
        self._repository = repository
        self._llm_client = llm_client
        self._timeout_seconds = timeout_seconds

    def select(self, *, species: str, question: str) -> list[HealthCard]:
        candidates = self._repository.search(species=species, query=question, limit=CANDIDATES)
        if len(candidates) <= MAX_CARDS or self._llm_client is None:
            return candidates[:MAX_CARDS]
        chosen = self._rerank(question, candidates)
        return chosen if chosen is not None else candidates[:MAX_CARDS]

    def _rerank(self, question: str, candidates: list[HealthCard]) -> list[HealthCard] | None:
        assert self._llm_client is not None
        listing = "\n".join(
            f"- id {card.id} | {card.title} | topic {card.topic} | {card.body[:200]}"
            for card in candidates
        )
        try:
            response = self._llm_client.generate(
                LLMGenerationRequest(
                    system_prompt=SYSTEM_PROMPT,
                    user_prompt=f"Question: {question[:1000]}\nCards:\n{listing}",
                    temperature=0.0,
                    max_tokens=80,
                    purpose="health_card_selection",
                    model_class="light",
                    json_mode=True,
                    json_schema=IDS_SCHEMA,
                    timeout_seconds=self._timeout_seconds,
                )
            )
        except ProviderError as exc:
            logger.warning("health card selection unavailable (%s): store order kept", exc)
            return None
        ids = self._parse(response.content)
        if ids is None:
            return None
        by_id = {card.id: card for card in candidates}
        chosen = [by_id[card_id] for card_id in ids if card_id in by_id]
        return chosen[:MAX_CARDS]

    @staticmethod
    def _parse(content: str) -> list[str] | None:
        match = _OBJECT.search(content or "")
        if match is None:
            return None
        try:
            payload = json.loads(match.group(0))
        except json.JSONDecodeError:
            return None
        ids = payload.get("ids") if isinstance(payload, dict) else None
        if not isinstance(ids, list):
            return None
        return [str(item) for item in ids]
