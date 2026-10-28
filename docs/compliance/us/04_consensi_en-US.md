> **BOZZA — non è consulenza legale; da rivedere da un avvocato abilitato negli USA prima della pubblicazione**

# Consensi — testi per il catalogo backend (en-US)

Fonte del formato: `packages/core/domain/consent/account_consent_text.py` (`CONSENT_TEXT_IT`, `CURRENT_VERSIONS`, `CONSENT_TEXTS_BY_LANGUAGE`, `build_consent_catalog`), `packages/core/domain/consent/models.py` (`AccountConsentType`) e `packages/core/domain/medical_record/consent_text.py` (consenso per-animale). Non ho toccato il codice: questo file contiene solo testi e raccomandazioni per chi lo implementerà.

## 1. Versione propria e lingua/regione mostrata (decisione 2026-10-13, problema 7 di REVISIONE_MULTILANG)

- **Versione propria v1** per la regione USA: i testi sotto partono da `v1` e **non** condividono la versione dell'italiano (`CURRENT_VERSIONS` oggi è unico per tutte le lingue: un cambiamento di una traduzione costringerebbe a cambiare la versione per tutti — il commento nel codice lo dice).
- **Va registrata la lingua/regione mostrata** all'utente al momento della decisione (es. `"en-US"`), accanto a `version` e `decided_at`. Motivo legale USA: le prove di consenso devono dimostrare *quale testo* è stato visto (ROSCA/ARL per i rinnovi, regolatori statali, Apple 5.1.1(ii) per il consenso ai dati d'uso). Una versione `v1` che significhi testi diversi in lingue diverse non lo dimostra.
- **Nota tecnica per l'implementatore** (non applicata qui): `served_consent_language()` oggi riduce il codice a lingua (`"en-US"` → `"en"`); per avere un testo USA distinto da UK/AU serve una chiave per **locale** (es. `"en-US"`, `"en-GB"`, `"en-AU"`) con fallback alla lingua, e una mappa di versioni per locale. `ConsentRecord` dovrebbe ricevere un campo `locale` (o la versione dovrebbe includere il locale, es. `en-US/v1`). Il test `tests/unit/test_consent_texts_match_behaviour.py` va esteso per i numeri nel testo della cartella clinica.
- Il testo sotto è **inglese americano**; UK e AU avranno propri testi (altre sessioni legali).

## 2. Mappa degli id

| id (identico all'italiano) | Obbligatorio? | Versione | Note USA |
|---|---|---|---|
| `terms_of_service` | sì (contratto) | `v1` (en-US) | Accettazione dei Termini 03; è un contratto, non un "consenso" privacy. |
| `privacy_policy` | sì (presa visione) | `v1` (en-US) | Negli USA la policy è una **informativa** (CalOPPA, Apple 5.1.1(i)), non una base giuridica di consenso: il testo è una presa visione. Menziona l'IA di terzi (Apple 5.1.2(i)). |
| `marketing_email` | no (opt-in, off di default) | `v1` | CAN-SPAM richiede solo l'opt-out, ma si mantiene l'opt-in come in Italia. Richiede indirizzo postale e "unsubscribe" nelle email. |
| `analytics` | no (opt-in, off di default) | `v1` | Apple 5.1.1(ii) richiede consenso anche per dati d'uso anonimi. **Oggi nessuno strumento attivo**: se resta così, tenere la voce nascosta o con nota. |
| `contribution_rules` | no (prima del primo contributo) | `v1` | Regole 07 adattate (proprietà privata/"trespass"; nessun dato personale). |
| `medical_record_consent` (per animale, servizio separato: `SetMedicalRecordConsentService`) | no, revocabile | `v1` (en-US) | Stesso significato del v2 italiano (3 voci recenti, max 2 documenti, solo l'inizio, fornitore IA esterno). Non dichiarare anonimizzazione. |
| *(proposta nuova)* `ai_provider_sharing` | no — prerequisito all'uso della chat | `v1` | **Non esiste nel catalogo italiano.** Apple 5.1.2(i) richiede permesso **esplicito** prima di inviare dati personali a un'IA di terzi. Se il team non vuole un nuovo id, il permesso può essere una schermata al primo uso della chat con registrazione separata, o essere integrato nel testo di `privacy_policy` (rischio: Apple può non considerarlo sufficiente). Decisione aperta (08, domanda 3). |

## 3. Testi (da incollare in una `CONSENT_TEXT_EN_US` per locale)

Stile: uguale a quello italiano (un blocco di testo, tono diretto). Punteggiatura e frasi sono definitive per la bozza; ogni modifica sostanziale richiede una nuova versione.

### `terms_of_service`

```
By using Quokka, you agree to the Terms of Service: the rules for using the app, your responsibilities as a user, and the limits of our responsibility, including that the assistant's suggestions are not veterinary advice and do not replace a veterinarian. You must be 18 or older. Without this agreement we can't create an account. The Terms include an arbitration agreement and class-action waiver, which you can opt out of within 30 days.
```

*(La frase su arbitrato dipende dalla decisione del proprietario: se si elimina la clausola 14 dei Termini, togliere l'ultima frase. Vedi 03 e 08.)*

### `privacy_policy`

```
In short: to let you use Quokka, we collect your account details (name and email), your pets' profiles, the documents and photos you upload, your chats with the assistant, and, if you turn them on, your location and walk routes. What you send to the assistant (questions, attachments, voice messages) is sent to an outside AI provider so it can write answers; your pet's health record is sent only if you allow it. Your data is stored with third-party hosting and database services. We don't sell your personal information or use it for targeted ads. You can ask to see, correct, or delete your data by writing to Settings → Contact us, and you can withdraw optional consents any time in Settings. The full Privacy Policy is available in Settings and at sign-up.
```

*(Ultima frase: finché la policy completa non è pubblicata, usare la formula "The full Privacy Policy is being prepared", come nella v2 italiana. Verificare "We don't sell… targeted ads" prima di pubblicare.)*

### `marketing_email`

```
With your permission, we may email you news about Quokka and tips for your pets. You can withdraw your permission any time in Settings, and every email has an unsubscribe link. Saying no has no effect on how you use the app.
```

### `analytics`

```
With your permission, we collect anonymous statistics about how the app is used (for example, which screens you visit and which features you use) to understand how to improve it. You can withdraw your permission any time in Settings. Saying no has no effect on how you use the app.
```

### `contribution_rules`

Basato sul testo italiano (docs/compliance/07_contributi_utenti.md), con adattamenti USA: *private property / trespass*, nessuna "legge su agenzie" citata.

```
Rules for reports and votes
1. Report only what you have checked yourself or know for certain.
2. For businesses, write only the business name as it appears on the sign. Don't enter phone numbers, home addresses, emails, or personal details about other people.
3. Reports stay "pending confirmation" until other users confirm them. They are not a guarantee: always check before you go.
4. Dog-park ratings are personal opinions: one rating per park.
5. Report a missing dog park only if it is public and open to the public. Don't report private property, and don't encourage others to enter private property.
6. Don't use reports to hurt a business. False or repeated reports may lead to suspension of your account.
7. Businesses may ask for a correction or removal: we'll review and reply as soon as we can.
8. Your reports and votes are shown without your name or personal details, which are handled under our Privacy Policy.
```

### `medical_record_consent` (per animale)

Testo di consenso (corrisponde a `CONSENT_TEXT_IT` v2):

```
To give you more precise advice, the assistant can read your pet's health record. When you ask a question, it may read the three most recent entries, including title, date, description, and the text of attached documents, even if they aren't related to your question. If you ask it to explain a test result, it may read the documents about it, up to two. For a very long document, it reads only the beginning. What it reads is sent to the outside AI provider that writes the answer. Quokka uses it only to answer you. You can withdraw your consent any time from your pet's page or in Settings; it applies to later requests.
```

Domanda in chat al primo uso (corrisponde a `INLINE_QUESTION_IT`, da formattare con `{pet_name}`):

```
Would you like me to look at {pet_name}'s health record to give you more precise advice? I'll read the three most recent entries, including the text of attached documents, and send them to the AI service that writes the answer. You can change your mind any time from {pet_name}'s page.
```

Note: nei numeri (tre voci, due documenti) il testo deve coincidere con i limiti del codice (`MAX_EXPLAINED_DOCUMENTS`, ecc.). Non va scritto che la cartella viene anonimizzata (documento 03, punto 3 aperto).

### *(proposta)* `ai_provider_sharing`

```
Quokka's assistant is powered by artificial intelligence (AI) provided by an outside company. To answer you, we send it what you type or upload in the chat (questions, photos, documents, voice messages). Some personal details may be removed first, but not all. Answers are generated by AI, can be wrong, and are not veterinary advice. Do you agree to send your chat messages to this AI provider? You can say no and still use the rest of the app, and you can change your choice any time in Settings.
```

*(Bottoni suggeriti: "Agree and continue" / "Not now". Se rifiutato, la chat resta disattivata: limitare la funzione, non bloccare l'app — coerente con docs/compliance/04.)*

## 4. Regole di registrazione (da riportare a chi implementa)

1. Registrare per ogni decisione: `granted`, `version`, `decided_at`, **`locale` mostrato**, e idealmente un hash del testo.
2. Un cambiamento di significato in un testo en-US bumpa **solo** la versione en-US.
3. Se si cambia lingua dell'app, non reinterpretare le decisioni passate: mostrare lo stato "accepted v1 (en-US)". Se l'utente cambia regione (es. si trasferisce) servono i testi della nuova regione solo per i nuovi consensi; per quelli già dati, valutare un re-consenso (domanda aperta).
4. Il consenso a `terms_of_service` e `privacy_policy` è parte della registrazione; marketing/analytics solo in Impostazioni, **disattivati** di default.
