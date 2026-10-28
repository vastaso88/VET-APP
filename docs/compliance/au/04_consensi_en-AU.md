> **BOZZA — non è consulenza legale; da rivedere da un solicitor australiano prima della pubblicazione**

# Testi dei consensi en-AU per il catalogo backend

Questi testi corrispondono, uno per uno, a `CONSENT_TEXT_IT` in `packages/core/domain/consent/account_consent_text.py` e al testo della cartella clinica in `packages/core/domain/medical_record/consent_text.py`. Sono scritti in inglese australiano semplice. **Nessun codice è stato toccato**: sono solo i testi proposti.

## Come registrarli (proposta per la sessione coordinatrice)

- **Versione propria v1** per `en-AU` (decisione 13/10/2026). Non riusare `v1`/`v2` dell'italiano: il testo è diverso, e `ConsentRecord.version` deve voler dire «il testo che l'utente ha visto».
- **Registrare la lingua/regione mostrata** insieme alla versione, per esempio `language="en"`, `region="AU"` (o la stringa `en-AU`) nel `ConsentRecord`. Oggi il record ha solo `granted`, `version`, `decided_at`; serve un campo nuovo (revisione MULTILANG, problema 7). Alternativa che non richiede un campo: versione composta `en-AU.v1`. Scelta della sessione coordinatrice.
- `CONSENT_TEXTS_BY_LANGUAGE` oggi ha chiave solo per lingua («en»). Per le regioni serve una chiave per regione (`en-AU`) o una struttura lingua → regione. Anche `served_consent_language` riduce `en-AU` a `en`: la regione andrebbe preservata.
- **Pre-condizione di pubblicazione:** ogni testo resta bozza fino alla revisione di un solicitor australiano.

## Consensi account

### `terms_of_service` — en-AU v1 (obbligatorio)

> By using Quokka you accept our Terms of Service. They explain the rules for using the app, what we expect from you, and the limits of our responsibility. This includes that the assistant's suggestions are general information and do not replace advice from a registered veterinarian. Nothing in the terms takes away your rights under the Australian Consumer Law. Without this acceptance you cannot create an account.

### `privacy_policy` — en-AU v1 (obbligatorio)

> In short: to let you use Quokka we handle your account details (name and email), your pets' profiles, the documents and photos you add, your chats with the assistant and, if you turn them on, your location and walk routes. What you send to the assistant (questions, attachments, voice messages) goes to an external artificial intelligence provider, which may be outside Australia, so it can write the replies. A pet's health record is only shared if you allow it. Your information is stored with third-party hosting and database providers. You can ask to see or correct your information, ask us to delete it, and withdraw your optional consents in Settings at any time, by writing to Settings → Contact us. You can also complain to the Office of the Australian Information Commissioner. The full privacy policy is available in the app.

*(Nota: nel testo italiano v2 dice «L'informativa completa è in preparazione». Qui il testo presuppone che il file 02 sia pubblicato nell'app. Se non lo è al lancio, sostituire l'ultima frase con «The full policy is being finalised.» e non prometterla.)*

### `marketing_email` — en-AU v1 (facoltativo)

> With your consent, we can email you news about Quokka and tips for your pets. Every email has an unsubscribe link that works without signing in. You can withdraw your consent at any time in Settings, and it will not affect how you use the app.

### `analytics` — en-AU v1 (facoltativo)

> With your consent, we collect anonymous statistics about how the app is used (for example, which screens you visit and which features you use) so we can improve it. You can withdraw your consent at any time in Settings, and it will not affect how you use the app.

*(Nota: il registro italiano dice che oggi non risulta alcuno strumento di analisi attivo. Pubblicare solo se è vero.)*

### `contribution_rules` — en-AU v1 (facoltativo)

> Rules for place reports and votes
> 1. Only report what you have checked yourself or know for certain.
> 2. For businesses, write only the trading name, as shown on the sign. Do not add phone numbers, private addresses, emails or details about other people.
> 3. Reports stay "awaiting confirmation" until other users confirm them. They are not a guarantee: always check before you go.
> 4. Votes on dog parks are personal opinions: one vote per park.
> 5. Report a missing dog park only if it is a public place open to everyone. Do not report private property and do not invite others onto private land.
> 6. Do not use reports to harm a business. False or repeated reports can lead to your account being suspended.
> 7. Businesses can ask for a correction or removal. We check and reply as soon as we can.
> 8. Your reports and votes are published without your name or personal details, which are handled as set out in the privacy policy.

*(Nota: le regole 5 e 7 per l'Australia: i "luoghi pubblici" non sono definiti uniformemente; il solicitor può voler aggiungere un rimando alle regole dei consigli locali, es. «off-leash areas». Ho lasciato invariato il senso del testo italiano.)*

## Consenso per pet — cartella clinica (`medical_record_consent`) — en-AU v1

### Testo di consenso (corrisponde a `CONSENT_TEXT_IT`)

> To give you more accurate advice, the assistant can read your pet's health record. When you ask a question, it can read the three most recent entries, including the title, date, description and the text of attached documents, even if they are not related to your question. If you ask it to explain a test, it can read the documents about it, up to two. For a very long document it reads only the beginning. What it reads is sent to the external artificial intelligence provider that writes the reply, which may be outside Australia. Quokka uses it only to answer you. You can withdraw your consent at any time from your pet's page or from Settings. This applies to later requests.

### Domanda in chat (corrisponde a `INLINE_QUESTION_IT`; `{pet_name}` come nel codice)

> Would you like me to look at {pet_name}'s health record so I can give you more accurate advice? I'll read the three most recent entries, including the text of attached documents, and send them to the artificial intelligence service that writes the reply. You can change your mind at any time from {pet_name}'s page.

*(Vincolo: `tests/unit/test_consent_texts_match_behaviour.py` lega i numeri nel testo ai limiti del `MedicalRecordContextRetriever` («tre voci», «due documenti»). Se i limiti cambiano per l'IT, cambiano anche qui. La frase «may be outside Australia» è nuova rispetto all'italiano: va confermata col file 02, sez. 6.)*

## Tabella riassuntiva

| id (catalogo) | Obbligatorio | Italiano oggi | en-AU proposto | Note |
|---|---|---|---|---|
| `terms_of_service` | sì | v1 | **v1 (en-AU)** | Cita ACL |
| `privacy_policy` | sì | v2 | **v1 (en-AU)** | Cita OAIC; estero |
| `marketing_email` | no | v1 | **v1 (en-AU)** | Spam Act: disiscrizione senza login |
| `analytics` | no | v1 | **v1 (en-AU)** | Solo se attivo |
| `contribution_rules` | no | v2 | **v1 (en-AU)** | Stesso senso dell'italiano |
| `medical_record_consent` (per pet) | no | v2 | **v1 (en-AU)** | Sotto la versione corrente conta come decisione (`effective_decision`) |
