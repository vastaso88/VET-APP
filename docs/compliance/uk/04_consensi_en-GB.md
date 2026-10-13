> **BOZZA — non è consulenza legale; da rivedere da un solicitor del Regno Unito prima della pubblicazione**
> DRAFT — not legal advice; to be reviewed by a UK solicitor before publication.

# Testi dei consensi per il catalogo backend — en-GB (v1)

Data: 2026-10-13. Base: `packages/core/domain/consent/account_consent_text.py` (testi IT: ToS v1, Privacy v2, Marketing v1, Analytics v1, Contribution rules v2) e `packages/core/domain/medical_record/consent_text.py` (v2). I testi qui sotto sono **equivalenti nel contenuto** a quelli italiani e restano coerenti con ciò che l'app fa oggi.

## Regole di registrazione (da implementare lato backend: non l'ho toccato)

Decisione dell'Orchestratore (2026-10-13): **versione propria v1 per lingua/regione** e **lingua mostrata salvata** con il consenso.

1. **Chiave di catalogo.** Oggi `CONSENT_TEXTS_BY_LANGUAGE` usa il codice lingua primario (`en`) e `CURRENT_VERSIONS` è condiviso da tutte le lingue. Con una sola traduzione inglese e tre bandiere (UK/US/AU) serve una chiave per **lingua + regione** (es. `en-GB`), altrimenti un utente UK vedrebbe il testo USA. Proposta: `CONSENT_TEXTS_BY_LOCALE["en-GB"]` e `CURRENT_VERSIONS_BY_LOCALE["en-GB"]`, con ripiego `en-GB → it` solo se il locale non esiste (mai ripiego silenzioso `en-GB → en-US`).
2. **Versione.** Tutti i consensi `en-GB` partono da **`v1`**. Una modifica sostanziale a un singolo testo porta solo quella voce a `v2` (come oggi). La versione `v1` di `en-GB` **non** equivale alla `v1` italiana: la sequenza è indipendente.
3. **Campo da salvare in `ConsentRecord`** (oggi ha `granted`, `version`, `decided_at`): aggiungere **`locale`** (es. `"en-GB"`, la lingua+regione dei testi *mostrati*, non quella del dispositivo), opzionale per compatibilità con i record IT esistenti. La coppia `(locale, version)` è la prova di quale testo vide l'utente. Meglio salvare anche un **hash del testo** mostrato.
4. **Cambio lingua o regione dopo il consenso.** Il consenso resta valido per il testo che l'utente vide; non va riscritto in silenzio. Se l'utente passa da en-GB a un'altra lingua, in Impostazioni appare lo stato «Accepted en-GB v1»; i consensi *obbligatori* (ToS, Privacy) si riconfermano solo se la sostanza cambia, secondo la regola già in vigore.
5. **Lingua mostrata e testi di pagina.** I testi di questo file sono la fonte della lingua `en-GB`; i testi in app devono coincidere (come per `_approvedConsentText` del consenso cartella clinica).
6. **Revisione.** I testi sono bozze; il campo `ConsentCatalogEntry` non ha un flag «bozza». Finché il solicitor non li approva, la lingua `en-GB` non va servita in produzione (o va servita dietro un flag).

Esempio di forma dati (solo illustrativo, non è codice del repo):

```python
CURRENT_VERSIONS_BY_LOCALE = {"en-GB": {"terms_of_service": "v1", "privacy_policy": "v1",
    "marketing_email": "v1", "analytics": "v1", "contribution_rules": "v1"}}
```

## Tabella degli id

| Id catalogo | Tipo | Equivalente IT | Versione en-GB |
|---|---|---|---|
| `terms_of_service` | obbligatorio | `TERMS_OF_SERVICE` (IT v1) | v1 |
| `privacy_policy` | obbligatorio | `PRIVACY_POLICY` (IT v2) | v1 |
| `marketing_email` | facoltativo | `MARKETING_EMAIL` (IT v1) | v1 |
| `analytics` | facoltativo | `ANALYTICS` (IT v1) | v1 |
| `contribution_rules` | facoltativo | `CONTRIBUTION_RULES` (IT v2) | v1 |
| *(consenso per animale)* `medical_record_consent` | facoltativo, per pet | `MedicalRecordConsentRecord` (IT v2) | v1 (propria) |

---

## 1. `terms_of_service` — en-GB v1

```
By using VetApp you accept the Terms of Service: the rules for using the app, your responsibilities as a user and the limits of our responsibility, including the fact that the assistant's suggestions do not replace the advice of a vet. Without this acceptance we cannot create an account.
```

## 2. `privacy_policy` — en-GB v1

Sintesi, non l'informativa completa. Va tenuta vera rispetto all'app (come l'IT v2).

```
In short: to let you use VetApp we process your account details (name and email), your pets' profiles, the documents and photos you upload, your conversations with the assistant and, if you switch them on, your location and your walk routes. What you send to the assistant (questions, attachments, voice messages) is sent to an external artificial intelligence provider so it can write the answers; your pet's health record only if you allow it. Your information is stored with third-party hosting and database services, some of which may be outside the UK. You can ask to see, correct or delete your information by writing to us from Settings → Contact us, and you can withdraw any optional consent at any time in Settings. You can also complain to the Information Commissioner's Office. The full privacy notice is being prepared.
```

Quando l'informativa completa (doc 02) sarà pubblicata, sostituire l'ultima frase con un link e passare a `v2`.

## 3. `marketing_email` — en-GB v1

```
With your consent, we may email you news about VetApp and tips for your pets. You can withdraw your consent at any time in Settings, and it makes no difference to how you use the app.
```

(PECR: ogni email deve anche contenere un modo semplice di annullare l'iscrizione.)

## 4. `analytics` — en-GB v1

```
With your consent, we collect anonymous statistics about how the app is used (for example, which screens are visited and which features are used) to understand how to improve it. You can withdraw your consent at any time in Settings, and it makes no difference to how you use the app.
```

Nota: oggi non c'è alcuno strumento di analisi attivo (bozza IT, nota 1). Se il testo resta nel catalogo, va tenuto vero: o si attiva davvero uno strumento, o si toglie la voce.

## 5. `contribution_rules` — en-GB v1

```
Rules for reports and votes
1. Only report what you have checked yourself or know for certain.
2. For businesses, write only the trading name as it appears on the sign. Do not enter phone numbers, private addresses, emails or other people's details.
3. Reports stay "waiting for confirmation" until other users confirm them. They are not a guarantee: always check before you travel to a place.
4. Votes on dog parks are personal opinions: one vote per park.
5. Report a missing dog park only if it is public and open to the public. Do not report private property and do not encourage others to enter private land.
6. Do not use reports to harm a business. False or repeated reports can lead to your account being suspended.
7. Businesses can ask for a correction or for information to be removed: we will check and reply as soon as we can.
8. Your reports and votes are published without your name or personal details, which are handled as set out in the privacy notice.
```

Adattamenti rispetto all'IT: «dog park» invece di «area cani»; «trading name» invece di «nome commerciale»; «private land» per proprietà private; «as it appears on the sign» identico all'insegna.

## 6. Consenso per animale: lettura della cartella clinica da parte della chat — en-GB v1

Non è un consenso di account (non è in `AccountConsentType`): vive in `packages/core/domain/medical_record/consent_text.py`. Valgono le stesse regole di locale e versione. Il testo deve restare coerente con ciò che il codice legge (tre voci recenti, due documenti per «spiegami l'esame», 1.200 e 3.500 caratteri); il test `tests/unit/test_consent_texts_match_behaviour.py` ne vincola le cifre per l'italiano: va esteso alla versione inglese.

```
To give you more precise advice, the assistant can read your pet's health record. When you ask a question it can read the three most recent entries, with title, date, description and the text of any attached documents, even if they are not related to your question. If you ask it to explain a test result, it can read the documents about that test, up to two. For a very long document it reads only the beginning. What it reads is sent to the external artificial intelligence provider that writes the answer. VetApp uses it only to answer you. You can withdraw your consent at any time from your pet's page or from Settings, and this applies to later requests.
```

Domanda in chat (da formattare con `pet_name`), equivalente di `INLINE_QUESTION_IT`:

```
Would you like me to look at {pet_name}'s health record to give you more precise advice? I will read the three most recent entries, including the text of any attached documents, and send them to the artificial intelligence service that writes the answer. You can change your mind at any time from {pet_name}'s page.
```

## Note per il solicitor

1. «Optional consents are separate and never a condition of using the app»: coerente con UK GDPR art. 7 e con PECR per l'email marketing.
2. Il consenso `privacy_policy` è un'accettazione/presa visione, non una base giuridica; la base è il contratto (doc 02, §3).
3. I testi non dichiarano anonimizzazione né pagamenti attivi.
4. «Some of which may be outside the UK» nella sintesi privacy: serve perché i fornitori (p. es. IA) possono essere USA.
5. Spelling britannico: «recognise», «organisation», «licence» (nome), «favourite».
