"""What is decided and assembled before the model writes a natural answer (QK-19).

Moved out of ``ChatOrchestrator._generate_natural_answer``, unchanged in behaviour (the
recorded behaviour of the whole chat path is pinned by
``tests/unit/test_natural_answer_characterization.py``). Four steps, each with explicit inputs
and an explicit result:

1. :func:`decide_natural_answer` - the turn's decisions (what kind of request, whether it is a
   health question, the behaviour cases, the second try, whether the questions come first);
2. :func:`select_prompt_sources` - which of the sources found go into the prompt (the duty
   notes of this country, the two at most);
3. :func:`attachment_note` - the note about a file or photo that did not reach the model;
4. :func:`assemble_natural_prompts` - the system prompt, the user prompt and the token ceiling.

This module does no I/O: no repository, no model, no anonymizer, no clock. Everything that
reads or writes something (the answer cache, the retrieval of sources, the medical record, the
anonymization of every text that leaves for a provider, the call to the model) stays in
``ChatOrchestrator``, which keeps the coordination and the order of those calls. The texts
this module receives are already anonymized.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date
from typing import TYPE_CHECKING, Any, Protocol

from packages.core.application.services.natural_answer_prompt import (
    build_system_prompt,
    stable_prefix,
)
from packages.core.application.services.safety_gate import SafetyGate
from packages.core.domain.common.language import reply_in_this_language
from packages.core.domain.conversation.request_kind import (
    RequestKind,
    asks_to_stop_questions,
    is_behavioural_or_duty,
)
from packages.core.domain.knowledge.duty_notes import DUTY_CATALOG, pinned_duty_notes
from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.pet_profile.species import normalize_species
from packages.core.domain.pet_profile.species_facts import species_facts
from packages.core.domain.safety.dosage_request import is_prevention_schedule_question
from packages.core.domain.safety.emergency_patterns import normalize_for_matching
from packages.core.domain.safety.first_aid import (
    has_a_question_besides_the_dose,
    medical_cause_first,
    named_foreign_country,
    travel_to_sand_fly_area,
)
from packages.core.domain.safety.harmful_requests import (
    HARMFUL_NOTES,
    aggression_toward_animals,
    aggression_toward_people,
    asks_for_a_bare_yes_or_no,
    behaviour_needs_questions,
    describes_a_vague_picture,
    detect_harmful_request,
    expresses_hopelessness,
    is_about_a_future_animal,
    is_human_health_question,
    is_long_message,
    is_minor_writing,
    is_plant_diet_for_a_carnivore,
    mentions_a_child_at_risk,
    mentions_a_death,
    mentions_a_warning_signal,
    mentions_play,
    vomiting_and_not_eating_for_a_day,
)

if TYPE_CHECKING:
    from packages.core.application.services.chat_orchestrator import ChatOrchestratorInput

# "Ti allego la foto", "here is a photo": the owner believes a photo was sent.
_PHOTO_MENTION = re.compile(
    r"\b(?:foto|fotografia|immagine|photo|picture|pic|image|imagen|fotograf\w*|bild|bilder)\b"
)


class NaturalAnswerRules(Protocol):
    """The rules of the orchestrator that the decisions consult. All of them only read the
    request and the conversation, except ``_strong_allowed``: it counts the answer against the
    plan's allowance when it says yes, so it is asked exactly once, and only when the turn is a
    second try (as before the move)."""

    def _request_kind(self, data: ChatOrchestratorInput) -> RequestKind: ...

    def _owner_not_helped(self, data: ChatOrchestratorInput) -> bool: ...

    def _is_health_question(
        self, kind: RequestKind, intent: str, prefetch: Any, message: str = ""
    ) -> bool: ...

    def _earlier_behaviour_warning(self, data: ChatOrchestratorInput) -> bool: ...

    def _continues_a_behaviour_case(self, data: ChatOrchestratorInput) -> bool: ...

    def _strong_allowed(self, data: ChatOrchestratorInput) -> bool: ...

    def _may_ask(self, data: ChatOrchestratorInput, kind: RequestKind) -> bool: ...

    def _is_dosage_request(self, message: str) -> bool: ...

    def _asks_an_amount_of_a_recent_medicine(
        self, lowered: str, user_history: list[str]
    ) -> bool: ...

    def _is_educational_toxin_question(self, safety_flags: list[str], message: str) -> bool: ...

    def _follows_a_triage_reply(self, data: ChatOrchestratorInput) -> bool: ...


# --- 1. the turn's decisions ---------------------------------------------------------------


@dataclass(frozen=True)
class NaturalDecisions:
    kind: RequestKind
    # Plan "fratello maggiore": the owner was not helped by a health answer.
    not_helped: bool
    health_question: bool
    behavioural: bool
    # Plan 08 (v2): an animal that has bitten or attacked people or other animals.
    dangerous_behaviour: bool
    behaviour_anamnesis: bool
    warning_signal: bool
    second_try: bool
    escalated: bool
    vague_picture: bool


def decide_natural_answer(
    rules: NaturalAnswerRules,
    data: ChatOrchestratorInput,
    message: str,
    intent: str,
    *,
    answer_v2: bool,
    request_kind: RequestKind | None,
    prefetch: Any,
) -> NaturalDecisions:
    # A general curiosity (no history, no document, nothing about this
    # animal in particular) may share its answer with every owner of the
    # same species for a day (build 32). Personal cases never do.
    kind = request_kind or rules._request_kind(data)
    # Plan "fratello maggiore": the owner was not helped by a health answer
    # (the same question again, or "non hai capito"): that complaint
    # continues the health topic even without a health word in it.
    not_helped = rules._owner_not_helped(data)
    health_question = rules._is_health_question(kind, intent, prefetch, message) or not_helped
    # A growl, a snap or a bite in a behaviour question (owner's test
    # 2026-11-16): the first time in the conversation the reply asks the
    # facts that decide the advice before explaining anything; later
    # turns build on the answers, without invented motives.
    # Round 2 of the synthetic users: also a vague picture toward the animal
    # or the owner ("ringhia ogni tanto", "fa i dispetti"), even when the
    # message reads as a symptom rather than a behaviour question.
    behavioural = kind is RequestKind.DIRECT and is_behavioural_or_duty(message)
    earlier_warning = rules._earlier_behaviour_warning(data)
    # Plan 08 (CHAT_ANSWER_V2): an animal that has bitten or attacked people or other
    # animals gets safety first and the specialist with a criterion; that rule wins
    # over "ask first" (an attack is not a picture to explore before acting).
    dangerous_behaviour = answer_v2 and (
        aggression_toward_people(message) or aggression_toward_animals(message)
    )
    behaviour_anamnesis = (
        kind in (RequestKind.DIRECT, RequestKind.SYMPTOM)
        and behaviour_needs_questions(message)
        and not earlier_warning
        and not asks_to_stop_questions(data.user_message)
        and not dangerous_behaviour
    )
    # The turn right after a behaviour case, or a warning in a behaviour
    # question: no invented motive, consistency, the behaviour vet.
    warning_signal = (
        not behaviour_anamnesis
        and not dangerous_behaviour
        and (
            rules._continues_a_behaviour_case(data)
            or (behavioural and mentions_a_warning_signal(message) and not mentions_play(message))
        )
    )
    # ... or the button pressed on the last health answer.
    second_try = health_question and (data.escalate_health or not_helped)
    escalated = second_try and rules._strong_allowed(data)
    # "È strano, non so spiegarlo" (synthetic users round 3): questions first,
    # once, as long as questions are allowed in this turn.
    vague_picture = (
        not behaviour_anamnesis
        and not second_try
        and kind in (RequestKind.DIRECT, RequestKind.SYMPTOM)
        and describes_a_vague_picture(message)
        and rules._may_ask(data, kind)
        and not any(
            m.role == "user" and describes_a_vague_picture(m.content)
            for m in data.conversation_history
        )
    )
    return NaturalDecisions(
        kind=kind,
        not_helped=not_helped,
        health_question=health_question,
        behavioural=behavioural,
        dangerous_behaviour=dangerous_behaviour,
        behaviour_anamnesis=behaviour_anamnesis,
        warning_signal=warning_signal,
        second_try=second_try,
        escalated=escalated,
        vague_picture=vague_picture,
    )


# --- 2. which sources go into the prompt ---------------------------------------------------


@dataclass(frozen=True)
class PromptSources:
    sources: list[EvidenceSource]
    # The owner names a foreign country (its duties are not the Italian ones).
    foreign_country: bool


def select_prompt_sources(
    message: str, sources: list[EvidenceSource], *, max_sources: int, species: str
) -> PromptSources:
    """Two sources at most go into the prompt (build 32): the model uses
    one or two at best, and each one costs a few hundred tokens.
    Fifth round: a duty the owner names (dangerous breeds, abandonment,
    a hedgehog found) gets its note by rule, ahead of what the
    keyword search returned."""
    foreign = named_foreign_country(message)
    if foreign:
        # "Do I need to microchip my dog by law in the UK?": the Italian
        # duty notes stay out (wide eval 2026-11-06).
        sources = [source for source in sources if source not in DUTY_CATALOG]
    else:
        pinned = pinned_duty_notes(message, species)
        if pinned:
            sources = pinned + [source for source in sources if source not in pinned]
    return PromptSources(sources=list(sources)[:max_sources], foreign_country=foreign)


# --- 3. the note about an attachment -------------------------------------------------------


def attachment_note(data: ChatOrchestratorInput) -> str:
    if data.attachment_unreadable:
        return (
            "\n\nThe owner attached a file to this message, but its reading failed: "
            "you know nothing of what it shows. Say so and suggest sending it again."
        )
    if data.photo_reading_off:
        return (
            "\n\nThe owner attached a photo, but photo reading is switched off: you "
            "know nothing of what it shows. Never describe it or guess its content; a "
            "sentence saying you cannot see photos is already written before your "
            "text, do not repeat it. Answer only from what the owner wrote."
        )
    if _PHOTO_MENTION.search(normalize_for_matching(data.user_message)) and not (
        data.photo_context
    ):
        # Synthetic users round 3 (f#199): "ti allego la foto" with nothing
        # attached was answered as if the photo had been seen.
        return (
            "\n\nThe owner mentions a photo, but no photo reached you and you cannot "
            "see images: if they say they are sending or showing one, start with one "
            "short sentence saying you cannot see it and asking them to describe what "
            "they see; never describe or guess what a photo shows. Then answer from "
            "what they wrote."
        )
    return ""


# --- 4. the prompts ------------------------------------------------------------------------


@dataclass(frozen=True)
class NaturalPromptInputs:
    """What the prompts are made of. Every text here is already anonymized and every read
    (sources, history, medical record, reminders, the profile block) is already done."""

    data: ChatOrchestratorInput
    message: str
    decisions: NaturalDecisions
    effective_species: str
    other_animal: bool
    generic_context: bool
    foreign_country: bool
    evidence_block: str
    official: str
    anonymized_message: str
    attachment_block: str
    medical_context: str
    reminders_context: str
    attachment_note: str
    history_block: str
    pet_block: str
    today: date


@dataclass(frozen=True)
class NaturalPrompts:
    system_prompt: str
    user_prompt: str
    max_tokens: int
    # How much of the system prompt is the stable prefix the provider may cache.
    cacheable_system_chars: int
    may_ask: bool
    # The owner asks a dose besides a real question (or v2: only a dose): the refusal opens
    # the answer.
    dose_part: bool


def assemble_natural_prompts(
    rules: NaturalAnswerRules,
    inputs: NaturalPromptInputs,
    *,
    answer_v2: bool,
    safety_gate: SafetyGate,
    answer_max_tokens: int,
) -> NaturalPrompts:
    data = inputs.data
    message = inputs.message
    decisions = inputs.decisions
    kind = decisions.kind
    effective_species = inputs.effective_species
    other_animal = inputs.other_animal

    # Tone, structure and how many questions are allowed live in
    # natural_answer_prompt.py, per kind of request. validate_answer
    # below still enforces the citation rule mechanically.
    may_ask = rules._may_ask(data, kind)
    # Which notes travel with this request (repositioning): a toxin
    # asked about, not met; a preventive treatment's schedule; a
    # behaviour or duty question (one context question allowed).
    toxin_flags = safety_gate.evaluate(message.lower(), species=effective_species)
    # "Il CBD funziona per l'artrosi? quante gocce?": the amount is
    # refused in a fixed sentence, the rest is answered.
    dose_part = rules._is_dosage_request(message.lower()) and has_a_question_besides_the_dose(
        data.user_message
    )
    user_history = [m.content for m in data.conversation_history if m.role == "user"]
    dose_only = (
        answer_v2
        and not dose_part
        and (
            rules._is_dosage_request(message.lower())
            or rules._asks_an_amount_of_a_recent_medicine(message.lower(), user_history)
        )
    )
    dose_part = dose_part or dose_only
    owner_health = answer_v2 and is_human_health_question(data.user_message.strip().lower())
    system_prompt = build_system_prompt(
        kind,
        may_ask=may_ask,
        has_reference_material=bool(inputs.evidence_block),
        species_facts=(
            species_facts(effective_species, ethology=kind is RequestKind.DIRECT)
            if other_animal
            else species_facts(
                data.species, data.breed, data.notes, ethology=kind is RequestKind.DIRECT
            )
        ),
        language=data.language,
        behavioural=decisions.behavioural,
        behaviour_anamnesis=decisions.behaviour_anamnesis,
        warning_signal=decisions.warning_signal,
        vague_picture=decisions.vague_picture,
        safety_question=bool(toxin_flags)
        and rules._is_educational_toxin_question(toxin_flags, message),
        prevention_schedule=is_prevention_schedule_question(message),
        harmful_note=HARMFUL_NOTES.get(detect_harmful_request(message) or "", ""),
        minor=is_minor_writing(message),
        minor_account=data.owner_is_minor,
        child_at_risk=mentions_a_child_at_risk(message, data.pet_name),
        long_message=is_long_message(message),
        forced_yes_no=asks_for_a_bare_yes_or_no(message),
        future_animal=is_about_a_future_animal(message),
        visit_today=vomiting_and_not_eating_for_a_day(message),
        plant_diet=is_plant_diet_for_a_carnivore(message, normalize_species(effective_species)),
        grief=mentions_a_death(message),
        hopelessness=expresses_hopelessness(message),
        dose_part=dose_part,
        dose_only=dose_only,
        owner_health=owner_health,
        other_chats=bool(answer_v2 and data.recent_other_chats),
        foreign_country=inputs.foreign_country,
        medical_first=medical_cause_first(message, data.age_years),
        travel_south=travel_to_sand_fly_area(message, normalize_species(effective_species)),
        emergency_follow_up=rules._follows_a_triage_reply(data),
        other_animal=other_animal,
        second_try=decisions.second_try,
        v2=answer_v2,
        urgency_doubt=data.urgency_doubt if answer_v2 else None,
        dangerous_behaviour=decisions.dangerous_behaviour,
        official_sources=bool(inputs.official),
    )
    user_prompt = (
        f"{inputs.pet_block}\n"
        f"{inputs.history_block}"
        f"User message: {inputs.anonymized_message}"
        f"{inputs.attachment_block}"
        f"{inputs.medical_context}"
        f"{inputs.reminders_context}"
        f"{inputs.attachment_note}"
        f"\n\nToday's date: {inputs.today.isoformat()}"
        + inputs.official
        + (
            f"\n\nReference material (optional, use only if genuinely "
            f"relevant):\n{inputs.evidence_block}"
            if inputs.evidence_block
            else ""
        )
        # Said again at the end of the message, where it is closest to the answer (collaudo,
        # wave 1: five answers of eleven for an English account came out in Italian).
        + reply_in_this_language(data.language)
    )
    # A report is explained in four or five paragraphs; anything else
    # fits the prompt's own ceiling of about 1000 characters (build 32:
    # 2000 tokens of budget were never needed). The provider adds the
    # reasoning headroom for the models that think before writing.
    max_tokens = answer_max_tokens + (
        150 if kind is RequestKind.REPORT or is_long_message(message) else 0
    )
    return NaturalPrompts(
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        max_tokens=max_tokens,
        cacheable_system_chars=len(stable_prefix(kind, may_ask=may_ask)),
        may_ask=may_ask,
        dose_part=dose_part,
    )
