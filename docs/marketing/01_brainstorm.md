# Brainstorm marketing

Idee raccolte progressivamente. Non ancora prioritizzate né validate: servono come materiale grezzo da cui, in futuro, estrarre iniziative concrete.

## Incentivi per le recensioni (2026-09-16)

Meccanismo proposto per incentivare recensioni positive e recuperare quelle negative:

- **Recensione positiva**: si regalano 2 settimane di abbonamento full.
- **Recensione non massima (ma non negativa)**: si chiede all'utente (via email o altro canale) cosa servirebbe per arrivare al voto massimo. Le risposte si raccolgono e vengono usate per guidare le migliorie future del prodotto.
- **Recensione negativa**: si apre automaticamente una conversazione per capire il problema riscontrato. Se il problema viene risolto, si regalano 2 settimane di abbonamento full; insieme al regalo si allega una richiesta gentile di aggiornare voto e recensione.

Punti aperti da definire in futuro: su quale piattaforma raccogliere le recensioni, come automatizzare il flusso di richiesta/risposta, come evitare abusi del meccanismo (es. utenti che sfruttano il regalo senza intenzione di aggiornare la recensione).

## News card (pet_news) — indicizzazione e monetizzazione (2026-09-16)

La feature `pet_news` (già presente nel repo: [apps/mobile_app/lib/features/pet_news/](../../apps/mobile_app/lib/features/pet_news/), solo data layer, nessuna UI ancora) mostrerà card con notizie da testate giornalistiche esterne. Domanda posta: dando visibilità a queste testate tramite le card, è possibile indicizzarle e farsi pagare per questo?

**Nota legale da verificare con un legale prima di procedere — non è un'area in cui affidarsi a un'interpretazione informale:**

- Il quadro normativo rilevante è quello del *diritto connesso degli editori* (EU Copyright Directive 2019/790, art. 15, recepito in Italia) e le sue varianti (Australia News Media Bargaining Code, Canada Online News Act, "legge Google" spagnola). Questi regimi vanno tipicamente nella direzione opposta a quella ipotizzata: è l'aggregatore/piattaforma che **deve pagare** l'editore per riprodurre snippet/anteprime di contenuto giornalistico, non il contrario — salvo che si tratti di semplici link con titolo, tipicamente esenti.
- "Farsi pagare per indicizzare" non è il modello standard in questo ambito; il rischio concreto da valutare è l'opposto: se le card riproducono più di un semplice link (es. estratto di testo, immagine dell'articolo), VetApp potrebbe rientrare tra i soggetti tenuti a un compenso verso gli editori, a seconda di quanto contenuto viene riprodotto e come.
- Alternative più comuni per un aggregatore: accordi di affiliazione/referral con le testate, programmi ufficiali di syndication content, o limitarsi a link puri (titolo + URL, senza estratto) per restare nell'area tipicamente esente.

Questo punto va portato a un legale prima di costruire la UI di `pet_news`, non solo notato come idea di marketing — ha impatto diretto su come la feature deve essere implementata (quanto contenuto mostrare nella card).

## Specie supportate — nomenclatura da usare nel copy (2026-09-18)

Segnalato dalla sessione "UI/UX e funzionalità base": decisione del proprietario sulle categorie di specie, già implementata lato Flutter ([pet_demo_store.dart](../../apps/mobile_app/lib/features/pets/data/pet_demo_store.dart)). Da usare questi nomi esatti in qualunque copy futuro che elenchi le specie supportate (sito, store listing, onboarding, email):

- Cane
- Gatto
- **Piccoli mammiferi** (non più solo "Coniglio"): coniglio, criceto, cavia, cincillà, gerbillo, furetto
- Uccello
- **Rettili e anfibi** (non più solo "Rettile"): drago barbuto, gecko leopardino, testuggine, serpente del mais, rana, salamandra, axolotl
- Pesce

Nessun materiale marketing esistente in questo file menzionava ancora le specie (verificato), quindi nessuna correzione necessaria ora — solo da tenere a mente per copy futuro.

---

**Promemoria**: quando il materiale in questo file sarà sufficiente, l'utente chiederà un riassunto delle potenziali strategie di marketing da validare, sintetizzando le idee raccolte qui.
