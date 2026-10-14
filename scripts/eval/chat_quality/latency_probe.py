"""Seconds per turn with a stand-in model of known latency: no provider.

Each model call sleeps for a fixed time by purpose (defaults close to what
Groq showed live: ~1.2 s for an answer, ~0.4 s for a short structured call
on the light model), the literature retriever sleeps too, and the probe
reports, per turn, the wall-clock time against two references:

* "solo risposta": one answer call, as the chat was before build 32;
* "in serie": the sum of every call this turn made, as build 32 ran them.

    uv run python scripts/eval/chat_quality/latency_probe.py
"""

from __future__ import annotations

import argparse
import statistics
import sys
import time
from pathlib import Path
from typing import Any

ROOT_DIR = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
for path in (str(ROOT_DIR), str(HERE)):
    if path not in sys.path:
        sys.path.insert(0, path)

from run import OWNER_ID, PETS, SCENARIOS, _create_pet, _load_cache  # noqa: E402
from token_budget import _purpose_of, _settings, _stand_in_reply  # noqa: E402

from packages.bootstrap.container import ApplicationContainer  # noqa: E402
from packages.core.application.ports.evidence_retriever import (  # noqa: E402
    EvidenceRetrievalRequest,
)
from packages.core.application.ports.llm_client import (  # noqa: E402
    LLMGenerationRequest,
    LLMResponse,
)
from packages.core.application.services.send_chat_message import (  # noqa: E402
    SendChatMessageInput,
)

DEFAULT_LATENCY = {
    "answer": 1.2,
    "answer_retry": 1.2,
    "urgency_classifier": 0.4,
    "evidence_query": 0.4,
    "situation_model": 0.6,
    "interview_question": 0.4,
}
RETRIEVAL_SECONDS = 0.3


class SlowStandIn:
    def __init__(self, latency: dict[str, float]) -> None:
        self.latency = latency
        self.calls: list[tuple[str, float]] = []

    def install(self, client: Any, retriever: Any) -> None:
        stand_in = self

        def generate(_self: Any, request: LLMGenerationRequest) -> LLMResponse:
            purpose = _purpose_of(request)
            delay = stand_in.latency.get(purpose, 0.3)
            time.sleep(delay)
            stand_in.calls.append((purpose, delay))
            content = _stand_in_reply(request, purpose)
            return LLMResponse(
                content=content, provider="stand-in", model="stand-in", token_count=1
            )

        type(client).generate = generate

        retriever_class = type(retriever)
        if getattr(retriever_class, "_probe_wrapped", False):
            # Installed once per class: the stand-in is re-created per scenario.
            retriever_class._probe_latency_target = stand_in
            return
        original_retrieve = retriever_class.retrieve

        def retrieve(_self: Any, request: EvidenceRetrievalRequest) -> Any:
            time.sleep(RETRIEVAL_SECONDS)
            target = getattr(retriever_class, "_probe_latency_target", stand_in)
            target.calls.append(("retrieval", RETRIEVAL_SECONDS))
            return original_retrieve(_self, request)

        retriever_class.retrieve = retrieve
        retriever_class._probe_wrapped = True
        retriever_class._probe_latency_target = stand_in


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--category", default="caso,curiosita,sintomo")
    parser.add_argument("--limit", type=int, default=12, help="quanti scenari")
    args = parser.parse_args()
    categories = set(args.category.split(","))
    scenarios = [s for s in SCENARIOS if s.category in categories][: args.limit]
    cache = _load_cache()
    settings = _settings(False)

    rows: list[dict[str, float]] = []
    for scenario in scenarios:
        container = ApplicationContainer(settings)
        stand_in = SlowStandIn(DEFAULT_LATENCY)
        stand_in.install(container.llm_client, container.evidence_retriever)
        profile = _create_pet(container, PETS[scenario.pet], cache)
        service = container.send_chat_message_service()
        turn = scenario.turns[0]
        if turn.attachment:
            continue
        started = time.perf_counter()
        output = service.execute(
            SendChatMessageInput(owner_id=OWNER_ID, pet_id=profile.id, user_message=turn.text)
        )
        wall = time.perf_counter() - started
        serial = sum(delay for _, delay in stand_in.calls)
        answer_only = sum(
            delay for purpose, delay in stand_in.calls if purpose in ("answer", "answer_retry")
        ) + sum(delay for purpose, delay in stand_in.calls if purpose == "retrieval")
        rows.append(
            {
                "wall": wall,
                "serial": serial,
                "answer_only": answer_only,
                "calls": len(stand_in.calls),
            }
        )
        print(
            f"{scenario.id:<32} modo={output.mode:<10} chiamate={len(stand_in.calls)} "
            f"solo-risposta={answer_only:.2f}s  in-serie={serial:.2f}s  ora={wall:.2f}s"
        )
    if not rows:
        return 0
    median = {
        key: statistics.median(r[key] for r in rows) for key in ("wall", "serial", "answer_only")
    }
    print()
    print("| misura (mediana sui turni) | secondi |")
    print("|---|---|")
    print(f"| solo risposta (prima della build 32) | {median['answer_only']:.2f} |")
    print(f"| chiamate in serie (build 32) | {median['serial']:.2f} |")
    print(f"| in parallelo (build 33) | {median['wall']:.2f} |")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
