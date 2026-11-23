import logging
import threading
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from datetime import UTC, date, datetime, timedelta

from pydantic import BaseModel

from packages.core.application.ports.account_age_repository import AccountAgeRepository
from packages.core.application.ports.chat_attachment_repository import ChatAttachmentRepository
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.owner_limits import OwnerLimitsLookup
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.weight_measurement_repository import (
    WeightMeasurementRepository,
)
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.llm_budget import is_our_failure
from packages.core.application.services.message_claims import MessageClaims
from packages.core.application.services.reminder_context_retriever import (
    ReminderContextRetriever,
)
from packages.core.application.services.safety_gate import SafetyGate
from packages.core.domain.age.models import AgeBand, band_for
from packages.core.domain.common.language import normalize_language
from packages.core.domain.conversation.attachment import ChatAttachment
from packages.core.domain.conversation.models import (
    ChatMessage,
    Conversation,
    history_without_record,
)
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.conversation.title import (
    is_legacy_title,
    title_from_message,
)
from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.localization import translate
from packages.core.domain.medical_record.consent_text import (
    CURRENT_VERSION,
    effective_decision,
)
from packages.core.domain.medical_record.models import MedicalRecordConsentRecord
from packages.core.domain.pet_profile.body_condition import (
    body_condition_code,
    species_has_body_condition,
)
from packages.core.domain.pet_profile.memorial import ensure_not_in_memories
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.pet_profile.species import normalize_species
from packages.core.domain.pet_profile.weight_measurement import (
    format_date_it,
    weight_label_with_date,
)
from packages.core.domain.safety.clarification_fit import describes_a_grave_picture
from packages.core.domain.safety.first_aid import describes_fume_distress, describes_heat_distress
from packages.core.domain.safety.triage_clarification import requires_immediate_escalation
from packages.core.domain.subscription.limits import EMERGENCY_CHATS_ABOVE_PET_LIMIT, PlanLimits
from packages.shared.errors.base import ConversationLimitError, ValidationError

logger = logging.getLogger(__name__)

# How many recent messages cross into the orchestrator (spec v3 §38: never
# resend the entire history). SituationModelBuilder itself only looks at
# the last 6, so this is a generous ceiling, not the real working window.
MAX_HISTORY_MESSAGES = 12


# What the orchestrator answers when it could not answer: the provider failed (the text says
# so and the model is a guard, not a model), or the day's quota ended mid-turn.
_UNANSWERED_MODELS = frozenset({"natural-answer-guard", "evidence-guard"})
_UNANSWERED_MODES = frozenset({"quota_exhausted", "user_limit_reached"})


def not_answered(result: ChatOrchestratorResult) -> bool:
    """True for a result that is an apology or a refusal rather than an answer: only what the
    owner actually received counts against their daily questions."""
    return result.model in _UNANSWERED_MODELS or result.mode in _UNANSWERED_MODES


def owner_names_for_anonymization(display_name: str | None, *, pet_name: str) -> list[str]:
    """The owner's name as a value to redact from text sent to the LLM
    provider — unless it is also the pet's name (people do name a pet
    after themselves, or register with the pet's name): redacting it then
    would blank the one name the conversation is about.
    """
    name = (display_name or "").strip()
    if not name:
        return []
    pet = pet_name.strip().lower()
    if name.lower() == pet or pet in {part.lower() for part in name.split()}:
        return []
    return [name]


def migrate_legacy_title(conversation: Conversation) -> Conversation:
    """Conversations created before 2026-10-06 are titled "Chat for {pet_id}":
    given a title from their first message the first time they are read."""
    if not is_legacy_title(conversation.title):
        return conversation
    first = next((m for m in conversation.messages if m.role == "user"), None)
    if first is None:
        return conversation
    conversation.title = title_from_message(first.content)
    return conversation


class SendChatMessageInput(BaseModel):
    owner_id: str
    pet_id: str
    conversation_id: str | None = None
    user_message: str
    attachment_id: str | None = None
    # The signed-in owner's display name, when the account has one.
    owner_display_name: str | None = None
    # The account's e-mail, only to recognise developer accounts (exempt
    # from the daily message allowance); never sent to the provider.
    owner_email: str | None = None
    # The app's id for this message; the same on a retry.
    client_message_id: str | None = None
    # Language of the reply (see packages.core.domain.common.language).
    language: str = "it"


class SendChatMessageOutput(BaseModel):
    conversation: Conversation
    reply: ChatMessage
    mode: str
    confidence: str
    ai_generated: bool
    # Plan "fratello maggiore": the app shows "Non mi ha aiutato" under it.
    health_answer: bool = False
    sources: list[EvidenceSource]
    limitations: list[str]
    safety_flags: list[str]
    recommended_action: str | None = None
    provider: str
    model: str
    state: ConversationState
    coverage_score: float | None = None
    medical_record_consent: bool | None = None
    awaiting_medical_record_consent: bool = False
    awaiting_safety_clarification: bool = False
    safety_clarification_category: str | None = None


class _InFlightMessages:
    """One lock per (owner, client_message_id) while a message is being answered (QK-03).

    A duplicate of a message still being answered (the app's retry after its timeout, a
    double tap) used to find nothing stored, call the model again and, for a new chat, open
    a second conversation. It now waits for the first request to finish and then finds the
    saved answer: the same reply id, no second model call.

    Limits, on purpose: the registry lives in this process, so two duplicates served by
    different serverless instances at the very same moment are not caught (a durable guard
    needs a unique key in the database); and a duplicate that waits longer than
    [wait_seconds] goes on and answers, as before, rather than hang the app.
    """

    def __init__(self) -> None:
        self._guard = threading.Lock()
        self._entries: dict[tuple[str, str], tuple[threading.Lock, list[int]]] = {}

    @contextmanager
    def hold(self, owner_id: str, client_message_id: str, wait_seconds: float) -> Iterator[bool]:
        key = (owner_id, client_message_id)
        with self._guard:
            lock, users = self._entries.setdefault(key, (threading.Lock(), [0]))
            users[0] += 1
        acquired = lock.acquire(timeout=wait_seconds)
        try:
            yield acquired
        finally:
            if acquired:
                lock.release()
            with self._guard:
                users[0] -= 1
                if users[0] == 0:
                    self._entries.pop(key, None)


_IN_FLIGHT = _InFlightMessages()
# How long a duplicate waits for the first copy of its message to be answered.
DUPLICATE_WAIT_SECONDS = 45.0


def _last_activity(conversation: Conversation) -> datetime:
    """When the chat was last written in (its last message), for "the chat used last"."""
    if conversation.messages:
        return conversation.messages[-1].created_at
    return datetime.min.replace(tzinfo=UTC)


class SendChatMessageService:
    def __init__(
        self,
        repository: ConversationRepository,
        orchestrator: ChatOrchestrator,
        pet_profile_repository: PetProfileRepository,
        *,
        attachment_repository: ChatAttachmentRepository | None = None,
        reminder_context_retriever: ReminderContextRetriever | None = None,
        weight_measurement_repository: WeightMeasurementRepository | None = None,
        max_active_conversations_per_pet: int = 4,
        quota_exempt_emails: frozenset[str] = frozenset(),
        owner_limits: OwnerLimitsLookup | None = None,
        account_age_repository: AccountAgeRepository | None = None,
        photo_reading_enabled: bool = True,
        recent_other_chats: bool = False,
        message_claims: MessageClaims | None = None,
        in_flight: _InFlightMessages | None = None,
        quota_refund: Callable[[], object] | None = None,
        quota_commit: Callable[[], object] | None = None,
    ) -> None:
        self._repository = repository
        # Plan 08, v2 only (CHAT_ANSWER_V2): the last lines of the pet's other recent
        # conversations travel with the message (synthetic users round 4b, 21/11).
        self._recent_other_chats = recent_other_chats
        self._orchestrator = orchestrator
        self._pet_profile_repository = pet_profile_repository
        # None simply means this deployment never offers photo attachments,
        # same convention as ChatOrchestrator's optional
        # medical_record_context_retriever.
        self._attachment_repository = attachment_repository
        # None: this deployment's chat doesn't see reminders (same
        # optional-collaborator convention as above).
        self._reminder_context_retriever = reminder_context_retriever
        # None: the chat only knows the free-text weight of the profile.
        self._weight_measurement_repository = weight_measurement_repository
        self._max_active_conversations_per_pet = max_active_conversations_per_pet
        # Developer accounts are not held to the daily message allowance.
        self._quota_exempt_emails = frozenset(e.strip().lower() for e in quota_exempt_emails)
        # None: this deployment has no plans, so no per-plan limits apply.
        self._owner_limits = owner_limits
        # None: no age is ever declared here, every owner is treated as an adult.
        self._account_age_repository = account_age_repository
        # False: photos are saved but never read (VISION_PROVIDER=off, or no
        # Groq production vision model: docs/compliance/19).
        self._photo_reading_enabled = photo_reading_enabled
        # QK-03b: the reservation shared by every instance (None: only the lock below).
        self._message_claims = message_claims
        # The lock inside this process; a test gives each simulated instance its own.
        self._in_flight = in_flight or _IN_FLIGHT
        # Gives back the daily allowances counted for this request (LlmBudget
        # .refund_request_quota_uses) when the turn ends without an answer.
        self._quota_refund = quota_refund
        # Makes the counted allowances final once the answer is stored: nothing that happens
        # afterwards (a 500 building the response, the client gone) can give them back.
        self._quota_commit = quota_commit

    _MAX_OTHER_PETS = 12

    # A case opened in another chat is raised once, in the first reply of a new one, and
    # only while it is fresh (collaudo, wave 1: the chocolate of one chat came back as
    # "call the vet now" at the head of every reply of another, for hours).
    _OTHER_CHATS_WINDOW = timedelta(hours=24)
    _OTHER_CHATS_MAX = 2  # conversations
    _OTHER_CHATS_LINES = 2  # last messages of each, after the owner's first one

    def _recent_other_chat_lines(
        self, conversation: Conversation, record_allowed: bool, now: datetime
    ) -> list[ChatMessage]:
        """The owner's first line and the last two lines of the pet's OTHER conversations of
        the last 24 hours, oldest first, for the FIRST reply of a new conversation only: a
        serious case opened there is raised once. Same owner, same pet, the same consent
        rule as the history; nothing beyond what the app already stores."""
        if not self._recent_other_chats:
            return []
        if any(m.role == "assistant" for m in conversation.messages):
            return []  # this conversation has already had its first reply
        try:
            # QK-11: a bounded read (this owner, this pet, not this chat, active in the window)
            # instead of every conversation of the pet; two spare rows in case the stored
            # last-message date is stale. The same checks as before still apply below.
            others = [
                c
                for c in self._repository.list_recent_for_context(
                    conversation.owner_id,
                    conversation.pet_id,
                    exclude_conversation_id=conversation.id,
                    active_since=now - self._OTHER_CHATS_WINDOW,
                    limit=self._OTHER_CHATS_MAX + 2,
                )
                if c.id != conversation.id
                and c.owner_id == conversation.owner_id
                and c.pet_id == conversation.pet_id
                and c.messages
                and now - _last_activity(c) <= self._OTHER_CHATS_WINDOW
            ]
        except Exception:  # noqa: BLE001 - the answer never fails on this context
            return []
        others.sort(key=_last_activity)
        lines: list[ChatMessage] = []
        for other in others[-self._OTHER_CHATS_MAX :]:
            messages = other.messages
            if not record_allowed:
                messages = history_without_record(
                    messages, conversation_had_consent=other.medical_record_consent is True
                )
            # The owner's first message is where the case was described (round 4c: the lily
            # was in it, the last two lines only spoke of a medicine); then the last lines.
            first = next((m for m in messages if m.role == "user"), None)
            chosen = [first] if first is not None else []
            chosen += [m for m in messages[-self._OTHER_CHATS_LINES :] if m is not first]
            lines += [m for m in chosen if now - m.created_at <= self._OTHER_CHATS_WINDOW]
        return lines

    def _other_pets(self, owner_id: str, pet_id: str) -> list[str]:
        """The owner's other animals, name and species only ("Orlando (Gatto,
        Europeo)"): the chat knows they exist without asking. Never their
        notes, records or health, which follow each pet's own consent."""
        try:
            pets = self._pet_profile_repository.list_by_owner(owner_id)
        except Exception:  # noqa: BLE001 - a nicety: the chat answers without it
            return []
        return [
            f"{pet.name} ({', '.join(part for part in (pet.species, pet.breed) if part)})"
            for pet in pets
            if pet.id != pet_id and pet.owner_id == owner_id and pet.name.strip()
        ][: self._MAX_OTHER_PETS]

    @staticmethod
    def _history_for_provider(
        conversation: Conversation, record_allowed: bool
    ) -> list[ChatMessage]:
        """The earlier turns sent with this message. Data minimization (spec v3
        §38): only recent turns. With the record consent not granted (never, or
        revoked), the turns written while it was are left out (Orchestrator
        decision 2026-11-16): a revocation also stops what the chat already
        said about the record from leaving again."""
        history = conversation.messages[:-1]
        if not record_allowed:
            history = history_without_record(
                history, conversation_had_consent=conversation.medical_record_consent is True
            )
        return history[-MAX_HISTORY_MESSAGES:]

    def _owner_is_minor(self, owner_id: str, today: date) -> bool:
        """A declared age of 14 to 17 (the age guard has already closed
        accounts under 14). Read on every turn: a birthday changes it."""
        if self._account_age_repository is None or not owner_id:
            return False
        age = self._account_age_repository.get(owner_id)
        return age is not None and band_for(age.birth_date, today) == AgeBand.MINOR

    def _limits_for(self, data: SendChatMessageInput) -> PlanLimits | None:
        if self._owner_limits is None:
            return None
        return self._owner_limits(data.owner_id, data.owner_email)

    def _weight_label(self, owner_id: str, pet_profile: PetProfile, today: date) -> str | None:
        """The latest weighing with its date ("23 kg al 14 ottobre") when the
        owner records them, else the free-text weight of the profile."""
        if self._weight_measurement_repository is not None:
            try:
                latest = self._weight_measurement_repository.latest_for_pet(
                    owner_id, pet_profile.id
                )
            except Exception:
                latest = None
            if latest is not None:
                return weight_label_with_date(latest, today)
        return pet_profile.weight_label

    def _body_condition_context(
        self, owner_id: str, pet_profile: PetProfile, today: date
    ) -> tuple[str | None, str | None]:
        """(code, date) of the pet's one body condition: the latest weighing
        that recorded it (with its date), else the owner's estimate on the
        profile (no date). Never two different values. None for a species with
        no body condition guide."""
        if not species_has_body_condition(pet_profile.species, pet_profile.breed):
            return None, None
        if self._weight_measurement_repository is not None:
            try:
                latest = self._weight_measurement_repository.latest_with_body_condition_for_pet(
                    owner_id, pet_profile.id
                )
            except Exception:
                latest = None
            code = body_condition_code(latest.body_condition) if latest is not None else None
            if latest is not None and code is not None:
                return code, format_date_it(latest.measured_at, today)
        return pet_profile.body_condition, None

    def execute(self, data: SendChatMessageInput) -> SendChatMessageOutput:
        # A photo alone is a message (an edited message may keep only its
        # attachment); no text and no attachment is not.
        if not data.user_message.strip() and not data.attachment_id:
            raise ValidationError("user_message must not be empty")
        pet_profile = self._pet_profile_repository.get(data.pet_id)
        # Ownership is enforced here because the backend's Supabase client
        # runs with the service role (no row-level security): another
        # owner's pet id must look exactly like a missing one.
        if pet_profile is None or pet_profile.owner_id != data.owner_id:
            raise ValidationError("pet_profile not found")
        # Past chats of a pet in Ricordi stay readable; no new messages.
        ensure_not_in_memories(pet_profile)

        if not data.client_message_id:
            return self._answer_new_message(data, pet_profile)
        # The same message twice at once waits for the first to be answered (see
        # _InFlightMessages); then the retry below finds it stored.
        with self._in_flight.hold(data.owner_id, data.client_message_id, DUPLICATE_WAIT_SECONDS):
            return self._answer_new_message(data, pet_profile)

    def _answer_new_message(
        self, data: SendChatMessageInput, pet_profile: PetProfile
    ) -> SendChatMessageOutput:
        # The conversations that can hold this message are read ONCE and serve both the
        # retry check and the loading of the chat (QK-03: they used to be read twice).
        candidates = self._load_candidates(data)

        # A retry of a message this server already answered (the app gave up
        # waiting, the answer was stored anyway — 2026-10-07): hand back that
        # answer. No second model call, no duplicate turn, and for a new chat
        # no second conversation.
        replay = self.already_answered(data, candidates)
        if replay is not None:
            return replay

        conversation = self._load_or_create_conversation(data, pet_profile, candidates)
        claims = self._message_claims
        if claims is None or not data.client_message_id:
            return self.respond_in(conversation, data, pet_profile)

        # QK-03b: the same message may be in flight on ANOTHER instance. Reserved before the
        # model is called; a duplicate waits and gets the stored answer. The reservation is a
        # lock only: the replay is always read from the stored conversation.
        replay, claim = claims.acquire(
            data.owner_id,
            data.client_message_id,
            conversation.id,
            lambda: self.already_answered(data),
            wait_seconds=DUPLICATE_WAIT_SECONDS,
        )
        if replay is not None:
            return replay
        try:
            output = self.respond_in(conversation, data, pet_profile)
        except BaseException:
            # A failed request must not leave the retry waiting on its reservation.
            if claim is not None:
                claims.release(claim)
            raise
        if claim is not None:
            claims.answered(claim, output.reply.id)
        return output

    def _load_candidates(self, data: SendChatMessageInput) -> list[Conversation]:
        """The stored conversations that could hold this message: the one it names, or the
        pet's conversations for a new chat. Not filtered by owner here: each user of the
        list does it."""
        if data.conversation_id:
            stored = self._repository.get(data.conversation_id)
            return [stored] if stored is not None else []
        return self._repository.list_by_pet(data.pet_id)

    def respond_in(
        self,
        conversation: Conversation,
        data: SendChatMessageInput,
        pet_profile: PetProfile | None = None,
    ) -> SendChatMessageOutput:
        """Adds the owner's message to [conversation] (already loaded, and
        possibly changed by the caller — see EditChatMessageService), answers
        it through the usual path and stores the result.

        The question counted for this turn is settled HERE, by the service, whoever calls it
        (a new message or an edited one) and whether or not the client is still connected (a
        client that hangs up does not stop this work, and nothing outside gives back for a
        client that left): given back if the turn fails through our fault or the provider's,
        final once the answer is stored."""
        try:
            return self._respond_in(conversation, data, pet_profile)
        except BaseException as exc:
            if self._quota_refund is not None and is_our_failure(exc):
                self._quota_refund()
            raise

    def _respond_in(
        self,
        conversation: Conversation,
        data: SendChatMessageInput,
        pet_profile: PetProfile | None = None,
    ) -> SendChatMessageOutput:
        if pet_profile is None:
            pet_profile = self._pet_profile_repository.get(conversation.pet_id)
            if pet_profile is None:
                raise ValidationError("pet_profile not found")
        # Also covers an edited message (EditChatMessageService).
        ensure_not_in_memories(pet_profile)
        attachment = self._resolve_attachment(data, pet_profile)
        photo_context = attachment.analysis if attachment is not None else None
        user_message = ChatMessage(
            role="user",
            content=data.user_message.strip(),
            attachment_id=data.attachment_id,
            client_message_id=data.client_message_id,
        )
        conversation.messages.append(user_message)

        # A pet-level consent decision (settings, or a previous conversation)
        # always wins over per-conversation state, so a revocation takes
        # effect immediately and a grant is never asked twice (spec v3 §18).
        medical_record_consent = conversation.medical_record_consent
        awaiting_medical_record_consent = conversation.awaiting_medical_record_consent
        if pet_profile.medical_record_consent is not None:
            # A decision taken under an earlier consent text (v1) counts as
            # no decision (2026-10-06, compliance audit): the record is not
            # read, and the chat asks again with the current wording.
            medical_record_consent = effective_decision(pet_profile.medical_record_consent)
            awaiting_medical_record_consent = False

        today = datetime.now(UTC).date()
        plan_limits = self._limits_for(data)
        body_condition, body_condition_as_of = self._body_condition_context(
            data.owner_id, pet_profile, today
        )
        # R25, option A (owner decision 2026-11-07): the profile's free notes
        # ("Diagnosi MBD lieve 2024") and the reminders, therapies included,
        # are health information and leave for the provider only with the
        # record consent granted under the current text. Without it the
        # chat knows name, species, breed, sex, age and weight, as the
        # consent text lets the owner expect.
        record_allowed = medical_record_consent is True
        reminders_context = (
            self._reminder_context_retriever.summarize_for_pet(data.owner_id, pet_profile.id, today)
            if record_allowed and self._reminder_context_retriever is not None
            else None
        )

        orchestrator_result = self._orchestrator.answer(
            ChatOrchestratorInput(
                user_message=data.user_message.strip(),
                species=pet_profile.species,
                pet_name=pet_profile.name,
                pet_id=pet_profile.id,
                breed=pet_profile.breed,
                age_years=pet_profile.age_years,
                notes=pet_profile.notes if record_allowed else None,
                birth_date_label=pet_profile.birth_date_label,
                sex=pet_profile.sex,
                weight_label=self._weight_label(data.owner_id, pet_profile, today),
                dog_size_category=pet_profile.dog_size_category,
                is_sterilized=pet_profile.is_sterilized,
                body_condition=body_condition,
                body_condition_as_of=body_condition_as_of,
                activity_level=pet_profile.activity_level,
                reminders_context=reminders_context,
                language=normalize_language(data.language),
                owner_id=data.owner_id,
                owner_is_minor=self._owner_is_minor(data.owner_id, today),
                other_pets=self._other_pets(data.owner_id, pet_profile.id),
                quota_exempt=(getattr(data, "owner_email", None) or "").strip().lower()
                in self._quota_exempt_emails,
                user_daily_limit=plan_limits.daily_questions if plan_limits else None,
                sonnet_daily_limit=(plan_limits.daily_sonnet_answers if plan_limits else None),
                upgrade_plan=plan_limits.upgrade_to if plan_limits else None,
                escalate_health=conversation.escalate_next_health,
                awaiting_anamnesis=conversation.awaiting_anamnesis,
                owner_names=owner_names_for_anonymization(
                    data.owner_display_name, pet_name=pet_profile.name
                ),
                today=today,
                habitat=pet_profile.habitat,
                aquarium_stock=pet_profile.aquarium_stock,
                photo_context=photo_context,
                attachment_unreadable=bool(data.attachment_id)
                and not photo_context
                and self._photo_reading_enabled,
                photo_reading_off=bool(data.attachment_id)
                and not photo_context
                and not self._photo_reading_enabled,
                # Data minimization (spec v3 §38): only recent turns cross
                # the service boundary — the full history never needs to,
                # since SituationModel already carries the compact,
                # structured summary of everything older forward.
                conversation_history=self._history_for_provider(conversation, record_allowed),
                recent_other_chats=self._recent_other_chat_lines(
                    conversation, record_allowed, datetime.now(UTC)
                ),
                situation_model=conversation.situation_model,
                interview_turns_used=conversation.interview_turns_used,
                medical_record_consent=medical_record_consent,
                awaiting_medical_record_consent=awaiting_medical_record_consent,
                awaiting_safety_clarification=conversation.awaiting_safety_clarification,
                safety_clarification_category=conversation.safety_clarification_category,
            )
        )
        if self._quota_refund is not None and not_answered(orchestrator_result):
            # An apology instead of an answer (provider down, models out of quota): the
            # owner received nothing, so the question is not counted against them.
            self._quota_refund()
        reply = ChatMessage(
            role="assistant",
            content=orchestrator_result.answer,
            ai_generated=orchestrator_result.ai_generated,
            health_answer=orchestrator_result.health_answer or None,
            # Written with the record readable (granted before, or in this very
            # turn): never resent after a revocation.
            record_shared=record_allowed or orchestrator_result.medical_record_consent is True,
        )
        conversation.messages.append(reply)
        conversation.awaiting_anamnesis = orchestrator_result.awaiting_anamnesis
        if orchestrator_result.health_answer:
            # The second try has been given (or was refused by the cap): the
            # button's effect is spent.
            conversation.escalate_next_health = False
        conversation.situation_model = orchestrator_result.situation_model
        conversation.coverage_score = orchestrator_result.coverage_score
        conversation.state = orchestrator_result.state
        conversation.interview_turns_used = orchestrator_result.interview_turns_used
        conversation.medical_record_consent = orchestrator_result.medical_record_consent
        conversation.awaiting_medical_record_consent = (
            orchestrator_result.awaiting_medical_record_consent
        )
        conversation.awaiting_safety_clarification = (
            orchestrator_result.awaiting_safety_clarification
        )
        conversation.safety_clarification_category = (
            orchestrator_result.safety_clarification_category
        )
        reply.state_after = conversation.snapshot()
        self._persist_pet_level_consent(pet_profile, orchestrator_result.medical_record_consent)

        if (
            orchestrator_result.mode in ("user_limit_reached", "quota_exhausted")
            and not data.conversation_id
            and len(conversation.messages) <= 2
        ):
            # A message the limit stopped does not create an empty chat
            # (synthetic users 2026-11-07, P5): the reply is returned, the
            # conversation is not stored.
            stored_conversation = conversation
        else:
            stored_conversation = self._repository.save(conversation)
            self._link_attachment(attachment, stored_conversation)
        if self._quota_commit is not None:
            # The answer is stored: the question is spent, whatever happens next.
            self._quota_commit()
        return SendChatMessageOutput(
            conversation=stored_conversation,
            reply=reply,
            mode=orchestrator_result.mode,
            confidence=orchestrator_result.confidence,
            ai_generated=orchestrator_result.ai_generated,
            health_answer=orchestrator_result.health_answer,
            sources=orchestrator_result.sources,
            limitations=orchestrator_result.limitations,
            safety_flags=orchestrator_result.safety_flags,
            recommended_action=orchestrator_result.recommended_action,
            provider=orchestrator_result.provider,
            model=orchestrator_result.model,
            state=orchestrator_result.state,
            coverage_score=orchestrator_result.coverage_score,
            medical_record_consent=orchestrator_result.medical_record_consent,
            awaiting_medical_record_consent=orchestrator_result.awaiting_medical_record_consent,
            awaiting_safety_clarification=orchestrator_result.awaiting_safety_clarification,
            safety_clarification_category=orchestrator_result.safety_clarification_category,
        )

    def already_answered(
        self,
        data: SendChatMessageInput,
        candidates: list[Conversation] | None = None,
    ) -> SendChatMessageOutput | None:
        """The stored answer to a message this server already answered (same
        client_message_id, same owner), or None. [candidates] are the conversations already
        read by the caller; without them they are read here."""
        if not data.client_message_id:
            return None
        if candidates is None:
            candidates = self._load_candidates(data)
        for conversation in candidates:
            if conversation.owner_id != data.owner_id:
                continue
            messages = conversation.messages
            for index, message in enumerate(messages):
                if message.role != "user" or message.client_message_id != data.client_message_id:
                    continue
                reply = next((m for m in messages[index + 1 :] if m.role == "assistant"), None)
                if reply is None:
                    return None
                return SendChatMessageOutput(
                    conversation=conversation,
                    reply=reply,
                    mode="replayed",
                    confidence="medium",
                    ai_generated=bool(reply.ai_generated),
                    health_answer=bool(reply.health_answer),
                    sources=[],
                    limitations=[],
                    safety_flags=[],
                    provider="replay",
                    model="replay",
                    state=conversation.state,
                    coverage_score=conversation.coverage_score,
                    medical_record_consent=conversation.medical_record_consent,
                    awaiting_medical_record_consent=conversation.awaiting_medical_record_consent,
                    awaiting_safety_clarification=conversation.awaiting_safety_clarification,
                    safety_clarification_category=conversation.safety_clarification_category,
                )
        return None

    def _resolve_attachment(
        self, data: SendChatMessageInput, pet_profile: PetProfile
    ) -> ChatAttachment | None:
        """The attachment of this message (or None), checked against its owner and pet."""
        if not data.attachment_id:
            return None
        if self._attachment_repository is None:
            raise ValidationError("attachments are not enabled for this deployment")
        attachment = self._attachment_repository.get(data.attachment_id)
        if attachment is None:
            raise ValidationError("attachment not found")
        if attachment.owner_id != data.owner_id or attachment.pet_id != pet_profile.id:
            raise ValidationError("attachment does not belong to this pet")
        return attachment

    def _link_attachment(
        self, attachment: ChatAttachment | None, conversation: Conversation
    ) -> None:
        """Ties an attachment to the conversation it was first sent in. An attachment is
        uploaded before a new chat officially exists, so it starts scoped only by pet (see
        UploadChatAttachmentService) and is linked once the conversation's row is stored:
        chat_attachments.conversation_id references it, and linking first made every new
        chat that started with a photo or a PDF fail (round 1 of the test network, 23/11).
        The answer is already stored here: a link that fails never loses it."""
        if attachment is None or attachment.conversation_id is not None:
            return
        if self._attachment_repository is None:
            return
        linked = attachment.model_copy(update={"conversation_id": conversation.id})
        # Twice: an attachment left without a conversation is cleaned up later as an orphan.
        for last in (False, True):
            try:
                self._attachment_repository.save(linked)
                return
            except Exception:
                if last:
                    logger.warning("chat attachment not linked to its conversation")

    def _load_or_create_conversation(
        self,
        data: SendChatMessageInput,
        pet_profile: PetProfile | None = None,
        candidates: list[Conversation] | None = None,
    ) -> Conversation:
        if candidates is None:
            candidates = self._load_candidates(data)
        if data.conversation_id:
            stored = candidates[0] if candidates else None
            if stored and stored.owner_id == data.owner_id and stored.pet_id == data.pet_id:
                return migrate_legacy_title(stored)
            raise ValidationError("conversation not found")

        existing_for_pet = [
            conversation for conversation in candidates if conversation.owner_id == data.owner_id
        ]
        # With a plan the plan decides (Plus 2, Pro 4, Ultra 6): the setting is only the
        # fallback where no plan is wired. Taking the smaller of the two kept Ultra at 4
        # (synthetic users round 3, 2026-11-16).
        plan_limits = self._limits_for(data)
        if plan_limits is not None:
            max_per_pet = plan_limits.max_chats_per_pet
        else:
            max_per_pet = self._max_active_conversations_per_pet
        if len(existing_for_pet) >= max_per_pet:
            if existing_for_pet and self._is_an_emergency(data.user_message, pet_profile):
                # An emergency never waits for a free slot (synthetic users
                # 2026-11-07 P5, 2026-11-16 giro 2): it gets a chat of its own, a few
                # above the limit, so it is neither refused nor buried in an old
                # chat about something else. Past that allowance it goes on in the
                # chat used last.
                if len(existing_for_pet) < max_per_pet + EMERGENCY_CHATS_ABOVE_PET_LIMIT:
                    return Conversation(
                        owner_id=data.owner_id,
                        pet_id=data.pet_id,
                        title=title_from_message(data.user_message),
                    )
                return migrate_legacy_title(max(existing_for_pet, key=_last_activity))
            pet_name = pet_profile.name if pet_profile is not None else ""
            raise ConversationLimitError(
                translate(
                    "conversation_limit", data.language, limit=max_per_pet, pet_name=pet_name
                ),
                limit=max_per_pet,
            )
        return Conversation(
            owner_id=data.owner_id,
            pet_id=data.pet_id,
            title=title_from_message(data.user_message),
        )

    @staticmethod
    def _is_an_emergency(message: str, pet_profile: PetProfile | None) -> bool:
        species = pet_profile.species if pet_profile is not None else "other"
        lowered = message.lower()
        # The grave pictures and a heatstroke too (Pricing, synthetic users round 2):
        # the wider this is, the less the per-pet chat limit can ever weigh.
        return (
            bool(SafetyGate().evaluate(lowered, species=species))
            or requires_immediate_escalation(lowered)
            or describes_a_grave_picture(message)
            or describes_heat_distress(message)
            or (normalize_species(species) == "bird" and describes_fume_distress(message))
        )

    def _persist_pet_level_consent(self, pet_profile: PetProfile, granted: bool | None) -> None:
        if granted is None:
            return
        current = pet_profile.medical_record_consent
        if (
            current is not None
            and current.granted == granted
            and current.version == CURRENT_VERSION
        ):
            return
        updated = pet_profile.model_copy(
            update={
                "medical_record_consent": MedicalRecordConsentRecord(
                    granted=granted, version=CURRENT_VERSION
                )
            }
        )
        self._pet_profile_repository.save(updated)
