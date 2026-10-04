# Allegati: foto e PDF (contratto API)

Contratto tra backend (sessione "Chat LLM") e app (sessione "UI/UX e
funzionalità base"), concordato il 2026-10-04. Vale per le foto allegate
in chat e per i referti caricati dalla cartella clinica.

## Upload

`POST /chat-attachments` — multipart con `pet_id` (campo) e `file`.

| Cosa | Regola |
|---|---|
| Formati accettati | JPEG, PNG, WEBP, PDF |
| Come si decide il formato | Dai primi byte del file. Il content-type dichiarato e l'estensione sono ignorati |
| Dimensione massima | 4 MB per file |
| PDF | Massimo 30 pagine; i PDF protetti da password sono rifiutati |

L'app dichiara comunque il content-type reale nel multipart (seconda
protezione), ma un valore mancante o sbagliato non fa fallire l'upload.

Il limite di 4 MB viene dalla piattaforma: Vercel rifiuta con `413` ogni
richiesta sopra i 4,5 MB prima che arrivi al backend. L'app controlla la
dimensione prima dell'upload e tratta il `413` come "file troppo grande".

### Risposta `200`

```json
{
  "attachment": {
    "id": "…",
    "pet_id": "…",
    "content_type": "application/pdf",
    "original_filename": "esami.pdf",
    "analysis": "Referto esami… Creatinina: 2,4 mg/dL (rif. 0,5 - 1,5)…",
    "analysis_failed": false,
    "created_at": "2026-10-04T10:00:00Z"
  }
}
```

- `content_type` è il tipo reale rilevato: `image/jpeg`, `image/png`,
  `image/webp` o `application/pdf`.
- `analysis` è la trascrizione del documento (tipo, data, valori con unità
  e intervalli di riferimento, terapie, conclusioni) oppure, per una foto
  dell'animale, la descrizione di ciò che si vede.
- `analysis_failed: true` con `analysis: null` significa che il file è
  salvato e scaricabile ma la lettura automatica non è riuscita. L'app lo
  mostra come "Salvato, lettura automatica non riuscita", non come errore.

### Errori `400`

Il campo `detail` inizia con un codice stabile, seguito da `: ` e da un
testo in italiano.

| Codice | Quando |
|---|---|
| `attachment_too_large` | File oltre 4 MB |
| `unsupported_attachment_type` | Il contenuto non è un'immagine supportata né un PDF, qualunque sia l'estensione |
| `pdf_too_many_pages` | PDF con più di 30 pagine |
| `pdf_unreadable` | PDF danneggiato o protetto da password |

Un file rifiutato non viene salvato.

## Download

`GET /chat-attachments/{id}/file` restituisce i byte originali con il
`Content-Type` reale e `Content-Disposition: inline` con il nome file
originale. `404` se l'allegato non esiste o appartiene a un altro utente.

## Come viene letto un PDF

1. **PDF con testo**: il testo delle prime 10 pagine viene estratto con
   `pypdf`, anonimizzato e riassunto dal modello di testo.
2. **PDF scansionato** (nessun testo): dalle prime 3 pagine si prende
   l'immagine JPEG incorporata, che viene letta dal modello di visione
   come una foto di documento.
3. **Nessuna delle due**: il file resta salvato, con `analysis_failed: true`.
   Succede con scansioni salvate in un formato immagine diverso da JPEG:
   il backend non rasterizza le pagine, perché servirebbero librerie
   native non disponibili su Vercel.

La trascrizione passa dal PII anonymizer prima di essere salvata.
L'upload di un PDF richiede una chiamata al modello: in genere pochi
secondi, l'app usa un timeout di 30.

## Uso in chat e consenso

Un referto è un `clinical_events` con `attachment_id`. La chat legge
`analysis` solo se il consenso alla cartella clinica dell'animale è attivo
(`PUT /pets/{pet_id}/medical-record-consent`); senza consenso non ne vede
né il contenuto né il titolo, e lo dice con una nota nella risposta.

## Evoluzione: file oltre 4 MB

Per file più grandi l'upload non può passare dal backend. La strada è
l'upload diretto dall'app allo Storage di Supabase con un URL firmato
rilasciato dal backend, seguito da una chiamata che chiede al backend di
analizzare il file già caricato. Non è implementato.
