"""Chat quality evaluation: real conversations with the real LLM, scored
against a written grid.

It runs the backend of this working tree in-process, with persistence in
memory and the bootstrap (fake) user: it never touches Supabase, nobody's
account, or production. Only the LLM/vision provider is real.

It NEVER uses the production key: it needs its own, EVAL_LLM_API_KEY (in
the environment or the local .env, never printed), and refuses to start
without it or when it is the same as LLM_API_KEY. On 2026-10-05 two full
runs on the shared key used up the provider's daily quota and took the
app's chat down. Each execution also stops by itself at `--max-tokens`
(default 40000; a full run with the judge needs about 100000). See
README.md in this folder.

    uv run python scripts/eval/chat_quality/run.py run --label prima
    uv run python scripts/eval/chat_quality/run.py run --label dopo
    uv run python scripts/eval/chat_quality/run.py compare prima dopo
    uv run python scripts/eval/chat_quality/run.py rescore prima

Options of `run`: `--only id1,id2` (some scenarios), `--resume` (continue an
interrupted run), `--no-judge` (only the mechanical measures, no extra LLM
calls), `--evidence in_memory` (skip the external literature search). With
an antivirus that intercepts HTTPS add `--with truststore` to `uv run`.
`rejudge <label>` asks the judge again for the scenarios it left unscored.

Output, under .local/chat_eval/<label>/ (never committed): results.json
and transcripts.md.

THE GRID (one row per scenario)
  risponde      0-2  does it answer what was asked?                 (judge)
  turni_attesa  n    replies made only of questions before the first
                     useful one                                    (judge)
  nei_tempi     s/n  useful reply within the turn the scenario allows
  ansia         0-2  0 calm, 1 some needless worry, 2 alarming      (judge)
  gergo         0-2  unexplained technical terms                    (judge)
  naturale      0-2  sounds like a person, not a form               (judge)
  corretta      0-2  broadly right clinically                       (judge)
  cita_referto  s/n  says it read the report (where one applies)    (mechanical)
  valori        0-1  share of the report's key figures it mentions  (mechanical)
  allarmi       n    frightening words the owner did not use        (mechanical)
  tecnicismi    n    technical terms left unexplained               (mechanical)
  farmaci       n    drug names the owner did not mention           (mechanical)
  onesta        s/n  says plainly what it cannot read (where due)   (mechanical)
  evita_errori  s/n  none of the scenario's known wrong claims       (mechanical)
  urgenza       s/n  emergencies are escalated at once              (mechanical)
  rimando       -    the vet is mentioned: appropriato / superfluo /
                     mancante / nessuno (or ammesso when either is fine) (mechanical)
  esperto       0-2  answers as an expert instead of delegating      (judge)
  caratteri     n    average length of a reply                      (mechanical)
  chiamate      n    LLM calls per reply (a regeneration counts)    (measured)
  secondi       n    time to produce a reply, evidence search and
                     LLM included, rate-limit retries excluded      (measured)

The judge is the same model that writes the answers: read its scores as a
comparison between two runs, not as an absolute mark.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import os
import re
import statistics
import sys
import time
from datetime import date
from pathlib import Path
from typing import Any

ROOT_DIR = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
for path in (str(ROOT_DIR), str(HERE)):
    if path not in sys.path:
        sys.path.insert(0, path)

from scenarios import PETS as BASE_PETS  # noqa: E402
from scenarios import SCENARIOS as BASE_SCENARIOS  # noqa: E402
from scenarios import Pet, Scenario  # noqa: E402
from scenarios_everyday import EXTRA_PETS, EXTRA_SCENARIOS  # noqa: E402

PETS: dict[str, Pet] = {**BASE_PETS, **EXTRA_PETS}
SCENARIOS: tuple[Scenario, ...] = BASE_SCENARIOS + EXTRA_SCENARIOS

from packages.bootstrap.container import ApplicationContainer  # noqa: E402
from packages.core.application.ports.llm_client import LLMGenerationRequest  # noqa: E402
from packages.core.application.services.send_chat_message import (  # noqa: E402
    SendChatMessageInput,
)
from packages.core.application.services.upload_chat_attachment import (  # noqa: E402
    UploadChatAttachmentInput,
)
from packages.core.domain.conversation.attachment import ChatAttachment  # noqa: E402
from packages.core.domain.conversation.states import ConversationState  # noqa: E402
from packages.core.domain.medical_record.consent_text import CURRENT_VERSION  # noqa: E402
from packages.core.domain.medical_record.models import (  # noqa: E402
    ClinicalEvent,
    MedicalRecordConsentRecord,
)
from packages.core.domain.pet_profile.models import (  # noqa: E402
    FishStock,
    HabitatDetails,
    PetProfile,
)
from packages.shared.config.settings import Settings  # noqa: E402
from packages.shared.errors.base import ProviderError  # noqa: E402

FIXTURES_DIR = HERE / "fixtures" / "referti"
OUTPUT_DIR = ROOT_DIR / ".local" / "chat_eval"
ANALYSIS_CACHE = OUTPUT_DIR / "analysis_cache.json"
OWNER_ID = "eval-owner"

# Words that frighten an unprepared owner. Counted only when the owner did
# not use them first.
ALARM_WORDS = (
    "tumore",
    "tumori",
    "cancro",
    "maligno",
    "maligna",
    "metastasi",
    "linfoma",
    "leucemia",
    "emangiosarcoma",
    "neoplasia",
    "insufficienza renale grave",
    "letale",
    "fatale",
    "mortale",
    "morte",
    "morire",
    "terminale",
    "gravissim",
    "irreversibile",
    "emorragia",
)

# Jargon an unprepared owner does not know. Counted when the owner did
# not use the term and no explanation in brackets follows it.
JARGON = (
    "iris",
    "ckd",
    "irc",
    "ipopotassiemia",
    "ipokaliemia",
    "iperfosfatemia",
    "proteinuria",
    "azotemia",
    "iperazotemia",
    "uremi",
    "isostenuria",
    "normocitic",
    "normocromic",
    "rigenerativa",
    "nefropatia",
    "epatopatia",
    "splenic",
    "parenchima",
    "ecostruttura",
    "ecogenicit",
    "ipoecogen",
    "anecogen",
    "ematuria",
    "eziologi",
    "patogenesi",
    "idiopatic",
    "antielmintic",
    "zoonosi",
    "stadio 1",
    "stadio 2",
    "stadio 3",
    "stadio 4",
    "legante del fosforo",
    "chelante",
)

DRUGS = (
    "sevelamer",
    "benazepril",
    "amlodipina",
    "telmisartan",
    "fenbendazol",
    "metronidazol",
    "ronidazol",
    "pirantel",
    "milbemicina",
    "praziquantel",
    "meloxicam",
    "carprofen",
    "prednisolone",
    "cortison",
    "tramadol",
    "gabapentin",
    "maropitant",
    "omeprazol",
    "idrossido di alluminio",
)

# Ways a reply sends the owner to the vet.
_VET_REFERRAL = re.compile(
    r"veterinari|\bvet\b|pronto soccorso|prossimo controllo|una visita|"
    r"farl[oa] (visitare|vedere|controllare)|portal[oa] (dal|da un|in)",
    re.IGNORECASE,
)


def vet_referral_outcome(expected: bool | None, replies: list[str]) -> str:
    present = any(_VET_REFERRAL.search(reply) for reply in replies)
    if expected is None:
        return "ammesso" if present else "nessuno"
    if expected:
        return "appropriato" if present else "mancante"
    return "superfluo" if present else "nessuno"


_READ_REPORT = re.compile(
    r"ho (letto|guardato|consultato|visto)|"
    r"(nel|dal|sul|il) referto|"
    r"(nell'|dall'|l')(esame|ecografia|emocromo)|"
    r"dagli esami|negli esami",
    re.IGNORECASE,
)


DEFAULT_MAX_TOKENS = 40_000


class BudgetExceeded(Exception):
    """The execution reached its token ceiling."""


class CallCounter:
    """Counts the calls every LLM client makes and the tokens they use, by
    wrapping `generate` on the client's class once: the orchestrator and
    its helpers each hold their own reference to the client. Enforces the
    execution's ceiling: no call is made once it has been reached.

    Tokens of the vision model (reading a scanned fixture, once, then
    cached) are not counted: they are not reported through this client.
    """

    calls = 0
    tokens = 0
    max_tokens = DEFAULT_MAX_TOKENS
    # Called with the tokens of each call as soon as it returns, so an
    # interrupted or failing execution still counts against the daily cap.
    on_tokens: Any = None

    @staticmethod
    def estimated_cost(request: Any) -> int:
        """Upper bound of what one call can cost: the prompt (about one
        token every 3 characters, deliberately pessimistic for Italian) plus
        the whole reply budget."""
        prompt = f"{getattr(request, 'system_prompt', '')}{getattr(request, 'user_prompt', '')}"
        return len(prompt) // 3 + int(getattr(request, "max_tokens", 0) or 0)

    @classmethod
    def install(cls, client: Any) -> None:
        client_class = type(client)
        if getattr(client_class, "_eval_counted", False):
            return
        original = client_class.generate

        def counted(self: Any, request: Any) -> Any:
            # Never start a call whose worst case would cross the ceiling.
            if cls.tokens + cls.estimated_cost(request) > cls.max_tokens:
                raise BudgetExceeded
            cls.calls += 1
            response = original(self, request)
            used = int(getattr(response, "token_count", 0) or 0)
            cls.tokens += used
            if cls.on_tokens is not None:
                cls.on_tokens(used)
            return response

        client_class.generate = counted
        client_class._eval_counted = True


def _dedicated_key(production_key: str) -> str:
    """EVAL_LLM_API_KEY from the environment or the local .env. Exits with
    an explanation when it is missing or is the production key."""
    key = _env_value("EVAL_LLM_API_KEY")
    if not key:
        sys.exit(
            "Manca EVAL_LLM_API_KEY.\n"
            "Le prove della chat non devono usare la chiave di produzione (LLM_API_KEY): "
            "consumano la stessa quota giornaliera e possono fermare la chat dell'app.\n"
            "Crea una chiave su un conto del provider SEPARATO da quello di produzione "
            "(i limiti sono per conto, non per chiave) e aggiungila al file .env locale "
            "come EVAL_LLM_API_KEY=... Vedi scripts/eval/chat_quality/README.md."
        )
    if key == production_key and not _env_value("EVAL_LLM_BASE_URL"):
        sys.exit(
            "EVAL_LLM_API_KEY è uguale a LLM_API_KEY: è la chiave di produzione. "
            "Usa una chiave di un conto separato."
        )
    return key


PRODUCTION_KEY_DAILY_CAP = 40_000
PRODUCTION_KEY_USAGE = OUTPUT_DIR / "production_key_usage.json"


def _env_value(name: str) -> str:
    """From the environment, else the local .env (Settings ignores names it
    does not know). Never printed."""
    value = os.environ.get(name, "").strip()
    env_file = ROOT_DIR / ".env"
    if not value and env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            key, separator, raw = line.partition("=")
            if separator and key.strip() == name:
                value = raw.strip().strip('"').strip("'")
    return value


def _production_key_tokens_today() -> int:
    if not PRODUCTION_KEY_USAGE.exists():
        return 0
    usage: dict[str, int] = json.loads(PRODUCTION_KEY_USAGE.read_text(encoding="utf-8"))
    return int(usage.get(date.today().isoformat(), 0))


def record_production_key_usage(tokens: int) -> None:
    usage: dict[str, int] = {}
    if PRODUCTION_KEY_USAGE.exists():
        usage = json.loads(PRODUCTION_KEY_USAGE.read_text(encoding="utf-8"))
    today = date.today().isoformat()
    usage[today] = int(usage.get(today, 0)) + tokens
    PRODUCTION_KEY_USAGE.parent.mkdir(parents=True, exist_ok=True)
    PRODUCTION_KEY_USAGE.write_text(json.dumps(usage, indent=2), encoding="utf-8")


def _allow_production_key(max_tokens: int | None) -> None:
    """The one sanctioned exception (Orchestratore, 2026-10-06): the
    production key may be used only with an explicit flag, only under an
    explicit ceiling no larger than what is left of PRODUCTION_KEY_DAILY_CAP
    for today (the ledger is updated after every call)."""
    used = _production_key_tokens_today()
    remaining = max(PRODUCTION_KEY_DAILY_CAP - used, 0)
    if max_tokens is None:
        sys.exit(
            "Con --allow-production-key devi indicare --max-tokens esplicitamente "
            f"(oggi restano {remaining} token su {PRODUCTION_KEY_DAILY_CAP})."
        )
    if max_tokens <= 0 or max_tokens > remaining:
        sys.exit(
            f"Con la chiave di produzione il tetto e' {PRODUCTION_KEY_DAILY_CAP} token al "
            f"giorno in totale: oggi ne sono gia' stati usati {used}, ne restano {remaining}, "
            f"e questa esecuzione ne chiede fino a {max_tokens}. Riduci --max-tokens o usa "
            "EVAL_LLM_API_KEY."
        )
    # Every call is written to the ledger as it returns, not at the end.
    CallCounter.on_tokens = record_production_key_usage
    print(
        f"ATTENZIONE: chiave di produzione in uso, tetto {max_tokens} token "
        f"(oggi gia' usati {used} su {PRODUCTION_KEY_DAILY_CAP})."
    )


def build_settings(
    evidence: str | None,
    *,
    real_calls: bool = True,
    allow_production_key: bool = False,
    max_tokens: int | None = DEFAULT_MAX_TOKENS,
) -> Settings:
    overrides: dict[str, Any] = {
        # The model under test only: a silent switch to a reserve model
        # would make two runs incomparable.
        "llm_fallback_models": "",
        "environment": "development",
        "persistence_backend": "in_memory",
        "auth_backend": "bootstrap",
        "vision_provider": "groq",
        "media_storage_dir": str(OUTPUT_DIR / "media"),
    }
    if evidence:
        overrides["evidence_backend"] = evidence
    settings = Settings().model_copy(update=overrides)
    if not real_calls:
        return settings
    # Another OpenAI-compatible provider under test (EVAL_LLM_BASE_URL and
    # EVAL_LLM_MODEL): the Groq client speaks that protocol.
    base_url, model = _env_value("EVAL_LLM_BASE_URL"), _env_value("EVAL_LLM_MODEL")
    if base_url or model:
        settings = settings.model_copy(
            update={
                "llm_provider": "groq",
                "llm_base_url": base_url or settings.llm_base_url,
                "llm_model": model or settings.llm_model,
            }
        )
    if settings.llm_provider == "echo":
        sys.exit("LLM_PROVIDER è 'echo': nel .env serve un provider reale per valutare la chat.")
    if allow_production_key and not _env_value("EVAL_LLM_API_KEY"):
        _allow_production_key(max_tokens)
        return settings
    return settings.model_copy(update={"llm_api_key": _dedicated_key(settings.llm_api_key)})


def _load_cache() -> dict[str, str]:
    if ANALYSIS_CACHE.exists():
        cached: dict[str, str] = json.loads(ANALYSIS_CACHE.read_text(encoding="utf-8"))
        return cached
    return {}


def _attachment_for(
    container: ApplicationContainer, pet_id: str, fixture: str, cache: dict[str, str]
) -> ChatAttachment:
    """The fixture as an uploaded file, read by the real upload pipeline
    the first time; later runs reuse that reading, so two runs compare the
    chat on identical inputs (and spend no vision calls)."""
    content = (FIXTURES_DIR / fixture).read_bytes()
    key = f"{fixture}:{hashlib.sha256(content).hexdigest()[:16]}"
    if key not in cache:
        uploaded = (
            container.upload_chat_attachment_service()
            .execute(
                UploadChatAttachmentInput(
                    owner_id=OWNER_ID,
                    pet_id=pet_id,
                    file_bytes=content,
                    filename=fixture,
                    content_type="application/octet-stream",
                )
            )
            .attachment
        )
        if not uploaded.analysis:
            raise ProviderError(f"lettura del referto di prova {fixture} non riuscita")
        cache[key] = uploaded.analysis
        ANALYSIS_CACHE.parent.mkdir(parents=True, exist_ok=True)
        ANALYSIS_CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")
        return uploaded
    content_type = "application/pdf" if fixture.endswith(".pdf") else "image/jpeg"
    return container.chat_attachment_repository.save(
        ChatAttachment(
            owner_id=OWNER_ID,
            pet_id=pet_id,
            storage_key="eval",
            content_type=content_type,
            original_filename=fixture,
            analysis=cache[key],
        )
    )


def _create_pet(container: ApplicationContainer, pet: Pet, cache: dict[str, str]) -> PetProfile:
    profile = PetProfile(
        owner_id=OWNER_ID,
        name=pet.name,
        species=pet.species,
        breed=pet.breed,
        age_years=pet.age_years,
        birth_date_label=pet.birth_date_label,
        sex=pet.sex,
        weight_label=pet.weight_label,
        notes=pet.notes,
        habitat=HabitatDetails(volume_liters=pet.habitat_liters) if pet.habitat_liters else None,
        aquarium_stock=[
            FishStock(species=name, male_count=males, female_count=females)
            for name, males, females in pet.aquarium_stock
        ],
        medical_record_consent=(
            None
            if pet.consent is None
            else MedicalRecordConsentRecord(granted=pet.consent, version=CURRENT_VERSION)
        ),
    )
    container.pet_profile_repository.save(profile)
    for record in pet.records:
        attachment_id = None
        if record.fixture and record.analysis_failed:
            attachment_id = container.chat_attachment_repository.save(
                ChatAttachment(
                    owner_id=OWNER_ID,
                    pet_id=profile.id,
                    storage_key="eval",
                    content_type="application/pdf",
                    original_filename=record.fixture,
                    analysis_failed=True,
                )
            ).id
        elif record.fixture:
            attachment_id = _attachment_for(container, profile.id, record.fixture, cache).id
        container.clinical_event_repository.save(  # type: ignore[attr-defined]
            ClinicalEvent(
                pet_id=profile.id,
                title=record.title,
                event_date=date.fromisoformat(record.event_date),
                attachment_id=attachment_id,
            )
        )
    return profile


def run_scenario(settings: Settings, scenario: Scenario, cache: dict[str, str]) -> dict[str, Any]:
    """One conversation, on a fresh in-memory backend."""
    container = ApplicationContainer(settings)
    CallCounter.install(container.llm_client)
    profile = _create_pet(container, PETS[scenario.pet], cache)
    service = container.send_chat_message_service()
    conversation_id: str | None = None
    turns: list[dict[str, Any]] = []
    for turn in scenario.turns:
        attachment_id = None
        if turn.attachment:
            attachment_id = _attachment_for(container, profile.id, turn.attachment, cache).id
        calls_before, started = CallCounter.calls, time.perf_counter()
        output = service.execute(
            SendChatMessageInput(
                owner_id=OWNER_ID,
                pet_id=profile.id,
                conversation_id=conversation_id,
                user_message=turn.text,
                attachment_id=attachment_id,
            )
        )
        seconds = time.perf_counter() - started
        if output.state == ConversationState.RETRIEVAL_FAILURE:
            raise ProviderError("il provider LLM non ha risposto")
        conversation_id = output.conversation.id
        turns.append(
            {
                "user": turn.text,
                "attachment": turn.attachment,
                "assistant": output.reply.content,
                "mode": output.mode,
                "state": str(output.state),
                "llm_calls": CallCounter.calls - calls_before,
                "seconds": round(seconds, 1),
            }
        )
    return {"id": scenario.id, "category": scenario.category, "turns": turns}


def _normalize(text: str) -> str:
    return text.lower().replace(".", ",")


def _documents_text(scenario: Scenario) -> str:
    """What is written on the documents the chat may read in this
    scenario: a drug named there is not one the chat brought up itself."""
    fixtures = [record.fixture for record in PETS[scenario.pet].records if record.fixture]
    fixtures += [turn.attachment for turn in scenario.turns if turn.attachment]
    texts = []
    for fixture in fixtures:
        source = FIXTURES_DIR / (fixture.rsplit(".", 1)[0] + ".txt")
        if source.exists():
            texts.append(source.read_text(encoding="utf-8").lower())
    return " ".join(texts)


def _unexplained(text: str, owner_text: str, terms: tuple[str, ...]) -> int:
    """Distinct terms used without an explanation in brackets right after
    their first appearance."""
    count = 0
    for term in terms:
        position = text.find(term)
        if position < 0 or term in owner_text:
            continue
        if "(" not in text[position : position + len(term) + 40]:
            count += 1
    return count


def mechanical_scores(scenario: Scenario, turns: list[dict[str, Any]]) -> dict[str, Any]:
    replies = [turn["assistant"] for turn in turns]
    everything = "\n".join(replies)
    owner_text = " ".join(turn["user"] for turn in turns).lower()
    known_text = owner_text + " " + _documents_text(scenario)
    scores: dict[str, Any] = {
        "caratteri": round(statistics.mean(len(reply) for reply in replies)),
        "allarmi": sum(
            len(re.findall(rf"\b{re.escape(word)}", everything.lower()))
            for word in ALARM_WORDS
            if word not in owner_text
        ),
        "struttura_markdown": bool(re.search(r"^\s*(#|\||[-*] |\d+\. )", everything, re.M)),
        "tecnicismi": _unexplained(everything.lower(), owner_text, JARGON),
        "chiamate": round(statistics.mean(turn.get("llm_calls", 0) for turn in turns), 2),
        "secondi": round(statistics.mean(turn.get("seconds", 0) for turn in turns), 1),
        "farmaci": sum(
            1 for drug in DRUGS if drug in everything.lower() and drug not in known_text
        ),
    }
    if scenario.uses_report:
        scores["cita_referto"] = bool(_READ_REPORT.search(everything))
    if scenario.key_values:
        found = [
            value for value in scenario.key_values if _normalize(value) in _normalize(everything)
        ]
        scores["valori"] = round(len(found) / len(scenario.key_values), 2)
    if scenario.must_not_say_any:
        scores["evita_errori"] = not any(
            re.search(pattern, everything, re.IGNORECASE) for pattern in scenario.must_not_say_any
        )
    if scenario.must_say_any:
        scores["onesta"] = any(
            re.search(pattern, everything, re.IGNORECASE) for pattern in scenario.must_say_any
        )
    scores["rimando"] = vet_referral_outcome(scenario.vet_referral, replies)
    if scenario.urgent:
        scores["urgenza"] = turns[0]["mode"] in {"triage", "safety_clarification"} or (
            turns[0]["state"] == str(ConversationState.POSSIBLE_URGENT_CASE)
        )
    return scores


JUDGE_KEYS = ("risponde", "ansia", "gergo", "naturale", "corretta", "esperto")

JUDGE_SYSTEM = (
    "Sei un valutatore severo di un assistente veterinario per proprietari di animali NON "
    "esperti. Leggi la conversazione e compila la griglia. Rispondi SOLO con un oggetto JSON, "
    "senza testo attorno, con queste chiavi:\n"
    '"turni": lista, una voce per ogni risposta dell\'assistente, "valore" se quella risposta '
    "dà qualcosa di utile rispetto a ciò che è stato chiesto (spiegazione, indicazione, "
    'informazione), "solo_domande" se contiene solo domande o richieste di chiarimento;\n'
    '"risponde": 0 non risponde a ciò che è stato chiesto, 1 risponde in parte, 2 risponde;\n'
    '"ansia": 0 tono tranquillo e proporzionato, 1 qualche allarme non necessario, 2 '
    "allarmante (elenca malattie gravi possibili, drammatizza);\n"
    '"gergo": 0 linguaggio semplice o termini tecnici spiegati, 1 qualche termine non '
    "spiegato, 2 molti termini tecnici non spiegati;\n"
    '"naturale": 0 meccanico o da modulo, 1 accettabile, 2 suona come una persona competente '
    "e gentile;\n"
    '"corretta": 0 contiene errori clinici o contenuti inventati, 1 imprecisa o generica, 2 '
    "corretta di massima e coerente con il comportamento atteso;\n"
    '"esperto": 0 delega (rimanda al veterinario o chiede invece di rispondere), 1 risponde '
    "ma si copre con rimandi o avvertenze non necessari, 2 risponde da esperto, con "
    "sostanza, e nomina il veterinario solo se c'\u00e8 un motivo concreto;\n"
    '"nota": una frase in italiano sul difetto principale, o "ok".\n'
    'Tutte le chiavi stanno allo stesso livello; "turni" è una lista di sole stringhe. '
    "Esempio di forma per una conversazione con due risposte: "
    '{"turni": ["solo_domande", "valore"], "risponde": 2, "ansia": 0, "gergo": 1, '
    '"naturale": 2, "corretta": 2, "esperto": 2, "nota": "ok"}'
)


def judge(
    container: ApplicationContainer, scenario: Scenario, turns: list[dict[str, Any]]
) -> dict[str, Any]:
    pet = PETS[scenario.pet]
    transcript = "\n\n".join(
        f"PROPRIETARIO: {turn['user']}"
        + (f" [allegato: {turn['attachment']}]" if turn["attachment"] else "")
        + f"\nASSISTENTE: {turn['assistant']}"
        for turn in turns
    )
    response = container.llm_client.generate(
        LLMGenerationRequest(
            system_prompt=JUDGE_SYSTEM,
            user_prompt=(
                f"Animale: {pet.name}, {pet.species}"
                + (f", {pet.age_years} anni" if pet.age_years is not None else "")
                + (f". Note: {pet.notes}" if pet.notes else "")
                + f"\nComportamento atteso: {scenario.expected}\n\nCONVERSAZIONE\n{transcript}"
            ),
            temperature=0.0,
            max_tokens=1500,
        )
    )
    match = re.search(r"\{.*\}", response.content, re.DOTALL)
    if not match:
        raise ProviderError("il giudice non ha restituito JSON")
    verdict: dict[str, Any] = json.loads(match.group(0))
    kinds = verdict.get("turni")
    if isinstance(kinds, list) and len(kinds) == 1 and isinstance(kinds[0], dict):
        # Seen with one-reply conversations: the whole grid nested inside
        # the single "turni" entry, its kind under the key "valore".
        nested = kinds[0]
        verdict = {**nested, "turni": [nested.get("valore") or nested.get("tipo")]}
        kinds = verdict["turni"]
    complete = (
        isinstance(kinds, list)
        and len(kinds) == len(turns)
        and all(kind in ("valore", "solo_domande") for kind in kinds)
        and all(verdict.get(key) in (0, 1, 2) for key in JUDGE_KEYS)
    )
    if not complete:
        # Treated like a failed call: retried, never recorded half-empty.
        raise ProviderError("il giudice ha restituito una griglia incompleta")
    return verdict


def score(
    container: ApplicationContainer | None, scenario: Scenario, turns: list[dict[str, Any]]
) -> dict[str, Any]:
    scores = mechanical_scores(scenario, turns)
    if container is None:
        return scores
    verdict = judge(container, scenario, turns)
    kinds = list(verdict.get("turni") or [])
    waiting = next((index for index, kind in enumerate(kinds) if kind == "valore"), len(kinds))
    scores.update(
        {
            "risponde": verdict.get("risponde"),
            "turni_attesa": waiting,
            "ansia": verdict.get("ansia"),
            "gergo": verdict.get("gergo"),
            "naturale": verdict.get("naturale"),
            "corretta": verdict.get("corretta"),
            "esperto": verdict.get("esperto"),
            "nota": verdict.get("nota"),
        }
    )
    if scenario.value_by_turn is not None:
        scores["nei_tempi"] = waiting < scenario.value_by_turn
    return scores


def with_retries(action: Any, what: str) -> Any:
    for attempt in range(4):
        try:
            return action()
        except (ProviderError, json.JSONDecodeError) as exc:
            # A daily limit does not clear in a minute: retrying only burns
            # requests (2026-10-05).
            if attempt == 3 or "per day" in str(exc):
                raise
            wait = 20 * (attempt + 1)
            print(f"    {what}: {type(exc).__name__}, riprovo tra {wait}s", flush=True)
            time.sleep(wait)
    return None


NUMERIC = (
    "risponde",
    "turni_attesa",
    "ansia",
    "gergo",
    "naturale",
    "corretta",
    "esperto",
    "valori",
    "allarmi",
    "tecnicismi",
    "farmaci",
    "caratteri",
    "chiamate",
    "secondi",
)
BOOLEAN = ("nei_tempi", "cita_referto", "onesta", "urgenza", "evita_errori")


def summarize(results: list[dict[str, Any]]) -> dict[str, Any]:
    summary: dict[str, Any] = {"scenari": len(results)}
    for key in NUMERIC:
        values = [
            r["scores"][key] for r in results if isinstance(r["scores"].get(key), int | float)
        ]
        if values:
            summary[key] = round(statistics.mean(values), 2)
    for key in BOOLEAN:
        values = [r["scores"][key] for r in results if isinstance(r["scores"].get(key), bool)]
        if values:
            summary[key] = f"{sum(values)}/{len(values)}"
    outcomes = [r["scores"].get("rimando") for r in results if r["scores"].get("rimando")]
    if outcomes:
        summary["rimando"] = ", ".join(
            f"{name} {outcomes.count(name)}"
            for name in ("superfluo", "mancante", "appropriato", "ammesso", "nessuno")
            if outcomes.count(name)
        )
    return summary


def write_outputs(label: str, results: list[dict[str, Any]], settings: Settings) -> None:
    folder = OUTPUT_DIR / label
    folder.mkdir(parents=True, exist_ok=True)
    by_category: dict[str, list[dict[str, Any]]] = {}
    for result in results:
        by_category.setdefault(result["category"], []).append(result)
    payload = {
        "label": label,
        "model": settings.llm_model,
        "summary": summarize(results),
        "by_category": {name: summarize(items) for name, items in by_category.items()},
        "results": results,
    }
    (folder / "results.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    lines = [f"# Trascritti - {label} ({settings.llm_model})", ""]
    for result in results:
        lines += [f"## {result['id']} ({result['category']})", ""]
        for turn in result["turns"]:
            attachment = f" [allegato: {turn['attachment']}]" if turn["attachment"] else ""
            lines += [
                f"**Proprietario:** {turn['user']}{attachment}",
                "",
                f"**Chat** ({turn['mode']}): {turn['assistant']}",
                "",
            ]
        lines += [f"Punteggi: `{json.dumps(result['scores'], ensure_ascii=False)}`", ""]
    (folder / "transcripts.md").write_text("\n".join(lines), encoding="utf-8")


def _previous_results(label: str) -> list[dict[str, Any]]:
    path = OUTPUT_DIR / label / "results.json"
    if not path.exists():
        return []
    results: list[dict[str, Any]] = json.loads(path.read_text(encoding="utf-8"))["results"]
    return results


def command_rescore(arguments: argparse.Namespace) -> int:
    """Recomputes the mechanical measures of a saved run (after a change
    to them), keeping the judge's scores: no LLM call."""
    by_id = {scenario.id: scenario for scenario in SCENARIOS}
    results = _previous_results(arguments.label)
    for result in results:
        result["scores"].update(mechanical_scores(by_id[result["id"]], result["turns"]))
    write_outputs(arguments.label, results, build_settings(None, real_calls=False))
    print(json.dumps(summarize(results), ensure_ascii=False, indent=2))
    return 0


def command_rejudge(arguments: argparse.Namespace) -> int:
    """Asks the judge again for the scenarios of a saved run that have no
    judge scores (or for all with --all), on the saved transcripts."""
    settings = _eval_settings(arguments)
    container = ApplicationContainer(settings)
    CallCounter.install(container.llm_client)
    CallCounter.max_tokens = arguments.max_tokens or DEFAULT_MAX_TOKENS
    by_id = {scenario.id: scenario for scenario in SCENARIOS}
    results = _previous_results(arguments.label)
    for result in results:
        if not arguments.all and result["scores"].get("risponde") is not None:
            continue
        print(result["id"], flush=True)
        try:
            result["scores"] = with_retries(
                lambda r=result: score(container, by_id[r["id"]], r["turns"]), "giudizio"
            )
        except BudgetExceeded:
            print(_budget_message(arguments.label, "rejudge"))
            break
        write_outputs(arguments.label, results, settings)
        time.sleep(arguments.pause)
    print(json.dumps(summarize(results), ensure_ascii=False, indent=2))
    return 0


def _budget_message(label: str, command: str) -> str:
    resume = f"run --label {label} --resume" if command == "run" else f"rejudge {label}"
    return (
        f"\nTETTO RAGGIUNTO: {CallCounter.tokens} token usati su {CallCounter.max_tokens} "
        "consentiti per questa esecuzione. Mi fermo qui; quanto fatto è salvato.\n"
        f"Per continuare: `{resume}` (alza --max-tokens solo se la quota del conto di "
        "prova lo permette)."
    )


def _eval_settings(arguments: argparse.Namespace) -> Settings:
    return build_settings(
        getattr(arguments, "evidence", None) or None,
        allow_production_key=arguments.allow_production_key,
        max_tokens=arguments.max_tokens,
    )


def command_run(arguments: argparse.Namespace) -> int:
    settings = _eval_settings(arguments)
    wanted = set(arguments.only.split(",")) if arguments.only else None
    scenarios = [s for s in SCENARIOS if wanted is None or s.id in wanted]
    cache = _load_cache()
    judge_container = None if arguments.no_judge else ApplicationContainer(settings)
    CallCounter.install(ApplicationContainer(settings).llm_client)
    CallCounter.max_tokens = arguments.max_tokens or DEFAULT_MAX_TOKENS
    results = _previous_results(arguments.label) if (wanted or arguments.resume) else []
    if wanted:
        results = [r for r in results if r["id"] not in wanted]
    done = {r["id"] for r in results}
    for index, scenario in enumerate(scenarios, start=1):
        if scenario.id in done:
            continue
        print(f"[{index}/{len(scenarios)}] {scenario.id}", flush=True)
        try:
            result = with_retries(
                lambda s=scenario: run_scenario(settings, s, cache), "conversazione"
            )
            result["scores"] = with_retries(
                lambda s=scenario, r=result: score(judge_container, s, r["turns"]), "giudizio"
            )
        except BudgetExceeded:
            # A scenario cut short is not recorded: --resume redoes it whole.
            print(_budget_message(arguments.label, "run"))
            break
        results.append(result)
        write_outputs(arguments.label, results, settings)
        time.sleep(arguments.pause)
    print(json.dumps(summarize(results), ensure_ascii=False, indent=2))
    print(f"Token usati in questa esecuzione: {CallCounter.tokens} ({CallCounter.calls} chiamate)")
    print(f"Trascritti e punteggi in .local/chat_eval/{arguments.label}/")
    return 0


def command_compare(arguments: argparse.Namespace) -> int:
    runs = []
    for label in (arguments.before, arguments.after):
        path = OUTPUT_DIR / label / "results.json"
        if not path.exists():
            sys.exit(f"Manca {path}: esegui prima `run --label {label}`.")
        runs.append(json.loads(path.read_text(encoding="utf-8")))
    before, after = runs
    common = {r["id"] for r in before["results"]} & {r["id"] for r in after["results"]}
    for run in runs:
        shared = [r for r in run["results"] if r["id"] in common]
        run["summary"] = summarize(shared)
        categories: dict[str, list[dict[str, Any]]] = {}
        for result in shared:
            categories.setdefault(result["category"], []).append(result)
        run["by_category"] = {name: summarize(items) for name, items in categories.items()}
    keys = [
        k
        for k in ("scenari", *NUMERIC, *BOOLEAN)
        if k in before["summary"] or k in after["summary"]
    ]
    print(f"{'misura':<16}{arguments.before:>12}{arguments.after:>12}")
    for key in keys:
        first, second = (run["summary"].get(key, "-") for run in (before, after))
        print(f"{key:<16}{first!s:>12}{second!s:>12}")
    print("rimando al veterinario:")
    for run, label in ((before, arguments.before), (after, arguments.after)):
        print(f"  {label:<14}{run['summary'].get('rimando', '-')}")
    print("\nPer categoria (risponde / turni_attesa / ansia / naturale):")
    for category in sorted(set(before["by_category"]) | set(after["by_category"])):
        cells = []
        for run in (before, after):
            data = run["by_category"].get(category, {})
            cells.append(
                "/".join(
                    str(data.get(k, "-")) for k in ("risponde", "turni_attesa", "ansia", "naturale")
                )
            )
        print(f"  {category:<12}{cells[0]:>22}{cells[1]:>22}")
    return 0


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    try:
        importlib.import_module("truststore").inject_into_ssl()
    except ModuleNotFoundError:
        pass

    parser = argparse.ArgumentParser(description="Valutazione della qualità della chat")
    commands = parser.add_subparsers(dest="command", required=True)
    run = commands.add_parser("run", help="esegue gli scenari e li valuta")
    run.add_argument("--label", required=True)
    run.add_argument("--only", default="")
    run.add_argument("--no-judge", action="store_true")
    run.add_argument("--resume", action="store_true", help="salta gli scenari già eseguiti")
    run.add_argument("--evidence", default="", help="es. in_memory")
    run.add_argument("--pause", type=float, default=2.0)
    run.add_argument(
        "--max-tokens",
        type=int,
        default=None,
        help=(
            f"tetto di token per questa esecuzione (predefinito {DEFAULT_MAX_TOKENS}; "
            "obbligatorio con --allow-production-key): raggiunto, si ferma da solo"
        ),
    )
    run.add_argument(
        "--allow-production-key",
        action="store_true",
        help=(
            "usa LLM_API_KEY se manca EVAL_LLM_API_KEY: solo con --max-tokens, massimo "
            f"{PRODUCTION_KEY_DAILY_CAP} token al giorno in totale"
        ),
    )
    run.set_defaults(handler=command_run)
    rescore = commands.add_parser("rescore", help="ricalcola le misure meccaniche")
    rescore.add_argument("label")
    rescore.set_defaults(handler=command_rescore)
    rejudge = commands.add_parser("rejudge", help="ripete il giudizio dove manca")
    rejudge.add_argument("label")
    rejudge.add_argument("--all", action="store_true")
    rejudge.add_argument("--pause", type=float, default=2.0)
    rejudge.add_argument("--max-tokens", type=int, default=None)
    rejudge.add_argument("--allow-production-key", action="store_true")
    rejudge.set_defaults(handler=command_rejudge)
    compare = commands.add_parser("compare", help="confronta due esecuzioni")
    compare.add_argument("before")
    compare.add_argument("after")
    compare.set_defaults(handler=command_compare)
    arguments = parser.parse_args()
    handler: Any = arguments.handler
    return int(handler(arguments))


if __name__ == "__main__":
    sys.exit(main())
