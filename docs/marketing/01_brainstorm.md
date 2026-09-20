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

## Professionisti come promoter e clienti (2026-09-19)

Principio di posizionamento: l'app **supporta** il lavoro di veterinari, educatori/addestratori e altri professionisti, non si sostituisce a loro. Domanda posta: come trasformare i professionisti in promoter (che pubblicizzano l'app) e non solo in clienti? Vale la pena sviluppare funzionalità dedicate a stimolare queste categorie a farlo?

**Il posizionamento non è solo copy: è già nell'architettura del prodotto.** Il safety gate rimanda sempre al veterinario per i casi seri, ogni risposta mostra fonti/limiti ed è etichettata come generata da IA ([01_ai_disclosure.md](../compliance/01_ai_disclosure.md)), e l'accesso alla cartella clinica richiede consenso esplicito ([03_consenso_cartella_clinica.md](../compliance/03_consenso_cartella_clinica.md)). Questo è rilevante per il go-to-market: la paura tipica di un professionista verso un'"app IA veterinaria" è che scavalchi la visita o dia consigli rischiosi ai suoi clienti. VetApp può onestamente dire che non lo fa — è un argomento di vendita concreto verso i professionisti, non solo una tutela legale.

**Perché un professionista dovrebbe pubblicizzare l'app (non solo tollerarla):**
- Se l'app gli fa perdere clienti/valore percepito → la ignora o la scoraggia.
- Se l'app gli fa risparmiare tempo, gli porta clienti, o gli dà visibilità → diventa un canale di acquisizione gratuito per VetApp (i professionisti hanno già la fiducia dei loro clienti, un referral da un veterinario vale più di qualunque pubblicità).

**Leve concrete da valutare (non prioritizzate, da discutere):**
1. **Referral/co-marketing**: link o codice univoco per clinica/professionista; chi si iscrive tramite quel codice regala visibilità/credito al professionista (e magari uno sconto al cliente). Ricalca i classici loop B2B2C (es. Calendly "powered by").
2. **Portale professionista / riepilogo pre-visita**: con il consenso del proprietario, il veterinario vede un riepilogo di cosa il cliente ha chiesto all'assistente prima dell'appuntamento — il professionista arriva preparato. È la leva più forte perché aiuta concretamente il suo lavoro invece di limitarsi a non danneggiarlo, ed è coerente al 100% con "supporto, non sostituzione".
3. **Widget co-brandizzato**: il professionista incorpora un widget "Chiedi al nostro assistente" sul proprio sito/social con il proprio brand; VetApp acquisisce il cliente, il professionista appare tecnologicamente avanzato.
4. **Account professionale gratuito/scontato** in cambio di un numero di clienti referenziati — classico scambio freemium-per-advocacy.
5. **Comitato consultivo di veterinari** che rivede i contenuti di sicurezza/evidenza: dà loro credibilità professionale (visibilità in conferenze, associazioni) e a VetApp un motivo di fiducia in più — un canale di passaparola naturale nella loro rete professionale.
6. **Contenuti di formazione continua (ECM/CE)**: la pipeline di evidenze/citazioni già costruita per la chat potrebbe alimentare contenuti formativi sponsorizzati, in cambio di visibilità e di una lista di contatti professionali.

Punti aperti: quale professione aggredire per prima (veterinari vs. educatori cinofili hanno dinamiche commerciali diverse), se il portale pre-visita richiede troppo lavoro di integrazione per un primo test, e come misurare se un professionista sta davvero portando clienti (serve un meccanismo di attribuzione, collegato al punto referral).

## Regalo per segnalazione di bug nella chat (2026-09-20)

Proposta (arrivata tramite la sessione "Chat LLM interna VETAPP", che gestisce l'orchestratore chat): se un cliente segnala rapidamente dalla chat una risposta mancante/limitata/errata, e la segnalazione porta a un miglioramento reale della chat, gli si regala una settimana di abbonamento gratis per ogni bug risolto. È la stessa famiglia di meccanismo di "Incentivi per le recensioni" sopra, ma innescato dalla qualità del prodotto invece che dallo store rating — e con un vantaggio in più: chi lo risolve produce già un commit + un test di regressione, quindi esiste una prova verificabile che il bug è stato davvero corretto (non un'autocertificazione).

**Decisioni prese (con l'utente):**
- **Accredito**: revisione umana al momento del fix, non automatico. Chi risolve un bug segnalato marca esplicitamente quali segnalazioni corrispondono a quel fix — solo quelle vengono premiate.
- **Unità del premio**: per bug risolto, non per segnalazione — se più persone segnalano lo stesso problema, tutte quelle collegate al fix ricevono la settimana, ma un utente non accumula premi ripetendo la stessa segnalazione.
- **Tetto**: mensile per utente (valore esatto da fissare, indicativamente 4 settimane/mese) per evitare che diventi un modo sistematico per azzerare il costo dell'abbonamento.

**Blocco tecnico scoperto verificando il codice**: non esiste ancora nessuna infrastruttura di abbonamento/pagamento reale. C'è una feature `apps/mobile_app/lib/features/billing/` con i piani Free/Plus/Pro, ma è dichiaratamente solo un demo store locale (`BillingDemoStore`, "no billing backend exists yet") — persino i prezzi di Plus e Pro sono un placeholder in attesa di input umano. Il meccanismo "regala una settimana" non ha quindi ancora nulla di reale a cui agganciarsi: la policy va fissata ora (sopra), ma l'implementazione del pulsante "segnala questa risposta" può procedere lato chat (tracciamento) indipendentemente, mentre l'accredito vero e proprio resta bloccato finché non esiste un abbonamento reale da estendere.

Coincidenza utile: il piano Pro nel demo store include già "Riepilogo pre-visita per il veterinario" — la stessa idea del "portale professionista" proposta sopra in "Professionisti come promoter e clienti". I due filoni convergono: vale la pena tenerli allineati quando si passerà dalla fase demo a quella reale.

**Nota legale (da formalizzare quando esisterà un vero sistema di abbonamento)**: il regalo va descritto esplicitamente come privo di valore in denaro, non trasferibile, non cumulabile oltre il tetto fissato, e revocabile in caso di abuso — poche righe da aggiungere alla sezione abbonamenti dei Termini di Servizio ([04_termini_e_consensi.md](../compliance/04_termini_e_consensi.md)) quando quella sezione verrà scritta.

---

**Promemoria**: quando il materiale in questo file sarà sufficiente, l'utente chiederà un riassunto delle potenziali strategie di marketing da validare, sintetizzando le idee raccolte qui.
