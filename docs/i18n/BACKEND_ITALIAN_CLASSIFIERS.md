# Classificatori e liste italiane nel backend

Non toccati dalla predisposizione multilingua (2026-10-12): lavorano su parole italiane e vanno resi multilingua dal ramo `multilingua`. Numeri di riga indicativi.

## Contratto lingua già pronto
`language` (it/en/de/fr/es) in `POST /chat` e `PUT /conversations/{id}/messages/{mid}`, header `Accept-Language`, `GET /legal/consents?lang=xx` (ripiego a it). Vedi `packages/core/domain/common/language.py`.

Da fare: risposte "canned" italiane (fallback ProviderError, domande di sicurezza, consenso cartella clinica, domande di colloquio, titolo "Nuova conversazione"), `GET /account/consents` senza lang, `evidence_synthesizer.py` (`response_language` fisso dal container).

## Classificatori / liste italiane NON toccati (per il ramo multilingua)
packages/core/application/services/
- chat_orchestrator.py:106 EVIDENCE_KEYWORDS (intent, usati da _classify_intent ~:1889); :232 SMALL_TALK_MESSAGES; :262 DOSAGE_REQUEST_MARKERS (_is_dosage_request ~:864); :285 SPECIES_WORD_TO_FAMILY; :306/:314 MULTI_PET_*_MARKERS; :83 MEDICAL_RECORD_NOTICE_MARKER
- evidence_query_planner.py:23 IT_EN_TERMS (ponte IT→EN: "tosse"→cough, "ansia"→anxiety…); :132 INTENT_FALLBACK_TERMS; :149 FUZZY_ELIGIBLE_TERMS
- safety_gate.py:7 URGENT_RED_FLAG_KEYWORDS; :74 SPECIES_SPECIFIC_RED_FLAGS
- consent_interpreter.py:1-21 _SHORT_YES/_SHORT_NO/AFFIRMATIVE_PHRASES/NEGATIVE_PHRASES
- medical_record_context_retriever.py:23 _DOCUMENT_TOPICS, :59 _MONTHS, :75 italian_date
- vet_summary.py:40 _READ_LINE, :41 _DOCUMENT_LABEL
- interview_planner.py ~:64 QUESTION_TEMPLATES, ~:146 prompt "in Italian"
- natural_answer_prompt.py _VOICE/_REPORT/_DIRECT (~10-38): istruzioni "the reply is always Italian" (con language≠it prevale la riga finale, ma il testo va rivisto)
packages/core/domain/
- knowledge/relevance.py:29 _STOPWORDS, :45 _SPECIES_WORDS, :56 _BRIDGE (ponte IT→EN: "mastica", "ansia", "tosse", "sangue", "convuls", "avvelen"…)
- knowledge/answer_validation.py:10 ABSOLUTE_CLAIM_MARKERS
- safety/triage_clarification.py:14 RED_FLAG_CATEGORIES, :101 IMMEDIATE_ESCALATION_MARKERS, :118 CLARIFYING_QUESTIONS, :165 REASSURING_MARKERS, :210 WORSENING_MARKERS
- conversation/request_kind.py:42 _DOCUMENT_WORDS, :66 ANALYTES, :91 _EXPLAIN_MARKERS, :121 _INTERROGATIVE_OPENINGS, :157 _SYMPTOM_MARKERS, :206 _STOP_QUESTION_MARKERS, :237 _NAMED_EXAM, :278 _DOCUMENT_TEXT
- conversation/referral_style.py:23 _REFERRAL, :30 _RITUAL, :41 _CONCRETE
- conversation/title.py:21 _FILLER_OPENERS, :17 DEFAULT_TITLE
- pet_profile/weight.py:12 WEIGHT_RELEVANT_MARKERS, :53 WEIGHT_SUGGESTION_MARKER
- pet_profile/species.py:23 _LABEL_TO_CANONICAL
packages/infrastructure/
- privacy/rule_based_pii_anonymizer.py:23-100 (indirizzi/CAP/IBAN/CF/P.IVA italiani), :114 _NAME_STOPWORDS
- llm/retrieval/in_memory_evidence_retriever.py:79 QUERY_HINTS (solo test/demo)
