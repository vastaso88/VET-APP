# Francese: testi fissi del backend (da collegare)

I testi in francese sono pronti in `packages/core/domain/localization_fr.py`, ma **nessun
codice di produzione li usa ancora**: `localization.py`, `SupportedLocale` e
`response_locale` in `apps/api/schemas/chat.py` accettano solo `it/en/es` e sono di
competenza di chi mantiene MULTILANG (il 422 su `response_locale` va corretto lì).
Il test `tests/unit/test_localization_fr.py` verifica chiavi, segnaposto e marcatori.

## Cosa serve per attivarli (una riga per punto)

| Dove | Cosa aggiungere |
|---|---|
| `localization.py` | `"fr"` in `SupportedLocale` e in `SUPPORTED_LOCALES`; `"fr": "French"` in `LANGUAGE_NAMES`; per ogni chiave di `_MESSAGES` la voce `"fr": MESSAGES_FR[chiave]` |
| `apps/api/schemas/chat.py` | `"fr"` nel `Literal` di `response_locale` |
| `response_generator.py` | `"fr": CONNECTORS_FR` in `_CONNECTORS` |
| `interview_planner.py` | `"fr": QUESTION_TEMPLATES_FR` in `QUESTION_TEMPLATES_BY_LOCALE` |
| `chat_orchestrator.py` (righe ~661 e ~1358) | `"fr"` nelle tuple `("it", "en", "es")` |
| `evidence_synthesizer.py` | `"fr": "French"` in `LANGUAGE_NAMES` |
| `account_consent_text.py` | `CONSENT_TEXT_FR` in `CONSENT_TEXTS_BY_LANGUAGE` (testi legali: li fa la sessione legale, non tradotti qui) |
| `triage_clarification.py` | `"fr": CLARIFYING_QUESTIONS_FR` **e** i marcatori francesi in `REASSURING_MARKERS`: senza marcatori una risposta francese non è mai letta come rassicurante (default sicuro: si passa a emergenza), ma la funzione va resa multilingua per intero |
| `scripts/i18n/auto_translate.py` | `"fr"` in `LANGUAGES` **dopo** aver aggiunto le voci `fr` a `_MESSAGES` (altrimenti `check` segnala il backend come da tradurre); `DEEPL_TARGETS` ha già `"fr": "FR"`; variabile opzionale `DEEPL_GLOSSARY_FR`; poi `python scripts/i18n/auto_translate.py acknowledge` e aggiornare `tests/unit/test_auto_translate.py` (elenco lingue atteso) |

`common/language.py` ha già `fr` (i codici arrivano fino al prompt LLM): l'istruzione
"rispondi in francese" funziona già, ciò che manca è il catalogo dei testi fissi.

## Classificatori italiani
Come per EN/ES restano validi i limiti di `BACKEND_ITALIAN_CLASSIFIERS.md`: red flag,
ponte IT→EN in `relevance.py` e simili non sono stati toccati.

## Marcatori
`weight_marker` e `record_marker` devono restare sottostringhe esatte di
`weight_suggestion` e `record_notice` (il codice le cerca nel testo): il test lo verifica.
