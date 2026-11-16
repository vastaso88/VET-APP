"""Synthetic users, round 3 (2026-11-16, .local/synthetic_users/giro3/report.md):
sixteen owners, mostly of exotic animals.

1. Exotic emergencies: the first gesture by species and picture (an axolotl or a
   chinchilla in the heat were told to keep warm, a bleeding feather got no
   pressure), never a generic gesture that is wrong.
2. One emergency opening in 74 of 86 replies, also off context (a coral, a betta).
3. First-aid questions with no gesture and on signs nobody wrote (a cover on a
   cage, a canary that eats and sings); the non-stick pan in Italian.
4. The same dose refusal four times to an owner who asked no dose.
5. Routing: an aquarium question and a vet search taken for a report, a turtle
   taken for a fish, a law on keeping a turtle refused as off topic.
6. Questions on things not said ("non fa la cacca", blood for a gecko).
7. Vague pictures with a detail or two: advice before the questions.
9. Length: the shortening threshold.
10. The per-pet chat limit: Ultra stuck at 4.
And the shortening model's preface, a photo announced but never attached.
"""

from __future__ import annotations

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ANSWER_WORDS_LIMIT,
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.safety_gate import SafetyGate
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.application.services.urgency_classifier import UrgencyVerdict
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.conversation.request_kind import RequestKind, classify_request
from packages.core.domain.knowledge.dose_in_answer import find_dosage, without_dose_sentences
from packages.core.domain.localization import translate
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.safety.clarification_fit import clarifying_question_fits
from packages.core.domain.safety.dosage_request import asks_an_amount, is_dosage_request
from packages.core.domain.safety.first_aid import describes_fume_distress, mentions_heat
from packages.core.domain.safety.harmful_requests import describes_a_vague_picture
from packages.core.domain.safety.triage_clarification import clarifying_question
from packages.core.domain.subscription.limits import LIMITS_BY_PLAN
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import ConversationLimitError

LANGUAGES = ("it", "en", "es", "de", "fr")


def _ask(
    message: str,
    *,
    species: str = "Cane",
    breed: str | None = None,
    name: str = "Rex",
    sex: str | None = None,
    language: str = "it",
    history: list[ChatMessage] | None = None,
    client: RecordingLLMClient | None = None,
    classifier: object | None = None,
) -> tuple[ChatOrchestratorResult, RecordingLLMClient]:
    llm = client or RecordingLLMClient()
    orchestrator = ChatOrchestrator(
        llm,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        urgency_classifier=classifier,  # type: ignore[arg-type]
    )
    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=message,
            species=species,
            breed=breed,
            pet_name=name,
            sex=sex,
            language=language,
            conversation_history=history or [],
        )
    )
    return result, llm


class _Verdict:
    """The light classifier, answering what the test needs."""

    def __init__(self, level: str, category: str | None = None, topic: str | None = None):
        self.verdict = UrgencyVerdict(level=level, category=category, topic=topic)

    def classify(self, message: str, species: str) -> UrgencyVerdict:
        return self.verdict


# --- 10. the per-pet chat limit follows the plan ----------------------------------------------


def _chat_service(plan: str | None, setting: int = 4) -> SendChatMessageService:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-a", owner_id="owner-a", name="Milo", species="Cane"))
    orchestrator = ChatOrchestrator(
        RecordingLLMClient(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    return SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,
        pets,
        max_active_conversations_per_pet=setting,
        owner_limits=(lambda _o, _e: LIMITS_BY_PLAN[plan]) if plan else None,
    )


def _open_chats(service: SendChatMessageService, count: int) -> None:
    for index in range(count):
        service.execute(
            SendChatMessageInput(
                owner_id="owner-a", pet_id="pet-a", user_message=f"quanto deve dormire? {index}"
            )
        )


@pytest.mark.parametrize("plan", ["plus", "pro", "ultra"])
def test_the_plan_decides_how_many_chats_a_pet_may_have(plan: str) -> None:
    limit = LIMITS_BY_PLAN[plan].max_chats_per_pet
    service = _chat_service(plan, setting=4)

    _open_chats(service, limit)  # every one of them opens
    with pytest.raises(ConversationLimitError) as caught:
        _open_chats(service, 1)

    assert caught.value.limit == limit


def test_ultra_reaches_six_chats_per_pet_even_with_the_setting_at_four() -> None:
    service = _chat_service("ultra", setting=4)

    _open_chats(service, 6)

    assert len(service._repository.list_by_pet("pet-a")) == 6  # noqa: SLF001


def test_without_a_plan_the_setting_is_the_limit() -> None:
    service = _chat_service(None, setting=3)
    _open_chats(service, 3)

    with pytest.raises(ConversationLimitError) as caught:
        _open_chats(service, 1)

    assert caught.value.limit == 3


# --- 1. the first gesture by species and picture --------------------------------------------------


@pytest.mark.parametrize("language", LANGUAGES)
def test_no_generic_emergency_step_says_warm_any_more(language: str) -> None:
    warm = {"it": "al caldo", "en": "warm,", "es": "abrigad", "de": "warm,", "fr": "au chaud"}
    for key in ("triage_steps", "triage_steps_female", "triage_steps_exotic"):
        text = translate(key, language, pet_name="Toby")
        assert warm[language] not in text, (key, text)


def test_a_chinchilla_at_28_degrees_is_cooled_not_kept_warm() -> None:
    assert mentions_heat("En casa hace 28 grados")
    result, _ = _ask(
        "¡Urgente! En casa hace 28 grados, Luna está tumbada sobre el costado, respira muy "
        "rápido y tiene las orejas rojas. ¿Qué hago ahora mismo?",
        species="Piccoli mammiferi",
        breed="Cincillà",
        name="Luna",
        sex="Femmina",
        language="es",
        classifier=_Verdict("emergency", "respiratory"),
    )
    assert result.mode == "triage"
    assert "abrigad" not in result.answer
    assert "al rincón más fresco de la casa" in result.answer


def test_an_axolotl_is_never_told_to_be_kept_warm() -> None:
    result, _ = _ask(
        "Wooper galleggia di traverso con la pancia in su e non mangia da 4 giorni, le "
        "branchie sono pallide. Cosa posso fare adesso?",
        species="Rettili e anfibi",
        breed="Axolotl",
        name="Wooper",
        classifier=_Verdict("emergency", "other"),
    )
    assert result.mode == "triage"
    assert "al caldo" not in result.answer
    assert "non scaldare la vasca" in result.answer


def test_a_bleeding_growing_feather_gets_pressure_first() -> None:
    result, _ = _ask(
        "A Cip si è rotta una penna in crescita e sanguina tanto, non smette. Cosa faccio?",
        species="Uccello",
        breed="Cocorita",
        name="Cip",
    )
    assert result.mode == "triage"
    steps = result.answer.split("\n", 1)[1]
    assert steps.startswith("1) ferma il sangue adesso: premi")
    assert "senza stringere il petto" in result.answer
    assert "al caldo" not in result.answer


def test_a_bleeding_rabbit_gets_pressure_not_warmth() -> None:
    result, _ = _ask(
        "Il coniglio si è tagliato una zampa e perde sangue, non si ferma.",
        species="Piccoli mammiferi",
        breed="Coniglio nano",
    )
    assert result.mode == "triage"
    assert "premi con delicatezza" in result.answer
    assert "al caldo" not in result.answer


def test_a_bleeding_feather_without_a_quantity_still_gets_the_bird_steps_at_once() -> None:
    # Round 3 eval: "sanguina" without "tanto" got the generic dog question.
    result, _ = _ask(
        "Una penna in crescita si è rotta e sanguina, cosa faccio?",
        species="Uccello",
        breed="Canarino",
        name="Caruso",
    )
    assert result.mode == "triage"
    assert "senza stringere il petto" in result.answer


def test_a_cat_straining_with_a_few_drops_of_urine_is_an_emergency_at_once() -> None:
    result, _ = _ask(
        "Fa forza nella lettiera, poche gocce di urina, miagola.",
        species="Gatto",
        name="Artù",
        sex="Maschio castrato",
    )
    assert result.mode == "triage"
    assert "Prima di darti indicazioni" not in result.answer


def test_a_dog_lying_down_at_35_degrees_gets_the_heatstroke_steps() -> None:
    result, _ = _ask(
        "Si è sdraiato a 35 gradi e ansima forte. Lo bagno con acqua fredda?",
        name="Zefiro",
        classifier=_Verdict("emergency", "respiratory"),
    )
    assert result.mode == "triage"
    assert "NON ghiacciata" in result.answer


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_new_steps_exist_in_every_language(language: str) -> None:
    for key in (
        "triage_steps_exotic_cool",
        "triage_steps_axolotl",
        "triage_steps_bird_bleeding",
        "triage_steps_exotic_bleeding",
        "triage_steps_bird_fumes",
        "triage_opening_2",
        "triage_opening_3",
        "dosage_answer_again",
    ):
        text = translate(key, language, pet_name="Toby")
        assert text.strip() and "{" not in text, (key, language)


# --- 3. the non-stick pan, and questions that need their own sign ---------------------------------


def test_a_bird_after_the_non_stick_pan_goes_to_fresh_air_at_once() -> None:
    message = "Ho usato la padella antiaderente, ora Caruso respira male e sta fermo sul fondo."
    assert describes_fume_distress(message)
    result, _ = _ask(message, species="Uccello", breed="Canarino", name="Caruso")

    assert result.mode == "triage"
    assert "fuori dalla stanza dei fumi" in result.answer
    assert "Prima di darti indicazioni" not in result.answer


def test_a_question_about_the_pan_with_no_sign_is_not_an_emergency() -> None:
    assert not describes_fume_distress("Posso usare la padella antiaderente se ho un pappagallo?")


@pytest.mark.parametrize(
    "message",
    [
        "Ho messo un telo pesante su tutta la gabbia, anche sopra, e lei sta zitta. Non è che "
        "la soffoco?",
        "Ha bolle nel naso e uno starnuto, ma mangia e canta.",
    ],
)
def test_the_breathing_question_needs_a_breathing_word(message: str) -> None:
    assert not clarifying_question_fits("respiratory", message)


def test_a_cover_on_the_cage_gets_an_answer_not_the_first_aid_question() -> None:
    result, _ = _ask(
        "Ho messo un telo pesante su tutta la gabbia, anche sopra, e lei sta zitta. Va bene "
        "così? Non è che la soffoco?",
        species="Uccello",
        breed="Calopsite",
        name="Perla",
        sex="Femmina",
        classifier=_Verdict("possible", "respiratory"),
    )
    assert result.mode != "safety_clarification"
    assert "fiato affannoso" not in result.answer


def test_a_gecko_losing_its_tail_without_blood_is_not_asked_about_bleeding() -> None:
    message = "lizzo ha perso la coda, o la sta perdendo. è apatica. ricresce da sola?"
    assert not clarifying_question_fits("bleeding_trauma", message)
    assert clarifying_question_fits("bleeding_trauma", "si è tagliato e c'è sangue sulla zampa")


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_breathing_question_starts_with_a_safe_gesture(language: str) -> None:
    question = clarifying_question("respiratory", language)
    assert question is not None
    assert "affann" not in question  # never a sign the owner did not write
    first = question.split(".")[0].lower()
    assert any(word in first for word in ("fresco", "cool", "fresco", "kühl", "frais")), question


@pytest.mark.parametrize("language", LANGUAGES)
@pytest.mark.parametrize("female", [False, True])
def test_no_clarifying_question_shows_a_placeholder(language: str, female: bool) -> None:
    # Round 3: a literal "{sp}" slipped into the French female breathing question.
    for category in ("respiratory", "collapse", "seizure", "bleeding_trauma", "urinary"):
        question = clarifying_question(category, language, female=female)
        assert question is None or ("{" not in question and "}" not in question), question
    gut = clarifying_question("gi_stasis", language, female=female, family="small_mammal")
    assert gut is not None and "{" not in gut


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_gut_question_does_not_presume_no_stools(language: str) -> None:
    question = clarifying_question("gi_stasis", language, family="small_mammal")
    assert question is not None
    assert "non fa la cacca" not in question
    assert "ni defecar" not in question and "passing stool" not in question


def test_a_bubble_nest_is_not_fish_in_distress() -> None:
    message = "Bola ha hecho un nido de burbujas en la superficie, cerca de la esquina. ¿Es normal?"
    assert SafetyGate().evaluate(message.lower(), species="Pesce") == []
    assert SafetyGate().evaluate("boccheggiano in superficie", species="Pesce")


# --- 2. the emergency opening is not always the same ----------------------------------------------


def _opening_of(result: ChatOrchestratorResult) -> str:
    return result.answer.split("\n", 1)[0]


def test_the_emergency_openings_vary_between_messages() -> None:
    messages = [
        "ha mangiato il cioccolato fondente adesso",
        "credo abbia una torsione gastrica",
        "ha la pancia gonfia e dura e cerca di vomitare",
        "è svenuto all'improvviso",
        "non riesce a respirare",
        "ha avuto una convulsione adesso",
    ]
    openings = {_opening_of(_ask(message)[0]) for message in messages}
    assert len(openings) >= 2


def test_a_second_emergency_in_the_same_chat_never_repeats_the_opening() -> None:
    first, _ = _ask("credo abbia una torsione gastrica")
    history = [
        ChatMessage(role="user", content="credo abbia una torsione gastrica"),
        ChatMessage(role="assistant", content=first.answer),
        ChatMessage(role="user", content="grazie, siamo tornati e sta bene"),
        ChatMessage(role="assistant", content="Che sollievo, sono contento."),
    ]
    second, _ = _ask("adesso non riesce a respirare", history=history)

    assert second.mode == "triage"
    assert _opening_of(second) != _opening_of(first)


def test_the_follow_up_still_recognises_every_opening_and_the_old_fish_one() -> None:
    legacy = (
        "Hai fatto bene a scrivermi subito. Quello che descrivi dei pesci è un segnale di "
        "acqua in sofferenza, e va corretto adesso. Ecco cosa fare:\n1) ..."
    )
    for reply in (legacy, translate("triage_opening_2", "it", pet_name="Rex") + "1) ..."):
        data = ChatOrchestratorInput(
            user_message="e adesso?",
            species="Cane",
            pet_name="Rex",
            conversation_history=[ChatMessage(role="assistant", content=reply)],
        )
        assert ChatOrchestrator._follows_a_triage_reply(data)  # noqa: SLF001


def test_the_fish_opening_names_neither_the_fish_nor_a_certain_cause() -> None:
    for language in LANGUAGES:
        opening = translate("triage_opening_fish", language).lower()
        assert "pesci" not in opening and "the fish" not in opening
        assert "peces" not in opening and "fischen" not in opening and "poissons" not in opening


# --- 4. the dose refusal only for a dose, and never twice the same --------------------------------


def test_saying_no_dose_is_not_a_dose_request() -> None:
    message = (
        "No dose, I'm not asking about medicine. Simply: a calopsite who is eating less and "
        "sitting low. Should I book a vet visit this week?"
    )
    assert not is_dosage_request(message)
    assert not asks_an_amount(message)
    # a real request with a negation in it stays one
    assert is_dosage_request("non so quanta dose di metacam dargli")


def test_a_body_weight_or_a_drink_is_not_a_dose() -> None:
    assert find_dosage("Poppy pesa 85 g: nessun farmaco senza il veterinario.") is None
    assert find_dosage("Un cane beve circa 60 millilitri per chilo al giorno.") is None
    assert find_dosage("Nebulizza il terrario due o tre volte al giorno, a goccioline.") is None
    assert find_dosage("Dagli 5 mg/kg di meloxicam") is not None


def test_only_the_dose_sentence_leaves_a_reply_to_a_question_that_asked_none() -> None:
    reply = (
        "Mangia un po' meno e sta bassa sul posatoio: conviene una visita questa settimana.\n\n"
        "Dagli 0,1 ml di meloxicam ogni 24 ore. Pesala ogni mattina alla stessa ora e annota "
        "il peso: se cala di più del 5% chiama il veterinario prima."
    )
    trimmed = without_dose_sentences(reply)
    assert "meloxicam" not in trimmed
    assert "Pesala ogni mattina" in trimmed and "visita questa settimana" in trimmed

    result, _ = _ask(
        "Mangia un po' meno del solito e sta bassa sul posatoio. Devo andare dal veterinario "
        "questa settimana?",
        species="Uccello",
        breed="Calopsite",
        name="Poppy",
        client=RecordingLLMClient(reply),
    )
    assert result.answer != translate("dosage_answer", "it")
    assert "meloxicam" not in result.answer
    assert "Pesala ogni mattina" in result.answer


def test_a_second_dose_refusal_in_a_row_is_worded_differently() -> None:
    request = "quanti mg di metacam gli do?"
    first, _ = _ask(request)
    history = [
        ChatMessage(role="user", content=request),
        ChatMessage(role="assistant", content=first.answer),
    ]
    second, _ = _ask("ma quanti mg di metacam allora?", history=history)

    assert first.answer.startswith(translate("dosage_answer", "it"))
    assert second.answer.startswith(translate("dosage_answer_again", "it"))


# --- 5. routing -----------------------------------------------------------------------------------


@pytest.mark.parametrize(
    "message",
    [
        "Adesso che i valori si stanno sistemando, vorrei aggiungere altri pesci. Con neon, "
        "guppy e corydoras quali posso mettere?",
        "Vicino a Pisa conosco solo un veterinario generico che dice di non curare rettili. "
        "Come trovo un veterinario che cura testuggini, e ogni quanto serve un esame delle feci?",
    ],
)
def test_a_question_is_not_taken_for_a_report_to_explain(message: str) -> None:
    assert classify_request(message) is not RequestKind.REPORT


def test_a_report_to_explain_is_still_one() -> None:
    assert classify_request("mi spieghi le analisi? la creatinina è alta") is RequestKind.REPORT


@pytest.mark.parametrize(
    ("message", "profile"),
    [
        (
            "Once he's eating again, what should Sheldon eat? Is that enough, or does he need "
            "insects, fish or supplements?",
            "Rettili e anfibi",
        ),
        ("¿Puedo usar arena de gato para su baño de arena?", "Piccoli mammiferi"),
        ("Can I use cat litter in her cage?", "Piccoli mammiferi"),
    ],
)
def test_a_species_named_as_food_or_as_an_object_is_not_the_patient(
    message: str, profile: str
) -> None:
    assert ChatOrchestrator._effective_species(message.lower(), profile) == profile  # noqa: SLF001


def test_a_ferret_profile_is_not_another_animal_when_the_owner_says_ferret() -> None:
    message = "in italia il microchip per il furetto è obbligatorio?"
    assert ChatOrchestrator._effective_species(message, "Furetto") == "Furetto"  # noqa: SLF001


def test_the_animal_named_as_the_patient_still_wins() -> None:
    assert ChatOrchestrator._effective_species("il mio gatto vomita", "Cane") == "cat"  # noqa: SLF001


def test_a_law_on_keeping_the_animal_is_never_off_topic() -> None:
    history = [
        ChatMessage(role="user", content="Can I release Sheldon in a pond?"),
        ChatMessage(role="assistant", content="No: releasing a pet turtle is forbidden."),
    ]
    result, client = _ask(
        "Which law says that? Please name the EU regulation or the Italian decree.",
        species="Rettili e anfibi",
        name="Sheldon",
        language="en",
        history=history,
        classifier=_Verdict("normal", topic="off_topic"),
    )
    assert result.mode != "general" or client.requests_for("answer")
    assert "I can't help with that" not in result.answer


def test_a_message_about_something_else_is_still_off_topic() -> None:
    result, _ = _ask(
        "scrivimi una ricetta per la torta di mele",
        classifier=_Verdict("normal", topic="off_topic"),
    )
    assert result.model == "off-topic-guard"


# --- 7. a vague picture: the questions first, once ------------------------------------------


@pytest.mark.parametrize(
    "message",
    [
        "Il mio Totò da qualche giorno è strano, non so spiegarlo bene. Dorme di più.",
        "Poppy isn't really herself lately. I can't explain it well.",
        "Bola está raro desde hace unos días, no sé explicarlo bien.",
        "hey so Chompy is acting kinda weird lately",
    ],
)
def test_vague_pictures_are_recognised(message: str) -> None:
    assert describes_a_vague_picture(message)


def test_ordinary_messages_are_not_vague_pictures() -> None:
    assert not describes_a_vague_picture("il filtro fa un rumore strano, lo pulisco?")
    assert not describes_a_vague_picture("quanto deve mangiare al giorno?")


def test_a_vague_picture_asks_first_and_only_once() -> None:
    message = "Tripode da qualche giorno è strano, non so spiegarlo bene. Dorme di più."
    _, client = _ask(message)
    assert "A VAGUE PICTURE" in client.requests_for("answer")[0].system_prompt

    history = [
        ChatMessage(role="user", content=message),
        ChatMessage(role="assistant", content="Mangia e beve come sempre? Da quando?"),
    ]
    _, again = _ask("mangia meno, da tre giorni, è sempre strano", history=history)
    assert "A VAGUE PICTURE" not in again.requests_for("answer")[0].system_prompt


# --- 9. length, the shortening preface, the photo never attached ---------------------------------


def test_the_shortening_threshold_is_the_asked_length() -> None:
    assert ANSWER_WORDS_LIMIT == 180


def test_the_shortening_models_preface_never_reaches_the_owner() -> None:
    long_answer = " ".join(["parola"] * 220) + "."
    client = RecordingLLMClient(
        long_answer,
        by_purpose={"shorten": "Ecco la versione più breve.\n\nTienila al riparo dal sole."},
    )
    result, _ = _ask("quanto sole deve prendere una testuggine?", client=client)

    assert result.answer.startswith("Tienila al riparo dal sole.")


def test_a_photo_announced_but_not_attached_is_said_to_be_missing() -> None:
    _, client = _ask(
        "Ti allego la foto della zampa: c'è un gonfiore. Cosa vedi?",
        species="Rettili e anfibi",
        name="Gamera",
    )
    assert "no photo reached you" in client.requests_for("answer")[0].user_prompt
