"""Synthetic users talk to the library-chat prototype instead of the app's chat.

Evaluation only, imported by server.py when SYNTHETIC_CHAT=biblioteca: the real API, the
real accounts, pets and conversations of the synthetic-users server (memory only,
SUPABASE_URL empty, 127.0.0.1), but `ChatOrchestrator.answer` is replaced, in this process
only, by `scripts/eval/chat_quality/library_chat.py` (plan docs/llm/07). Nothing of the
production path changes.

- the outbound message goes through the orchestrator's own `_anonymize_for_provider`;
- the library is the one listed in `.local/chat_eval/biblioteca/indice.json` (or
  SYNTHETIC_LIBRARY_DIR), loaded once at start;
- the general-knowledge offer: when the previous reply was the offer and the owner says
  yes, the model answers that one question from memory (labelled by the code); an owner
  aged 14-17 gets no offer on health, symptoms, drugs or dangerous behaviour (Normativa);
- sources already cited in the conversation are found again from the citation lines of
  the earlier replies, so they are not repeated.
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts" / "eval" / "chat_quality"))

import library_chat as L  # type: ignore[import-not-found]  # noqa: E402

from packages.core.application.ports.llm_client import LLMGenerationRequest  # noqa: E402
from packages.core.application.services.chat_orchestrator import (  # noqa: E402
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.domain.conversation.states import ConversationState  # noqa: E402

LIBRARY = Path(
    os.environ.get("SYNTHETIC_LIBRARY_DIR") or ROOT / ".local" / "chat_eval" / "biblioteca"
)
USE_RERANK = os.environ.get("SYNTHETIC_LIBRARY_RERANK", "1") != "0"
_YES = re.compile(
    r"^\s*(?:s[iì]|sí|yes|yeah|ok|okay|va bene|certo|volentieri|rispondimi|procedi|dai|"
    r"ja|gerne|oui|d'accord|claro|vale|por favor|please)\b",
    re.IGNORECASE,
)
_CITATION_LINE = re.compile(r"^\*{1,3} (.+)$", re.MULTILINE)


def _load_index() -> L.LibraryIndex:
    listed = json.loads((LIBRARY / "indice.json").read_text("utf-8"))
    names = {Path(str(row["file"])).name for row in listed}
    passages = L.load_library(LIBRARY / "testi", names)
    print(f"Chat dalla biblioteca: {len({p.doc.id for p in passages})} testi", flush=True)
    return L.LibraryIndex(passages)


def _pet(data: ChatOrchestratorInput) -> str:
    parts = [data.pet_name, data.species]
    parts += [x for x in (data.breed,) if x]
    if data.age_years is not None:
        parts.append(f"{data.age_years} anni")
    parts += [x for x in (data.sex, data.weight_label) if x]
    text = ", ".join(parts) + "."
    if data.notes:
        text += f" Note: {data.notes}"
    return text


def _history(data: ChatOrchestratorInput, by_citation: dict[str, str]) -> list[L.Turn]:
    turns: list[L.Turn] = []
    pending = ""
    for message in data.conversation_history:
        if message.role == "user":
            pending = message.content
        elif message.role == "assistant":
            cited = [
                by_citation[line.strip()]
                for line in _CITATION_LINE.findall(message.content)
                if line.strip() in by_citation
            ]
            turns.append(L.Turn(pending, message.content, cited))
            pending = ""
    return turns


def install() -> None:
    index = _load_index()
    by_citation = {p.doc.full_citation: p.doc.id for p in index.passages}

    def library_answer(self: ChatOrchestrator, data: ChatOrchestratorInput) -> Any:
        client = self._llm_client

        def call(system: str, user: str, purpose: str) -> str:
            request = LLMGenerationRequest(
                system_prompt=system, user_prompt=user, max_tokens=1200, purpose=purpose
            )
            return str(client.generate(request).content)

        language = data.language if data.language in L.LANGUAGE else "it"
        message = self._anonymize_for_provider(data.user_message, data)
        pet = _pet(data)
        history = _history(data, by_citation)
        offer = L.OFFER.get(language, L.OFFER["it"])
        previous = history[-1] if history else None
        if previous and previous.assistant.startswith(offer) and _YES.match(message):
            # the yes is valid for that one question only
            question = self._anonymize_for_provider(previous.user, data)
            reader = L.read(call, question, pet, history[:-1])
            general = L.general_answer(
                call,
                message=question,
                pet=pet,
                species=data.species,
                language=language,
                history=history[:-1],
                reader=reader,
            )
            return _result(general["text"], "biblio_generale", general.get("danger_after") or [])
        result = L.answer(
            call,
            index,
            message=message,
            pet=pet,
            species=data.species,
            language=language,
            history=history,
            use_rerank=USE_RERANK,
        )
        text = result.text
        mode = "biblio_offerta" if result.offered_general else "biblio"
        sensitive = (
            result.reader.get("salute")
            or result.reader.get("comportamento_pericoloso")
            or result.danger
        )
        if result.offered_general and data.owner_is_minor and sensitive:
            # Normativa: no general-knowledge answer to minors on these topics
            text = L.NO_SOURCE_PLAIN.get(language, L.NO_SOURCE_PLAIN["it"])
            mode = "biblio_minore"
        return _result(text, mode, result.danger_by)

    ChatOrchestrator.answer = library_answer  # type: ignore[method-assign]


def _result(text: str, mode: str, flags: list[str]) -> ChatOrchestratorResult:
    return ChatOrchestratorResult(
        answer=text,
        mode=mode,
        confidence="medium",
        ai_generated=True,
        safety_flags=list(flags),
        provider="claude-cli",
        model=os.environ.get("EVAL_CLI_MODEL", "claude-haiku-5-5"),
        state=ConversationState.ADEQUATE_EVIDENCE_FOUND,
    )
