"""Collaudo, wave 0 (23/11/2026): four defects of the chat found on the online twin.

1. replies cut in the middle of a word (the reasoning had spent the token budget);
2. a source on dogs and cats under a rabbit's and a guinea pig's answer;
3. "pending vet review" shown to the owner;
4. the size of a guinea pig's cage with no source.
"""

from __future__ import annotations

import importlib
import json
import re
import time
from collections.abc import Callable
from types import SimpleNamespace
from typing import Any

import pytest

from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services import chat_orchestrator as orchestrator_module
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.finished_text import generate_finished_lines
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.conversation.unfinished_text import (
    close_at_last_line,
    close_at_last_sentence,
)
from packages.core.domain.knowledge.enclosure_size import (
    unsourced_sizes,
    without_unsourced_sizes,
)
from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.knowledge.relevance import is_relevant, topic_terms
from packages.infrastructure.llm.providers.anthropic_llm_client import AnthropicLLMClient
from packages.infrastructure.llm.retrieval.curated_awareness_evidence_retriever import (
    AWARENESS_CATALOG,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    CATALOG,
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError

# the end of two replies of the round, cut as the tester read them (synthetic owners)
_CUT = (
    "Fiocco va visto da un veterinario adesso: un coniglio gonfio che si pulisce poco può "
    "avere l'intestino fermo. Chiama subito e descrivi cosa hai visto.\n\n"
    "Nel frattempo:\n\n"
    "1. Tienilo in un posto tranquillo, con fieno fresco davanti.\n"
    "2. Non forzarlo a mangiare e non premere la pancia con forza.\n\n"
    "Osserva se beve e se fa palline di fe"
)
_WHOLE = (
    "Fiocco va visto da un veterinario adesso: un coniglio gonfio che si pulisce poco può avere "
    "l'intestino fermo. Chiama subito e, mentre ti prepari, tienilo tranquillo con il fieno "
    "davanti. Se smette di fare palline o si accascia, dillo alla clinica quando arrivi."
)


class CuttingClient:
    """Answers with a queue of (text, finish_reason) for the answer and for the checks."""

    def __init__(self, **by_purpose: list[tuple[str, str] | Exception]) -> None:
        self.queues = {k: list(v) for k, v in by_purpose.items()}
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        queue = self.queues.get(request.purpose)
        outcome: Any = queue.pop(0) if queue else ("{}", "stop")
        if isinstance(outcome, Exception):
            raise outcome
        text, finish = outcome
        return LLMResponse(
            content=text, provider="fake", model="fake", token_count=1, finish_reason=finish
        )

    def of(self, purpose: str) -> list[LLMGenerationRequest]:
        return [r for r in self.requests if r.purpose == purpose]


def _ask(
    client: Any,
    message: str = "Si pulisce poco e sta gonfio. Cosa faccio?",
    *,
    v2: bool = True,
    species: str = "Piccoli mammiferi",
    name: str = "Fiocco",
    **extra: Any,
) -> ChatOrchestratorResult:
    orchestrator = ChatOrchestrator(
        client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer(), answer_v2=v2
    )
    return orchestrator.answer(
        ChatOrchestratorInput(user_message=message, species=species, pet_name=name, **extra)
    )


_PLAIN = "ogni quanto va spazzolato?"


# --- 1. a cut reply never goes out as it is ---------------------------------------------------


@pytest.mark.parametrize(
    ("text", "closed_end"),
    [
        (_CUT, "con forza."),
        ("Pesa 900 g, è nella norma. Se vedi un calo o se mangia meno del sol", "nella norma."),
        (
            "Le cause:\n\n1. L'acqua.\n2. Il cibo.\n3. Una malattia, meno probabile ma da",
            "Il cibo.",
        ),
        ("Va bene così. Nel frattempo:\n\n- acqua fre", "Va bene così. Nel frattempo:"),
        ("Give him 2.5 litres a day. Then, e.g. at ni", "a day."),
        ("Geben Sie Heu. Sie können z. B. am Aben", "Heu."),
        ("Dale heno. ¿Bebe agua? Si no be", "¿Bebe agua?"),
        ("Donnez du foin ! Surveillez s'il ma", "foin !"),
        ("È «normale.» Poi gua", "«normale.»"),
    ],
)
def test_a_cut_text_is_closed_at_its_last_finished_sentence(text: str, closed_end: str) -> None:
    closed = close_at_last_sentence(text)
    if closed_end.endswith(":"):
        # the line that only opens what was cut goes too
        assert closed == "" or not closed.endswith(":")
    else:
        assert closed.endswith(closed_end)
    assert text.startswith(closed)


def test_a_text_with_no_finished_sentence_closes_to_nothing() -> None:
    assert close_at_last_sentence("Per un pesce rosso a corpo tondo servo") == ""
    assert close_at_last_sentence("Nel frattempo:\n\n1. Tie") == ""


def test_half_of_a_value_is_dropped_with_its_line() -> None:
    text = "Emocromo del 3/11\nRBC 6,1 (5,5-8,5)\nALT 1"
    assert close_at_last_line(text) == "Emocromo del 3/11\nRBC 6,1 (5,5-8,5)"
    assert close_at_last_line("## Segni\n- vomito\n\n## Terapie") == "## Segni\n- vomito"


@pytest.mark.parametrize("v2", [True, False])
def test_a_cut_answer_is_written_again_with_no_reasoning(v2: bool) -> None:
    client = CuttingClient(answer=[(_CUT, "length")], answer_unfinished=[(_WHOLE, "stop")])
    result = _ask(client, _PLAIN, v2=v2)

    assert "l'intestino fermo" in result.answer
    assert not result.answer.rstrip().endswith("di fe")
    (again,) = client.of("answer_unfinished")
    assert again.without_reasoning and again.timeout_seconds is not None
    assert again.timeout_seconds <= 16


@pytest.mark.parametrize("v2", [True, False])
@pytest.mark.parametrize(
    "second",
    [("Anche questa finisce a me", "length"), ProviderError("down"), ("", "stop")],
)
def test_when_the_second_writing_fails_the_answer_is_closed(v2: bool, second: Any) -> None:
    client = CuttingClient(answer=[(_CUT, "length")], answer_unfinished=[second])
    result = _ask(client, _PLAIN, v2=v2)

    assert result.answer.rstrip().endswith("con forza.")
    assert "palline di fe" not in result.answer


def test_with_no_time_left_the_answer_is_closed_at_once(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(orchestrator_module, "_seconds_left", lambda: 6.0)
    client = CuttingClient(answer=[(_CUT, "length")])
    result = _ask(client, _PLAIN)

    assert client.of("answer_unfinished") == []
    assert result.answer.rstrip().endswith("con forza.")


def test_an_answer_cut_before_its_first_sentence_is_the_known_failure_reply() -> None:
    client = CuttingClient(
        answer=[("Per un pesce rosso a corpo tondo servo", "length")],
        answer_unfinished=[ProviderError("down")],
    )
    result = _ask(client, _PLAIN)

    assert result.state == ConversationState.RETRIEVAL_FAILURE
    assert "servo" not in result.answer


def test_a_whole_answer_is_never_touched() -> None:
    text = "Bastano due volte a settimana: usa una spazzola morbida e fermati se si agita"
    client = CuttingClient(answer=[(text, "stop")])
    assert text in _ask(client, _PLAIN).answer


def test_the_closed_text_is_what_the_severity_check_reads() -> None:
    cut = "Va visto oggi stesso, perché gonfio e fermo non è un buon segno. Poi guarda se fa pal"
    client = CuttingClient(
        answer=[(cut, "length")],
        answer_unfinished=[ProviderError("down")],
        severity_check=[('{"serious": false, "delays": false, "rewrite": ""}', "stop")],
    )
    _ask(client)

    for request in client.of("severity_check"):
        assert "se fa pal" not in request.user_prompt


def test_a_severity_check_cut_by_the_budget_is_asked_again_with_no_reasoning() -> None:
    delayed = (
        "Con la pancia dura e due vomiti va visto oggi stesso. Chiama il veterinario e descrivi "
        "cosa hai visto, poi tienilo tranquillo e senza cibo fino alla visita."
    )
    now = (
        "Portalo dal veterinario adesso: la pancia dura con due vomiti può peggiorare in poche "
        "ore. Chiama la clinica mentre ti prepari e descrivi cosa hai visto."
    )
    verdict = json.dumps({"serious": True, "delays": True, "rewrite": now})
    client = CuttingClient(
        answer=[(delayed, "stop")],
        severity_check=[('{"serious": true, "del', "length"), (verdict, "stop")],
    )
    result = _ask(client, "Ha vomitato due volte e la pancia è dura", species="Cane", name="Ringo")

    assert "adesso" in result.answer and "oggi stesso" not in result.answer
    first, second = client.of("severity_check")
    assert not first.without_reasoning and second.without_reasoning
    assert first.timeout_seconds is not None and first.timeout_seconds <= 16
    assert second.timeout_seconds is not None and second.timeout_seconds <= 19


def test_the_turn_is_timed_from_its_first_line(monkeypatch: pytest.MonkeyPatch) -> None:
    clock = [100.0]
    monkeypatch.setattr(time, "monotonic", lambda: clock[0])
    orchestrator_module._turn_started.set(100.0)
    assert orchestrator_module._seconds_left() == 19.0
    clock[0] = 112.0
    assert orchestrator_module._seconds_left() == 7.0


def test_a_summary_cut_by_the_budget_is_written_again_then_closed_by_line() -> None:
    request = LLMGenerationRequest(system_prompt="s", user_prompt="u", purpose="vet_summary")
    again = CuttingClient(
        vet_summary=[("## Segni\n- vom", "length"), ("## Segni\n- vomito", "stop")]
    )
    assert generate_finished_lines(again, request) == "## Segni\n- vomito"
    assert again.requests[1].without_reasoning

    cut = "## Segni\n- vomito ieri\n- febbre 39,"
    twice = CuttingClient(vet_summary=[(cut, "length"), ("## Se", "length")])
    assert generate_finished_lines(twice, request) == "## Segni\n- vomito ieri"


_LONG = " ".join(["Osserva il cane con calma e annota ogni giorno cosa mangia."] * 25)


def test_a_cut_shortening_never_reaches_the_owner() -> None:
    client = CuttingClient(answer=[(_LONG, "stop")], shorten=[("Osserva il cane con ca", "length")])
    result = _ask(client, _PLAIN)

    assert not result.answer.rstrip().endswith("con ca")
    assert "annota ogni giorno cosa mangia" in result.answer


def test_the_shortening_has_room_for_the_words_it_is_asked_for() -> None:
    # 150 words of Italian were more than 400 tokens: 20 shortenings of 32 were cut
    client = CuttingClient(answer=[(_LONG, "stop")], shorten=[("Osserva il cane.", "stop")])
    _ask(client, _PLAIN)
    (request,) = client.of("shorten")
    assert request.max_tokens >= 800 and request.timeout_seconds is not None


def test_with_no_time_left_the_long_answer_is_not_shortened(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(orchestrator_module, "_seconds_left", lambda: 2.0)
    # the reply itself had been written before
    monkeypatch.setattr(orchestrator_module, "_seconds_for_the_answer", lambda: 16)
    client = CuttingClient(answer=[(_LONG, "stop")])
    result = _ask(client, _PLAIN)
    assert client.of("shorten") == [] and "annota ogni giorno" in result.answer


def test_the_severity_check_never_starts_past_the_owners_wait(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(orchestrator_module, "_seconds_left", lambda: 4.0)
    # the reply itself had been written before
    monkeypatch.setattr(orchestrator_module, "_seconds_for_the_answer", lambda: 16)
    delayed = "Con la pancia dura va visto oggi stesso. Chiama il veterinario e descrivi tutto."
    client = CuttingClient(answer=[(delayed, "stop")])
    _ask(client, "Ha la pancia dura", species="Cane", name="Ringo")
    # only the quick way, with the time that is left
    (request,) = client.of("severity_check")
    assert request.without_reasoning and request.timeout_seconds == 4


def _settings() -> Settings:
    return Settings.model_validate(
        {"ANTHROPIC_API_KEY": "test-key", "ANTHROPIC_EFFORT": "low", "SUPABASE_URL": ""}
    )


def test_the_second_writing_switches_the_reasoning_off_at_the_provider() -> None:
    client = AnthropicLLMClient(_settings(), client=SimpleNamespace())
    ordinary = LLMGenerationRequest(system_prompt="s", user_prompt="u", max_tokens=450)
    body = client.payload(ordinary, structured=True)
    assert "thinking" not in body and body["max_tokens"] == 450 + 1200

    body = client.payload(ordinary.model_copy(update={"without_reasoning": True}), structured=True)
    assert body["thinking"] == {"type": "disabled"}
    assert body["max_tokens"] == 450


# --- 2. a source of another species is never shown ------------------------------------------

_DOGS_AND_CATS = next(s for s in CATALOG if "Dogs and Cats" in s.title)
_TERMS = topic_terms("quanto mangia? appetito e peso, vitamina")


@pytest.mark.parametrize("species", ["small_mammal", "bird", "fish", "reptile_amphibian", "other"])
def test_a_source_on_dogs_and_cats_is_not_for_other_animals(species: str) -> None:
    assert not is_relevant(_DOGS_AND_CATS, _TERMS, species=species)
    assert not is_relevant(_DOGS_AND_CATS, set(), species=species)


@pytest.mark.parametrize("species", ["dog", "cat"])
def test_it_stays_for_dogs_and_cats(species: str) -> None:
    assert is_relevant(_DOGS_AND_CATS, _TERMS, species=species)


@pytest.mark.parametrize(
    ("title", "journal", "species", "kept"),
    [
        ("Dental disease in pet rabbits", None, "small_mammal", True),
        ("Dental disease in pet rabbits", None, "dog", False),
        ("Vitamin C in guinea pigs", None, "small_mammal", True),
        ("Avian nutrition", None, "fish", False),
        (
            "Feeding the sick patient",
            "Journal of Feline Medicine and Surgery",
            "small_mammal",
            False,
        ),
        ("Feeding the sick patient", "Journal of Feline Medicine and Surgery", "cat", True),
        ("Laminitis in horses and ponies", None, "other", True),
        (
            "Feeding the sick patient",
            "Veterinary Clinics: Small Animal Practice",
            "small_mammal",
            True,
        ),
    ],
)
def test_the_title_and_the_journal_say_which_animals_a_source_is_about(
    title: str, journal: str | None, species: str, kept: bool
) -> None:
    source = EvidenceSource(title=title, journal=journal, species="other")
    assert is_relevant(source, set(), species=species) is kept


def test_every_curated_note_is_kept_for_its_own_family() -> None:
    # The small mammals' note names the guinea pig and the rat: "pig" and "rat" had it dropped
    # for the rabbits and guinea pigs it is about.
    for note in AWARENESS_CATALOG:
        if note.species not in ("other", "") and "Ethology" in (note.snippet or ""):
            assert is_relevant(note, set(), species=note.species), note.title


def test_farm_and_lab_animals_stay_out_for_small_mammals() -> None:
    for title in ("Swine influenza vaccination in pigs", "A murine model of colitis in mice"):
        paper = EvidenceSource(title=title, species="other", tier="B")
        assert not is_relevant(paper, set(), species="small_mammal")


def test_no_answer_on_a_rabbit_or_a_guinea_pig_shows_a_dogs_and_cats_source() -> None:
    for breed, message in (
        (
            "Coniglio nano",
            "Il mio coniglio nano ha 2 anni. Quanto fieno e verdura mangia al giorno?",
        ),
        ("Cavia", "Vitamina C per la cavia: serve? Dieta e alimentazione?"),
    ):
        client = CuttingClient(
            answer=[("Fieno sempre a disposizione, verdura fresca ogni giorno.", "stop")]
        )
        result = _ask(client, message, breed=breed)
        assert all("Dogs and Cats" not in s.title for s in result.sources)


# --- 3. no vet review promised anywhere -------------------------------------------------------

_VET_REVIEW = re.compile(
    r"pending (?:a )?(?:vet|review)|vet(?:erinary|erinarian)?[ -]review|"
    r"review(?:ed)? by (?:a |an |the |our )?(?:\w+ )?vet|"
    r"revisione (?:del )?veterinari|in attesa di revisione|revisionat\w+ da (?:un )?veterinari|"
    r"revisad\w+ por (?:un )?veterinari|revisión veterinaria|"
    r"tierärztlich(?:e|er|en)? (?:geprüft|prüfung|überprüfung)|"
    r"(?:relu|révisé|vérifié)e?s? par (?:un )?vétérinaire|relecture vétérinaire",
    re.IGNORECASE,
)
_MODULES = (
    "packages.core.domain.localization",
    "packages.core.domain.localization_fr",
    "packages.core.domain.knowledge.duty_notes",
    "packages.core.domain.safety.harmful_requests",
    "packages.core.domain.safety.first_aid",
    "packages.core.application.services.natural_answer_prompt",
    "packages.infrastructure.llm.retrieval.in_memory_evidence_retriever",
    "packages.infrastructure.llm.retrieval.curated_awareness_evidence_retriever",
    "packages.infrastructure.llm.retrieval.curated_husbandry_evidence_retriever",
)


def _strings(value: Any, seen: set[int]) -> list[str]:
    if id(value) in seen:
        return []
    seen.add(id(value))
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [t for v in value.values() for t in _strings(v, seen)]
    if isinstance(value, (list, tuple, set, frozenset)):
        return [t for v in value for t in _strings(v, seen)]
    if isinstance(value, EvidenceSource):
        return [value.title, value.snippet or "", value.journal or ""]
    return []


@pytest.mark.parametrize("module", _MODULES)
def test_no_text_or_source_name_promises_a_vet_review(module: str) -> None:
    loaded = importlib.import_module(module)
    texts = [
        text
        for name, value in vars(loaded).items()
        if not name.startswith("__") and not isinstance(value, (re.Pattern, Callable))  # type: ignore[arg-type]
        for text in _strings(value, set())
    ]
    assert texts
    assert [t[:120] for t in texts if _VET_REVIEW.search(t)] == []


def test_the_guard_recognises_the_old_label() -> None:
    assert _VET_REVIEW.search("Curated awareness note (pending vet review): understanding the dog")


# --- 4. the size of a cage needs a source ------------------------------------------------------


@pytest.mark.parametrize(
    "sentence",
    [
        "Per una coppia di cavie serve un recinto di almeno 100 x 60 cm.",
        "La gabbia deve misurare 100x60.",
        "Una gabbia di 120 cm per 60 cm va bene.",
        "Il recinto deve avere almeno 0,7 m² di superficie.",
        "Serve una gabbia lunga almeno 120 cm.",
        "The cage should be at least 100 x 60 cm.",
        "A hutch of 2 square metres is the minimum.",
        "La jaula debe medir 120 x 60 cm.",
        "Der Käfig sollte mindestens 100 x 60 cm groß sein.",
        "La cage doit mesurer au moins 100 x 60 cm.",
    ],
)
def test_a_cage_size_with_no_source_is_recognised_in_five_languages(sentence: str) -> None:
    assert unsourced_sizes(sentence, "Cavia da sola o in coppia?")
    assert without_unsourced_sizes(f"Meglio in coppia. {sentence}", "") == "Meglio in coppia."


@pytest.mark.parametrize(
    "sentence",
    [
        "Pulisci la gabbia 2 volte a settimana.",
        "Fallo correre fuori dal recinto 2 x 30 minuti al giorno.",
        "Dai 30 g di verdura e lascia il fieno nella gabbia.",
        "La cavia pesa 900 g e vive circa 5 anni.",
        "La gabbia va tenuta a 20 °C, lontano dagli spifferi.",
        "Due passeggiate di 40 minuti, circa 3 km.",
    ],
)
def test_what_is_not_the_size_of_a_cage_stays(sentence: str) -> None:
    assert unsourced_sizes(sentence, "") == []


def test_a_size_the_source_or_the_owner_gives_stays() -> None:
    sentence = "Per un geco leopardo adulto il terrario di riferimento è 75 x 30 cm."
    assert unsourced_sizes(sentence, "about 75x30cm floor as a minimum") == []
    assert unsourced_sizes("La tua gabbia da 80 x 50 cm è piccola.", "ho una gabbia 80x50") == []


@pytest.mark.parametrize("v2", [True, False])
def test_the_cage_size_of_the_round_is_not_said(v2: bool) -> None:
    reply = (
        "Le cavie vivono meglio in coppia, perché sono animali sociali. Per una coppia serve un "
        "recinto di almeno 100 x 60 cm. Lo spazio deve permettere di correre e di nascondersi, e "
        "ogni animale deve avere il suo riparo."
    )
    client = CuttingClient(answer=[(reply, "stop")])
    result = _ask(
        client,
        "Cavia da sola o in coppia? Lo spazio minimo della gabbia in cm.",
        v2=v2,
        name="Pepe",
    )

    assert "100" not in result.answer and "60" not in result.answer
    assert "in coppia" in result.answer and "nascondersi" in result.answer


def test_the_v2_prompt_asks_for_a_source_for_every_size() -> None:
    client = CuttingClient(answer=[(_WHOLE, "stop")])
    _ask(client, _PLAIN)
    (request,) = client.of("answer")
    assert "SIZES NEED A SOURCE" in request.system_prompt
