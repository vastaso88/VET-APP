from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.ports.pii_anonymizer import (
    PiiAnonymizationRequest,
    PiiAnonymizationResult,
)
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.conversation.states import ConversationState
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer


class FakeLLMClient:
    def __init__(self) -> None:
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        return LLMResponse(
            content='{"supported_claims": ["Risposta sintetica con fonti [1]."]}',
            provider="fake",
            model="fake-model",
            token_count=12,
            finish_reason="stop",
        )


class FakePiiAnonymizer:
    """Records every text it was asked to anonymize and replaces a fixed
    substring with a placeholder, so a test can assert the LLM never sees it."""

    def __init__(self, redact: str, replacement: str = "<REDACTED>") -> None:
        self.requests: list[PiiAnonymizationRequest] = []
        self._redact = redact
        self._replacement = replacement

    def anonymize(self, request: PiiAnonymizationRequest) -> PiiAnonymizationResult:
        self.requests.append(request)
        text = request.text
        redaction_count = 0
        if self._redact in text:
            text = text.replace(self._redact, self._replacement)
            redaction_count = 1
        return PiiAnonymizationResult(anonymized_text=text, redaction_count=redaction_count)


def test_chat_orchestrator_asks_a_safety_clarification_before_escalating() -> None:
    # An ambiguous red-flag message asks one short, category-specific
    # question before deciding how urgently to respond (spec v3 §9) —
    # it must not jump straight to the scariest message.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il gatto ha un collasso improvviso",
            species="cat",
            pet_name="Luna",
        )
    )

    assert result.mode == "safety_clarification"
    assert result.provider == "rule-based"
    assert result.ai_generated is False
    assert result.awaiting_safety_clarification is True
    assert result.safety_clarification_category == "collapse"
    assert not client.requests


def test_chat_orchestrator_flags_gi_stasis_for_small_mammals_not_dogs() -> None:
    # Real-world finding: a rabbit not eating/defecating for a day is a
    # true emergency (GI stasis), but the exact same phrase for a dog is
    # ordinarily just something to monitor — species must change the
    # outcome here, not just the wording of the answer.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())
    message = "Il mio coniglio non mangia da un giorno e non fa la cacca"

    rabbit_result = orchestrator.answer(
        ChatOrchestratorInput(user_message=message, species="Piccoli mammiferi", pet_name="Pallina")
    )
    dog_result = orchestrator.answer(
        ChatOrchestratorInput(user_message=message, species="dog", pet_name="Rex")
    )

    assert rabbit_result.mode == "safety_clarification"
    assert rabbit_result.safety_clarification_category == "gi_stasis"
    assert dog_result.mode != "safety_clarification"
    assert dog_result.mode != "triage"


def test_chat_orchestrator_escalates_dog_only_flea_treatment_given_to_a_cat() -> None:
    # Real-world finding: reporting that a dog-only permethrin spot-on
    # (Advantix) was already applied to a cat — a genuinely lethal
    # combination — was treated as an ordinary question with no
    # escalation at all, whether asked beforehand or already done.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Ho messo una goccia di advantix al mio gatto, ne devo mettere altre?",
            species="Gatto",
            pet_name="Micio",
        )
    )

    assert result.mode == "triage"
    assert result.state == ConversationState.POSSIBLE_URGENT_CASE


def test_chat_orchestrator_escalates_paracetamol_brand_name_for_cats() -> None:
    # Owners commonly say the brand name ("Tachipirina") rather than the
    # generic name — this must be caught the same way as "paracetamolo".
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=(
                "Vorrei dare la tachipirina al mio gatto che ha la febbre, "
                "che dosaggio uso?"
            ),
            species="Gatto",
            pet_name="Micio",
        )
    )

    assert result.mode == "triage"
    assert result.state == ConversationState.POSSIBLE_URGENT_CASE


def test_chat_orchestrator_escalates_immediately_for_unambiguous_severe_messages() -> None:
    # No clarification question when the first message already leaves no
    # doubt — asking here would only delay real emergency care.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il gatto è incosciente e non si sveglia dopo il collasso",
            species="cat",
            pet_name="Luna",
        )
    )

    assert result.mode == "triage"
    assert result.state == ConversationState.POSSIBLE_URGENT_CASE


def test_chat_orchestrator_escalates_when_clarification_reply_is_unclear() -> None:
    # Fail closed: an off-topic or unclear reply must escalate, never be
    # read as reassurance.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Boh, non so cosa dirti",
            species="cat",
            pet_name="Luna",
            awaiting_safety_clarification=True,
            safety_clarification_category="collapse",
        )
    )

    assert result.mode == "triage"
    assert result.state == ConversationState.POSSIBLE_URGENT_CASE


def test_chat_orchestrator_never_downgrades_gi_stasis_even_on_a_reassuring_sounding_reply() -> None:
    # Unlike "collapse"/"respiratory", GI stasis in a small mammal has no
    # reply that makes it genuinely safe to relax — it can progress to
    # fatal within hours regardless of how mild it currently sounds.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Solo poche ore, e ha provato ad avvicinarsi al cibo",
            species="Piccoli mammiferi",
            pet_name="Pallina",
            awaiting_safety_clarification=True,
            safety_clarification_category="gi_stasis",
        )
    )

    assert result.mode == "triage"
    assert result.state == ConversationState.POSSIBLE_URGENT_CASE


def test_chat_orchestrator_downgrades_to_moderate_caution_on_clear_benign_explanation() -> None:
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="È sveglio, reattivo e cammina normale, è durato pochi secondi",
            species="cat",
            pet_name="Luna",
            awaiting_safety_clarification=True,
            safety_clarification_category="collapse",
        )
    )

    assert result.mode == "safety_clarification_resolved"
    # A moderate resolution reassures first and keeps the vet-contact advice
    # conditional ("if it doesn't improve") — it must not open with the
    # unconditional urgent-triage wording used for genuine emergencies.
    assert "valutazione veterinaria immediata" not in result.answer.lower()
    assert "veterinario" in result.answer.lower()  # still vet-aware, never dismissive


def test_chat_orchestrator_escalates_when_reply_says_it_is_worsening() -> None:
    # A worsening marker overrides any reassuring wording in the same reply.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="È sveglio ma sta peggiorando",
            species="cat",
            pet_name="Luna",
            awaiting_safety_clarification=True,
            safety_clarification_category="collapse",
        )
    )

    assert result.mode == "triage"


def test_chat_orchestrator_never_downgrades_seizures() -> None:
    # No benign explanation exists for a seizure — the category has no
    # reassuring markers at all, so any reply escalates.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Sono già finite ed è tornato vigile, prima volta che capita",
            species="dog",
            pet_name="Milo",
            awaiting_safety_clarification=True,
            safety_clarification_category="seizure",
        )
    )

    assert result.mode == "triage"


def test_chat_orchestrator_requires_sources_for_evidence_mode() -> None:
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio gatto vomita da due giorni, cosa posso fare?",
            species="cat",
            pet_name="Luna",
        )
    )

    assert result.mode == "evidence"
    assert result.provider == "rule-based"
    assert result.ai_generated is False
    assert not result.sources
    assert not client.requests


def test_chat_orchestrator_uses_llm_when_sources_are_available() -> None:
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce da due giorni",
            species="dog",
            pet_name="Milo",
        )
    )

    assert result.mode == "evidence"
    assert result.provider == "fake"
    assert result.ai_generated is True
    assert result.sources
    assert client.requests


def test_chat_orchestrator_answers_reptile_husbandry_questions_from_curated_catalog() -> None:
    # Real-world finding (stress test): "che lampada UVB per il mio geco?"
    # hit "no source, no answer" because PubMed/Europe PMC/Crossref/
    # OpenAlex only index peer-reviewed biomedical literature, which
    # essentially never covers terrarium setup. Husbandry/equipment
    # questions now get their own intent and a curated evidence catalog
    # instead of being silently unanswerable.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Che lampada UVB devo usare per il mio geco leopardino?",
            species="Rettili e anfibi",
            pet_name="Spike",
        )
    )

    assert result.mode == "evidence"
    assert result.ai_generated is True
    assert result.sources
    assert all(source.clinical_domain == "husbandry" for source in result.sources)
    assert any("divulgativi curati" in limitation for limitation in result.limitations)


def test_chat_orchestrator_recognizes_husbandry_questions_phrased_without_uvb_jargon() -> None:
    # Real-world finding (live verification): the same underlying question
    # ("should I let my chameleon get direct sun by the window") is very
    # commonly phrased without any UVB/equipment jargon at all.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=(
                "Il mio camaleonte ha bisogno di stare al sole diretto vicino alla finestra?"
            ),
            species="Rettili e anfibi",
            pet_name="Iggy",
        )
    )

    assert result.mode == "evidence"
    assert result.sources
    assert all(source.clinical_domain == "husbandry" for source in result.sources)


def test_chat_orchestrator_does_not_flag_consolare_as_a_husbandry_sole_match() -> None:
    # Guards the "moment"/"momento" collision discipline applied to this
    # husbandry keyword set too: the bare word "sole" is deliberately NOT a
    # keyword (only multi-word phrases like "sole diretto") because it
    # would otherwise match "consolare"/"consolerò" ("comfort my dog"), a
    # plausible behavior-question phrase with nothing to do with lighting.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Non so come consolare il mio cane, sembra triste da ieri",
            species="dog",
            pet_name="Rex",
        )
    )

    assert not any(source.clinical_domain == "husbandry" for source in result.sources)


def test_chat_orchestrator_answers_bird_enrichment_questions_from_curated_catalog() -> None:
    # Real-world finding (stress test round 3): "come posso arricchire la
    # gabbia del mio pappagallo per non farlo annoiare?" matched none of
    # the husbandry keywords (all reptile/aquarium-specific at the time)
    # and fell through to a symptom-interview question ("da quanto tempo
    # lo stai notando?") — a wrong fit for a question with no symptom at
    # all. Also the curated catalog had zero bird entries.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=(
                "Come posso arricchire la gabbia del mio pappagallo per non farlo annoiare?"
            ),
            species="Uccello",
            pet_name="Pio",
        )
    )

    assert result.mode == "evidence"
    assert result.ai_generated is True
    assert result.sources
    assert all(source.clinical_domain == "husbandry" for source in result.sources)
    assert all(source.species == "bird" for source in result.sources)


def test_chat_orchestrator_answers_enclosure_size_questions_from_curated_catalog() -> None:
    # Real-world finding (stress test round 3): "che dimensioni deve avere
    # il terrario per il mio primo geco?" retrieved genuinely relevant
    # UVB/thermal content but the system honestly had no grounded answer
    # on enclosure SIZE — a real gap now filled by a dedicated entry.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=(
                "Sto per prendere il mio primo geco leopardino, "
                "che dimensioni deve avere il terrario?"
            ),
            species="Rettili e anfibi",
            pet_name="Spike",
        )
    )

    assert result.mode == "evidence"
    assert result.ai_generated is True
    assert any(
        "enclosure size" in (source.title or "") for source in result.sources
    )


def test_chat_orchestrator_answers_aquarium_husbandry_questions_from_curated_catalog() -> None:
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Come ciclo un acquario nuovo prima di mettere i pesci?",
            species="Pesce",
            pet_name="Bolla",
        )
    )

    assert result.mode == "evidence"
    assert result.ai_generated is True
    assert result.sources
    assert all(source.clinical_domain == "husbandry" for source in result.sources)


def test_chat_orchestrator_normalizes_the_mobile_apps_italian_species_label() -> None:
    # Real-world finding: the real Flutter app stores the Italian UI label
    # ("Cane", "Gatto"...) directly as PetProfile.species, but every
    # species-keyed lookup in the backend (here, the demo catalog's
    # `species == "dog"` filter) was written against English species
    # codes — so with the real app, species-specific evidence never
    # matched anything at all. This must normalize "Cane" to "dog" before
    # it reaches evidence retrieval.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce da due giorni",
            species="Cane",
            pet_name="Milo",
        )
    )

    assert result.mode == "evidence"
    assert result.sources


def test_chat_orchestrator_sends_anonymized_text_to_llm_not_raw_pii() -> None:
    client = FakeLLMClient()
    anonymizer = FakePiiAnonymizer(redact="0491234567", replacement="<TELEFONO>")
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), anonymizer)

    orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce, richiamami al 0491234567",
            species="dog",
            pet_name="Milo",
        )
    )

    assert anonymizer.requests
    assert client.requests
    sent_prompt = client.requests[0].user_prompt
    assert "0491234567" not in sent_prompt
    assert "<TELEFONO>" in sent_prompt


def test_classify_intent_recognizes_dermatological_and_parasitic_terms() -> None:
    # Real-world finding: a real forum question about ringworm ("tigna")
    # matched none of the clinical keywords and silently fell through to
    # general_info, skipping evidence retrieval entirely for a genuinely
    # evidence-backed clinical topic.
    for message in ("il gatto ha la tigna", "il cane si gratta e ha prurito", "ha le zecche"):
        assert ChatOrchestrator._classify_intent(message) == "clinical_question", message


def test_classify_intent_recognizes_generic_concern_phrases_for_exotic_species() -> None:
    # Real-world finding: real questions about exotic species describe a
    # worrying observation with vocabulary the symptom keyword list never
    # anticipated (a chicken's blackened toe, a turtle's sticky shell,
    # glass-like stool, a rabbit's testicular lumps) — none matched any
    # clinical keyword, so all four silently fell through to
    # "general_info" and skipped evidence retrieval, breaking "no
    # source, no answer" for a genuine clinical concern. These are the
    # exact real messages (paraphrased length aside) that failed live.
    messages = [
        "la mia gallina ha una delle dita con una zona nera, non so cosa possa "
        "essere e sono preoccupata",
        "vorrei sapere se le mie tartarughe sono malate, hanno una sostanza "
        "appiccicosa sul carapace",
        "ho visto qualcosa di simile a un vetro al posto delle feci della "
        "tartaruga, è possibile? cosa devo fare?",
        "il mio coniglio ha delle palline sotto la pelle vicino ai testicoli, "
        "sapete cosa potrebbe essere?",
    ]
    for message in messages:
        assert ChatOrchestrator._classify_intent(message) == "clinical_question", message


def test_classify_intent_defaults_to_clinical_for_unrecognized_vocabulary() -> None:
    # Real-world finding: the previous default was "general_info" for
    # anything unmatched, which skipped evidence retrieval for genuine
    # (if vaguely or unusually worded) health questions — including a
    # bare medication-safety question with no symptom vocabulary at all.
    for message in ("il mio cane sta male", "posso dare un antidolorifico al gatto"):
        assert ChatOrchestrator._classify_intent(message) == "clinical_question", message


def test_classify_intent_still_recognizes_short_small_talk() -> None:
    # Only a genuinely short greeting/thanks/meta-question should still
    # get the free-form "general_info" treatment — not narrowed away by
    # the new clinical-by-default fallback.
    for message in ("ciao", "grazie mille", "ciao, come va oggi?", "cosa sai fare?"):
        assert ChatOrchestrator._classify_intent(message) == "general_info", message


def test_dosage_request_never_computes_a_number() -> None:
    # Real-world finding: asked for an exact drug dose, the general LLM
    # path computed and handed over a specific mg figure with only a
    # disclaimer at the end. This must be a fixed, rule-based refusal —
    # never an LLM call that could drift.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=(
                "Puoi dirmi esattamente quanti mg di amoxicillina posso dare "
                "al mio gatto che pesa 4 kg?"
            ),
            species="cat",
            pet_name="Luna",
        )
    )

    assert result.ai_generated is False
    assert result.provider == "rule-based"
    assert "veterinario" in result.answer.lower()
    assert not client.requests


def test_independent_multi_pet_complaint_is_redirected() -> None:
    # Real-world finding: "Ho un cane e anche un gatto, entrambi non
    # mangiano" was answered as an ordinary single-pet case — the second
    # animal's independent complaint was silently dropped.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=(
                "Ho un cane e anche un gatto, entrambi non mangiano da "
                "stamattina, cosa può essere?"
            ),
            species="dog",
            pet_name="Rex",
        )
    )

    assert result.mode == "multi_pet_redirect"
    assert result.ai_generated is False
    assert not client.requests


def test_multi_pet_interaction_is_not_redirected() -> None:
    # A second animal mentioned as CONTEXT for a real interaction (not an
    # independent, unrelated complaint) must stay in the same
    # conversation — the case is still about the registered pet.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio criceto è andato in blocco dopo aver visto il cane di casa",
            species="dog",
            pet_name="Rex",
        )
    )

    assert result.mode != "multi_pet_redirect"
