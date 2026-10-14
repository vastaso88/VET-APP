"""How many tokens a chat answer costs, without calling any provider.

Runs the evaluation scenarios through the real orchestrator with a stand-in
model (no network, no key, no quota) and counts the tokens of every prompt
the chat would have sent, call by call, with the purpose and model class of
each. From that it estimates how many answers a day each Groq model's free
quota sustains.

    uv run --system-certs --with tiktoken --with truststore \\
        python scripts/eval/chat_quality/token_budget.py --label prima

tiktoken (o200k_base, the family of the gpt-oss tokenizers) is used when it
can be imported; otherwise a character heuristic, said so in the output.
The output tokens of the stand-in replies are NOT what the real model would
write: the report counts the prompt exactly and takes the reply budget
(`max_tokens`) and a typical real reply length as given.

Results: a table on stdout and `.local/chat_eval/token_budget_<label>.json`,
so two labels (before/after a change) can be compared with `--compare`.
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT_DIR = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
for path in (str(ROOT_DIR), str(HERE)):
    if path not in sys.path:
        sys.path.insert(0, path)

from run import OWNER_ID, PETS, SCENARIOS, _create_pet, _load_cache  # noqa: E402
from scenarios import Scenario, Turn  # noqa: E402

from packages.bootstrap.container import ApplicationContainer  # noqa: E402
from packages.core.application.ports.llm_client import (  # noqa: E402
    LLMGenerationRequest,
    LLMResponse,
)
from packages.core.application.services.send_chat_message import (  # noqa: E402
    SendChatMessageInput,
)
from packages.shared.config.settings import Settings  # noqa: E402

OUTPUT_DIR = ROOT_DIR / ".local" / "chat_eval"

# Public figures (console.groq.com/docs/rate-limits, 2026-10): tokens per
# day of the free tier, per model. The real ones are in the account's
# limits page: pass --tpd to override.
DEFAULT_TPD = {
    "openai/gpt-oss-120b": 200_000,
    "openai/gpt-oss-20b": 200_000,
    "qwen/qwen3.8-27b": 200_000,
}
# What a typical real reply costs on the output side: ~1000 characters of
# Italian (the prompt's own ceiling for most kinds of request) plus the
# reasoning a gpt-oss model spends at "low" effort before writing.
TYPICAL_REPLY_TOKENS = 350
TYPICAL_REASONING_TOKENS = 150

# A longer exchange than any evaluation scenario, to see what the history
# block costs once a conversation has gone on for a while.
LONG_CONVERSATION = Scenario(
    id="conversazione-lunga",
    category="storia",
    pet="argo",
    turns=tuple(
        Turn(text)
        for text in (
            "da qualche giorno zoppica un po' dalla zampa posteriore destra",
            "soprattutto dopo le passeggiate lunghe, a riposo sembra stare meglio",
            "mangia e beve normalmente, è vivace come sempre",
            "no, non è caduto e non ha preso colpi che io sappia",
            "ha 9 anni, può essere l'artrosi?",
            "cosa posso fare a casa per aiutarlo intanto?",
            "il tappetino riscaldato va bene o è meglio di no?",
            "e per le scale? abbiamo tre piani senza ascensore",
        )
    ),
    expected="",
)

_REPLY = (
    "Capisco la preoccupazione. Quello che descrivi è abbastanza comune e nella maggior "
    "parte dei casi non è nulla di grave: spesso dipende da un piccolo sforzo o da un "
    "fastidio passeggero, e tende a passare da solo in pochi giorni se lo tieni un po' a "
    "riposo. Intanto puoi fare così: passeggiate più corte e tranquille, niente salti o "
    "giochi bruschi, e dagli un posto comodo dove sdraiarsi. Controlla con calma la zampa "
    "per vedere se c'è qualcosa tra i polpastrelli o un'unghia rovinata, e osserva se "
    "appoggia il peso quando cammina. Se fra due o tre giorni zoppica ancora, se smette "
    "di appoggiare la zampa o se la vedi gonfia o calda, allora fallo vedere."
)
_EXTRACTION = (
    '{"presenting_problem": "zoppia posteriore", "onset": "da qualche giorno", '
    '"contexts": ["dopo le passeggiate"], "observed_behaviours": ["zoppica"], '
    '"associated_signs": ["appetito normale"], "known_medical_context": null, '
    '"environmental_changes": [], "working_domains": ["clinical_question"], '
    '"known_facts": [], "relevant_unknowns": [], "safety_critical_unknowns": []}'
)


class Counter:
    """Counts tokens with tiktoken when available, else by characters."""

    def __init__(self) -> None:
        self.method = "caratteri/3.5 (stima)"
        self._encoding: Any = None
        try:
            import tiktoken

            self._encoding = tiktoken.get_encoding("o200k_base")
            self.method = "tiktoken o200k_base"
        except Exception:  # noqa: BLE001 - optional dependency, offline fallback
            self._encoding = None

    def count(self, text: str) -> int:
        if self._encoding is not None:
            return len(self._encoding.encode(text))
        return max(1, round(len(text) / 3.5))


def _purpose_of(request: LLMGenerationRequest) -> str:
    explicit = getattr(request, "purpose", None)
    if explicit and explicit != "answer":
        return str(explicit)
    system = request.system_prompt
    if "extract structured case information" in system:
        return "situation_model"
    if "phrasing one anamnesis follow-up question" in system:
        return "interview_question"
    if "performing evidence synthesis" in system:
        return "evidence_synthesis"
    if "transcribing a veterinary document" in system:
        return "document_summary"
    if "a vet from a chat the owner had" in system:
        return "vet_summary"
    if "Reply briefly and warmly" in system:
        return "general_answer"
    return str(explicit or "answer")


def _stand_in_reply(request: LLMGenerationRequest, purpose: str) -> str:
    if purpose == "situation_model":
        return _EXTRACTION
    if purpose == "interview_question":
        return "Da quanto tempo lo noti?"
    if purpose == "urgency_classifier":
        return '{"level": "normal", "category": null}'
    if purpose == "evidence_query":
        return '["dog", "lameness", "hind limb"]'
    if purpose == "general_answer":
        return "Prego, a presto!"
    return _REPLY


class Recorder:
    """Replaces the model with a stand-in and keeps every request."""

    def __init__(self, counter: Counter) -> None:
        self.counter = counter
        self.calls: list[dict[str, Any]] = []

    def install(self, client: Any) -> None:
        recorder = self

        def generate(_self: Any, request: LLMGenerationRequest) -> LLMResponse:
            purpose = _purpose_of(request)
            content = _stand_in_reply(request, purpose)
            system_tokens = recorder.counter.count(request.system_prompt)
            user_tokens = recorder.counter.count(request.user_prompt)
            recorder.calls.append(
                {
                    "purpose": purpose,
                    "model_class": str(getattr(request, "model_class", "main")),
                    "system_tokens": system_tokens,
                    "user_tokens": user_tokens,
                    "prompt_tokens": system_tokens + user_tokens,
                    "max_tokens": request.max_tokens,
                }
            )
            return LLMResponse(
                content=content,
                provider="stand-in",
                model="stand-in",
                token_count=system_tokens + user_tokens + recorder.counter.count(content),
                finish_reason="stop",
            )

        type(client).generate = generate


def _settings(interview_loop: bool) -> Settings:
    return Settings(
        _env_file=None,  # type: ignore[call-arg]
        LLM_PROVIDER="echo",
        PERSISTENCE_BACKEND="in_memory",
        AUTH_BACKEND="bootstrap",
        EVIDENCE_BACKEND="in_memory",
        ENABLE_INTERVIEW_LOOP=interview_loop,
    )


def run_scenario(
    settings: Settings, scenario: Scenario, counter: Counter, cache: dict[str, str]
) -> dict[str, Any]:
    container = ApplicationContainer(settings)
    recorder = Recorder(counter)
    recorder.install(container.llm_client)
    profile = _create_pet(container, PETS[scenario.pet], cache)
    service = container.send_chat_message_service()
    conversation_id: str | None = None
    turns: list[dict[str, Any]] = []
    for turn in scenario.turns:
        if turn.attachment:
            # Needs the upload pipeline (vision): out of scope here.
            continue
        before = len(recorder.calls)
        output = service.execute(
            SendChatMessageInput(
                owner_id=OWNER_ID,
                pet_id=profile.id,
                conversation_id=conversation_id,
                user_message=turn.text,
            )
        )
        conversation_id = output.conversation.id
        calls = recorder.calls[before:]
        turns.append(
            {
                "text": turn.text[:60],
                "mode": output.mode,
                "calls": calls,
                "main_prompt_tokens": sum(
                    c["prompt_tokens"] for c in calls if c["model_class"] == "main"
                ),
                "light_prompt_tokens": sum(
                    c["prompt_tokens"] for c in calls if c["model_class"] != "main"
                ),
            }
        )
    return {"id": scenario.id, "category": scenario.category, "turns": turns}


def summarize(results: list[dict[str, Any]], tpd: dict[str, int]) -> dict[str, Any]:
    answered = [
        turn
        for result in results
        for turn in result["turns"]
        if any(c["purpose"] in ("answer", "general_answer") for c in turn["calls"])
    ]
    by_purpose: dict[str, list[int]] = defaultdict(list)
    by_purpose_max: dict[str, list[int]] = defaultdict(list)
    for result in results:
        for turn in result["turns"]:
            for call in turn["calls"]:
                by_purpose[call["purpose"]].append(call["prompt_tokens"])
                by_purpose_max[call["purpose"]].append(call["max_tokens"])
    main_per_turn = [t["main_prompt_tokens"] for t in answered] or [0]
    light_per_turn = [t["light_prompt_tokens"] for t in answered] or [0]
    calls_per_turn = [len(t["calls"]) for t in answered] or [0]
    answer_calls = [
        c for t in answered for c in t["calls"] if c["purpose"] in ("answer", "general_answer")
    ]
    system_tokens = [c["system_tokens"] for c in answer_calls] or [0]
    median_main = statistics.median(main_per_turn)
    cost_per_answer = median_main + TYPICAL_REPLY_TOKENS + TYPICAL_REASONING_TOKENS
    main_tpd = tpd["openai/gpt-oss-120b"]
    return {
        "turns_answered": len(answered),
        "calls_per_turn_median": statistics.median(calls_per_turn),
        "answer_system_prompt_tokens_median": statistics.median(system_tokens),
        "main_prompt_tokens_per_turn_median": median_main,
        "main_prompt_tokens_per_turn_p90": sorted(main_per_turn)[
            min(len(main_per_turn) - 1, int(len(main_per_turn) * 0.9))
        ],
        "light_prompt_tokens_per_turn_median": statistics.median(light_per_turn),
        "cost_per_answer_main_tokens": cost_per_answer,
        "answers_per_day_main_model": int(main_tpd // cost_per_answer) if cost_per_answer else 0,
        "answers_per_day_with_reserves": (
            int(sum(tpd.values()) // cost_per_answer)
            if cost_per_answer
            else 0
        ),
        "by_purpose": {
            purpose: {
                "calls": len(tokens),
                "prompt_tokens_median": statistics.median(tokens),
                "max_tokens_median": statistics.median(by_purpose_max[purpose]),
            }
            for purpose, tokens in sorted(by_purpose.items())
        },
    }


def _print(label: str, method: str, summary: dict[str, Any], results: list[dict[str, Any]]) -> None:
    print(f"## Token per risposta: {label}  (conteggio: {method})\n")
    print("| misura | valore |")
    print("|---|---|")
    for key in (
        "turns_answered",
        "calls_per_turn_median",
        "answer_system_prompt_tokens_median",
        "main_prompt_tokens_per_turn_median",
        "main_prompt_tokens_per_turn_p90",
        "light_prompt_tokens_per_turn_median",
        "cost_per_answer_main_tokens",
        "answers_per_day_main_model",
        "answers_per_day_with_reserves",
    ):
        print(f"| {key} | {summary[key]} |")
    print("\n| scopo | chiamate | token prompt (mediana) | max_tokens (mediana) |")
    print("|---|---|---|---|")
    for purpose, row in summary["by_purpose"].items():
        print(
            f"| {purpose} | {row['calls']} | {row['prompt_tokens_median']} | "
            f"{row['max_tokens_median']} |"
        )
    print("\n| scenario | turno | modo | chiamate | token principale | token leggero |")
    print("|---|---|---|---|---|---|")
    for result in results:
        for index, turn in enumerate(result["turns"], start=1):
            print(
                f"| {result['id']} | {index} | {turn['mode']} | {len(turn['calls'])} | "
                f"{turn['main_prompt_tokens']} | {turn['light_prompt_tokens']} |"
            )


def _compare(before: str, after: str) -> None:
    rows = []
    for label in (before, after):
        path = OUTPUT_DIR / f"token_budget_{label}.json"
        rows.append(json.loads(path.read_text(encoding="utf-8"))["summary"])
    print(f"| misura | {before} | {after} |")
    print("|---|---|---|")
    for key in rows[0]:
        if key == "by_purpose":
            continue
        print(f"| {key} | {rows[0][key]} | {rows[1][key]} |")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--label", default="misura")
    parser.add_argument("--interview-loop", action="store_true")
    parser.add_argument("--category", help="solo queste categorie, separate da virgola")
    parser.add_argument("--compare", nargs=2, metavar=("PRIMA", "DOPO"))
    parser.add_argument(
        "--tpd",
        action="append",
        default=[],
        metavar="MODELLO=TOKEN",
        help="quota giornaliera reale di un modello (dalla console Groq)",
    )
    args = parser.parse_args()
    if args.compare:
        _compare(*args.compare)
        return 0

    tpd = dict(DEFAULT_TPD)
    for item in args.tpd:
        model, _, value = item.partition("=")
        tpd[model] = int(value)
    counter = Counter()
    cache = _load_cache()
    settings = _settings(args.interview_loop)
    categories = set(args.category.split(",")) if args.category else None
    scenarios = [
        s for s in (*SCENARIOS, LONG_CONVERSATION) if categories is None or s.category in categories
    ]
    results = [run_scenario(settings, scenario, counter, cache) for scenario in scenarios]
    summary = summarize(results, tpd)
    _print(args.label, counter.method, summary, results)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUTPUT_DIR / f"token_budget_{args.label}.json").write_text(
        json.dumps(
            {"label": args.label, "method": counter.method, "summary": summary, "results": results},
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
