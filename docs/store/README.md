# Schede store (Google Play, App Store)

Testi pronti da incollare nelle console, per ogni lingua del prodotto. **Bozze**: da far rivedere a un madrelingua e, per le parti
legali, a un legale prima della pubblicazione (stesso trattamento delle ARB).

| File | Contenuto |
|---|---|
| `listings/<codice>.md` | Una scheda per `it`, `en-GB`, `en-US`, `en-AU`, `de`, `fr`, `es`: titolo, descrizione breve e completa, novità (Google Play); nome, sottotitolo, testo promozionale, descrizione, parole chiave, novità (App Store) |
| `02_screenshot_checklist.md` | Schermate da fotografare per lingua, didascalie tradotte, dati di prova per paese, dimensioni |
| `03_dichiarazioni_store.md` | Classificazione per età, scheda privacy / Data safety, dichiarazioni sull'IA, per paese; **blocchi alla pubblicazione** |

I limiti di lunghezza (titolo 30, breve 80, completa 4000, novità Play 500, sottotitolo 30, promo 170, parole chiave 100) sono
controllati da `tests/unit/test_store_listings.py`: va in rosso se un testo li supera, se manca una lingua, se compare un prezzo
o una funzione non ancora pubblica (Mercatino).

## Regole usate nei testi

- Specie nominate come da decisione del proprietario (`docs/marketing/01_brainstorm.md`): cani, gatti, piccoli mammiferi, uccelli,
  rettili e anfibi, pesci.
- **Niente prezzi, niente importi, niente "gratis"**: i prezzi reali sono segnaposto e la fatturazione è ancora dimostrativa (vedi
  blocchi). Quando i piani saranno veri andrà aggiunta una riga con la prova gratuita, con i termini richiesti dallo store.
- **Niente Mercatino, notizie, eventi**: sono in lavorazione in un'altra sessione e il Mercatino ha vincoli per paese (es. la vendita di
  animali tra privati in Francia: `docs/compliance/fr/01_ricerca_normativa.md`, sul ramo `ml/legale-fr`).
- Dichiarazioni obbligatorie sempre presenti: l'assistente è IA e le risposte sono etichettate; non sostituisce il veterinario, non fa
  diagnosi; in caso di urgenza il veterinario o il pronto soccorso veterinario.
- Registro: it "tu", en neutro, de "Sie", fr "vous", es "tú" (come l'app). en-US usa "veterinarian/medication", en-GB e en-AU "vet/medicine".
- Una scheda per lingua, non per paese: `de` vale per DE/AT/CH, `fr` per FR/BE/CH romanda. Le console non separano le varianti
  (Play ha `de-DE` e `fr-FR`; l'App Store ha `de-DE` e `fr-FR`); le differenze di paese stanno nella disponibilità per territorio, nelle
  dichiarazioni (`03_…`) e nelle schermate.

## Da verificare prima di incollare

- "Alle tue domande si applicano filtri per la privacy prima dell'invio al servizio di IA" è vero per l'anonimizzatore a regole
  (`docs/compliance/02_pii_anonymization.md`), ma le regole sono scritte per l'italiano (`docs/i18n/BACKEND_ITALIAN_CLASSIFIERS.md`):
  finché non sono estese a en/de/fr/es, per queste lingue la frase è più forte di quanto il codice garantisca. Se non si estendono le
  regole, ammorbidirla ("Ci impegniamo a proteggere…") nelle schede non italiane.
- "Trova … aree cani … (dove i dati sono disponibili)": i dati comunali sono italiani, fuori dall'Italia la mappa usa OpenStreetMap.
- Numeri e nomi dei fornitori non compaiono nelle schede; compaiono nelle dichiarazioni (`03_…`).
- Titoli: "VetApp" è un nome provvisorio? Verificare che sia disponibile come nome su entrambi gli store e in ogni paese (conflitti di
  marchio) prima di impostarlo.
