# Esportazione dei dati dell'utente: contratto della rotta `GET /account/export`

Ultimo aggiornamento: 2026-10-28. Attua il **diritto di accesso** (GDPR art.
15: sapere quali dati abbiamo) e il **diritto alla portabilità** (art. 20:
riceverli in un formato leggibile da una macchina, qui JSON). Il pulsante
«Scarica i miei dati» in Impostazioni → Account è a carico della sessione
UI/UX; questo documento descrive cosa riceve.

## Richiesta

| | |
| --- | --- |
| Metodo e percorso | `GET /account/export` |
| Autenticazione | `Authorization: Bearer <token Supabase>` (obbligatoria; il token identifica l'utente, non si può chiedere l'export di un altro id) |
| Parametri | nessuno |
| Limite | **1 richiesta ogni 10 minuti per utente** (chiave: hash del token; in assenza, indirizzo del client). Oltre: `429` con `Retry-After: 600` e `{"detail": "Troppe richieste: riprova tra poco."}`. Il contatore vive nella memoria dell'istanza serverless (best effort). |
| Tempo di risposta | pochi secondi; cresce con il numero di conversazioni e file. L'app mostri un'attesa e non ritenti in automatico. |

## Risposta `200` (JSON, `application/json`)

```json
{
  "format_version": "1",
  "generated_at": "2026-10-28T10:15:00+00:00",
  "owner_id": "<uuid utente>",
  "account": {
    "id": "<uuid>", "email": "…", "email_confirmed_at": "…", "created_at": "…",
    "last_sign_in_at": "…",
    "profile": { "display_name": "…", "surname": "…", "phone": "…", "preferred_locale": "it" }
  },
  "data": {
    "pet_profiles": [ { "...": "ogni colonna della tabella" } ],
    "clinical_events": [ ... ],
    "pet_conditions": [ ... ],
    "pet_weight_measurements": [ ... ],
    "pet_photos": [ ... ],
    "conversations": [ ... ],
    "chat_attachments": [ ... ],
    "chat_response_reports": [ ... ],
    "reminders": [ ... ],
    "dog_walks": [ ... ],
    "user_locations": [ ... ],
    "account_consents": [ ... ],
    "subscriptions": [ ... ],
    "marketplace_listings": [ ... ],
    "marketplace_listing_reports": [ ... ],
    "local_activities": [ ... ],
    "event_submissions": [ ... ],
    "chat_user_daily_usage": [ ... ],
    "radar_user_reports": [ ... ],
    "radar_report_votes": [ ... ],
    "radar_place_ratings": [ ... ]
  },
  "files": [
    {
      "bucket": "chat-attachments", "path": "<chiave>", "kind": "chat_attachment",
      "url": "https://…/storage/v1/object/sign/…", "url_expires_at": "2026-10-28T10:30:00+00:00",
      "note": null
    }
  ],
  "notes": [ "file links expire 15 minutes after generated_at" ]
}
```

Regole:
- **`data`** contiene una chiave per **ogni tabella che la cancellazione
  dell'account elimina** (stesso elenco di `supabase_account_eraser.py`, usato
  direttamente dal codice: un test fallisce se i due elenchi divergono). Le
  righe hanno i nomi di colonna reali del database, senza trasformazioni.
  Chiavi sempre presenti anche se vuote (`[]`).
- Le colonne interne `reporter_ref`, `reporter_pseudonym`, `voter_pseudonym`
  (pseudonimi dell'utente stesso) sono tolte: fuori dal servizio non hanno
  significato e aiuterebbero solo a correlare righe se il file venisse perso.
- **`files`**: un elemento per allegato della chat/cartella clinica, per foto e
  video dell'animale e per la foto profilo. `kind` ∈ `chat_attachment`,
  `pet_media`, `profile_photo`. `url` è un **link firmato valido 15 minuti**
  (chi ha il link scarica senza login: per questo scade); dopo, rifare
  l'export. Se il link non è stato generato, `url` è `null` e `note` spiega.
  Le foto degli annunci del Mercatino sono già negli URL pubblici dentro
  `data.marketplace_listings[].photo_urls`.
- **`account`**: dall'identity provider (e-mail, date, `profile` = metadati
  del profilo: nome, cognome, telefono facoltativo, lingua). Se il provider
  non risponde resta `{"id": …}` più i campi del token.
- **`notes`**: avvisi in inglese per il supporto (es. chiave radar non
  configurata). Non vanno mostrati all'utente così come sono.
- Nulla del contenuto viene scritto nei log del server.

## Errori

| Codice | Quando |
| --- | --- |
| `401` | token mancante, scaduto o non valido |
| `429` | più di un export in 10 minuti |
| `500` | errore interno: `{"detail": "Errore interno. Riprova tra poco.", "error_id": "…"}` (citare `error_id` al supporto) |

## Indicazioni per l'app (sessione UI/UX)

1. Pulsante «Scarica i miei dati» in Impostazioni → Account, con testo: cosa
   contiene (tutti i dati e link ai file validi 15 minuti) e che il file può
   contenere dati sensibili dell'animale e della famiglia: conservarlo con cura.
2. Salvare la risposta come `quokka-dati-<data>.json` tramite il selettore di
   file di sistema / condivisione; **non** lasciarlo nella cache dell'app.
3. Su `429` mostrare «Hai già richiesto un export da poco: riprova tra 10
   minuti», senza ritentare.
4. Facoltativo: scaricare anche i file dai link firmati e produrre uno zip;
   non obbligatorio per la conformità (i link nel JSON bastano).

## Verifiche

`tests/unit/test_export_account_data.py` (allineamento con la cancellazione,
isolamento tra utenti, link firmati, metadati), `tests/integration/test_security_api.py`
(rotta, contenuto, limite 429).
