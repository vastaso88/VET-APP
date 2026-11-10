"""Approved health cards in Supabase (scripts/setup/health_cards.sql).

Read with the service role through `search_health_cards`: Postgres full-text
search in Italian on title, topic and text, filtered by species family and
status "approved", ranked. No embeddings and no other provider (plan
stage 2): the database is the one already in Ireland. A failure is logged
and returns nothing, so the chat takes the safe path instead of erroring.
"""

from __future__ import annotations

import logging
import re
from typing import TYPE_CHECKING, Any

from packages.core.application.ports.health_card_repository import HealthCardRepository
from packages.core.domain.knowledge.health_cards import HealthCard

if TYPE_CHECKING:
    from supabase import Client

logger = logging.getLogger("vetgpt.health_cards")


class SupabaseHealthCardRepository(HealthCardRepository):
    def __init__(self, client: Client) -> None:
        self._client = client

    def search(self, *, species: str, query: str, limit: int = 10) -> list[HealthCard]:
        try:
            response = self._client.rpc(
                "search_health_cards",
                {"p_species": species, "p_query": query[:1000], "p_limit": limit},
            ).execute()
        except Exception:  # noqa: BLE001 - no card is a safe answer, an error is not
            logger.exception("health cards: search failed; answering without cards")
            return []
        rows = response.data if isinstance(response.data, list) else []
        cards: list[HealthCard] = []
        for row in rows:
            card = self._card(row)
            if card is not None:
                cards.append(card)
        return cards

    @staticmethod
    def _card(row: Any) -> HealthCard | None:
        if not isinstance(row, dict):
            return None
        try:
            return HealthCard(
                id=str(row["id"]),
                species=tuple(row.get("species") or ()),
                topic=str(row.get("topic") or ""),
                title=str(row.get("title") or ""),
                body=str(row.get("body") or ""),
                source=re.sub(r"^\s*font[ei]\s*:\s*", "", str(row.get("source") or ""), flags=re.I),
                source_level=int(row.get("source_level") or 3),
                language=str(row.get("language") or "it"),
            )
        except (KeyError, ValueError):
            logger.warning("health cards: a malformed row was skipped")
            return None
