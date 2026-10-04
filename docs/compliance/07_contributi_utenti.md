# Contributi degli utenti nel radar — parere operativo (perimetro ridotto)

Data: 2026-10-03. Aggiornato con il perimetro ridotto deciso dal proprietario. Richiesto da: Orchestratore progetto.
Collegato a [06_radar_mappe_sponsorizzazioni.md](06_radar_mappe_sponsorizzazioni.md).

> **Natura del documento.** Parere tecnico-normativo operativo, non legale. I punti marcati **⚖️** richiedono la revisione di un avvocato abilitato prima di diventare definitivi.

## Perimetro attivo

Decisione del proprietario, dopo la lettura del parere precedente (motivi: spazio e rischi legali):

- **Segnala!**, con tre tipi: *luogo mancante* (categoria da elenco chiuso, nome breve, posizione), *luogo chiuso*, *doppione o posizione errata*.
- Stato **"in attesa di conferma"**, che diventa definitivo con **5 conferme da utenti diversi** (soglia configurabile).
- Identità di chi segnala e di chi conferma **mai esposta**, solo pseudonimo.
- **Stelle da 1 a 5 solo per le aree cani**, media visibile con almeno 3 voti, senza testo.

**Non attivo** (vedi appendice): foto, testo libero, conferme su caratteristiche (recinzione, acqua, illuminazione), valutazioni di veterinari, negozi o attività.

## Sintesi decisionale

| Contributo | Esito | Condizioni |
|---|---|---|
| Segnalazione "luogo mancante" | **Fattibile con condizioni** | Categorie ristrette (sotto); nome commerciale; posizione; conferme e pseudonimi (sotto) |
| Segnalazione "luogo chiuso" | **Fattibile con condizioni più stringenti** | Lo stato pendente non è pubblico; contestazione del titolare; anti-abuso (sotto) |
| Segnalazione "doppione o posizione errata" | **Fattibile con condizioni** | Stesso canale di contestazione |
| Stelle sulle aree cani | **Fattibile subito** | Solo aree pubbliche esistenti; un voto per utente e area; media con almeno 3 voti |

## 1. Obblighi come piattaforma (DSA)

**Qualifica.** Il servizio mostra a tutti gli utenti dati inseriti da utenti (segnalazioni e voti): è plausibilmente una **piattaforma online** ai sensi del Reg. (UE) 2022/2065.

**Esenzione per le piccole imprese (art. 19 DSA).** Esclude la Sezione 3 (reclamo interno, risoluzione extragiudiziale, segnalatori attendibili, dark pattern, pubblicità, raccomandazioni). Restano obbligatori:
- punto di contatto per utenti e autorità (artt. 11–12), raggiungibile dall'app;
- condizioni d'uso con le regole di moderazione (art. 14);
- meccanismo di **segnalazione e rimozione** (art. 16): per questo perimetro è la contestazione del titolare;
- **motivazione** di ogni decisione di rimozione o limitazione (art. 17).

**Soglie.** L'esenzione dipende dalla Raccomandazione 2003/361/CE. Se si superano, si applica l'intera Sezione 3. ⚖️ Verificare al momento.

**Il perimetro ridotto abbassa molto il rischio di contenuto illecito**, perché i dati sono strutturati (categorie, stati, voti) e non c'è testo libero né immagini. Resta però il rischio di **affermazioni false su attività identificabili**, cioè la diffamazione (art. 595 c.p.) e la concorrenza sleale (art. 2598 c.c.), che la protezione dell'hosting (art. 6 DSA) copre solo con una risposta tempestiva.

## 2. Rischi residui

### 2.1 Nome di un'attività inserito dall'utente

**Il rischio.** Un "nome breve" può essere il nome di una persona che opera come ditta individuale (educatore, pet sitter, toelettatrice). È un dato personale, raccolto da un terzo, quindi scatta l'obbligo di informativa indiretta (art. 14 GDPR).

**Mitigazioni.**
- Nome commerciale **come appare sull'insegna**, con limite di lunghezza; nessun campo per telefono, email, indirizzo privato o URL.
- Filtro automatico su insulti e nomi di persone privati; moderazione manuale dei nomi prima della visibilità di massa.
- Stato "in attesa" finché non si raggiunge la soglia di conferma.
- Base giuridica: legittimo interesse (art. 6(1)(f)), con valutazione documentata. L'attività professionale è pubblica e registrata, quindi il pregiudizio atteso è basso.
- Informativa pubblica con la fonte dei dati; diritto di rettifica (art. 16) e di opposizione (art. 21), con il canale di contestazione (2.2).

**Rischio residuo specifico: sede domestica.** Pet sitter, educatori a domicilio e pensioni familiari lavorano spesso da casa. Una **posizione esatta** segnalata per loro rivela l'indirizzo di abitazione. **Regola:** per le categorie svolte a domicilio la posizione è approssimata (circa 500 metri o il comune), mai il punto esatto. ⚖️

### 2.2 Segnalazione falsa "chiuso" contro un concorrente

**Risposta diretta: la soglia di 5 e la non-rimozione non bastano da sole.** Tre ragioni:

1. **Lo stato pendente è già pubblico.** Mostrare "in attesa di conferma: chiuso" equivale a un'affermazione non verificata sull'attività, esposta a tutti. Produce danno immediato, prima di qualsiasi decisione. Per "chiuso" il luogo deve restare visibile normalmente e la segnalazione pendente deve essere visibile solo ai moderatori. Per "mancante" e "doppione" l'etichetta pubblica "in attesa" resta accettabile, perché il danno potenziale è minore.
2. **Cinque account sono economici da creare.** La soglia funziona solo se i conteggi riguardano account verificati.
3. **Senza un canale di contestazione** il titolare non ha rimedio rapido. Ed è il primo passo che chiede il GDPR (art. 16 e 21 per le ditte individuali) e che riduce l'esposizione per diffamazione.

**Misure richieste:**
- **Anti-sybil:** conteggio solo su account con email verificata; per "chiuso" account di almeno 7 giorni; massimo 5 segnalazioni al giorno per account; una sola segnalazione attiva per luogo e tipo per account; rilevazione di cluster (molti account nuovi sullo stesso luogo in poche ore) con congelamento e revisione.
- **Soglia più alta per "chiuso"** rispetto alle altre segnalazioni, come parametro separato e configurabile.
- **Canale di contestazione per il titolare:** modulo dalla scheda e dal contatto pubblico. Verifica proporzionata (P.IVA e un'email del dominio aziendale). Durante la contestazione lo stato negativo è **sospeso**, cioè non visibile. Esito motivato entro 5 giorni lavorativi, registrato nel log.
- **Sanzioni** per segnalazioni false ripetute (sospensione dell'account), senza rivelarne il motivo specifico agli altri utenti.
- **Effetto sul dato open:** nascondere la segnalazione non modifica OpenStreetMap né Overture.

### 2.3 Luoghi privati segnalati come area cani

**Rischi.** Un'area privata presentata come area cani può portare visitatori in una proprietà altrui (invasione di terreni, art. 637 c.p. ⚖️) e identifica pubblicamente un'abitazione o un fondo privato, con dati dei residenti collegati. Il proprietario non avrebbe altro modo di fermare le visite che la contestazione.

**Regole per la v1:**
- **"Area cani" non è selezionabile come categoria di luogo mancante.** Chi vuole segnalare un'area nuova lo fa come "luogo mancante" in un'altra categoria, oppure non lo fa.
- Le **stelle si assegnano solo ad aree cani esistenti e pubbliche**, cioè con tag `leisure=dog_park` e senza gestore commerciale o tariffa (tag `fee` o `operator` privato). ⚖️ Valutazione tecnica dei tag.
- Le **aree a pagamento gestite da un'attività** sono escluse dalle stelle in v1. Una stella su un'area gestita da un'impresa è una recensione di un operatore commerciale e rientra nelle regole Omnibus sulle recensioni.
- Il proprietario di un fondo privato usa lo stesso canale di contestazione; la sospensione è immediata.

### 2.4 Pseudonimi e conservazione

- **Pseudonimo a chiave (HMAC-SHA256)** calcolato sull'id utente con una chiave segreta del server, conservata fuori dal database. Non serve una tabella di corrispondenza, e alla cancellazione dell'account si ricalcola lo pseudonimo per trovare e cancellare o anonimizzare i contributi. Lo pseudonimo non è mai esposto.
- **Conservazione:** segnalazioni non confermate eliminate dopo 90 giorni; segnalazioni definitive conservate con stato e data; dati del segnalatore pseudonimi per 12 mesi dall'esito, poi solo contatori.
- **Il precedente della chat va allineato:** `ChatResponseReport` salva `reporter_owner_id` in chiaro e copia il testo della risposta, che può contenere dati sanitari sull'animale. ([packages/core/domain/feedback/models.py](../../packages/core/domain/feedback/models.py))

### 2.5 Stelle su aree cani: rischio residuo basso

Dato un luogo pubblico esistente e un voto per utente, il rischio di diffamazione è basso. Restano il rischio di voti concertati (gestiti dall'anti-sybil) e la regola "niente testo" che evita attacchi personali.

## 3. Regole d'uso da accettare prima della prima segnalazione o voto

Testo breve, con accettazione esplicita (casella da spuntare) e versione registrata nella chiave di consenso `contribution_rules`. Non è un gate dell'app: contribuire è facoltativo.

> **Regole per segnalazioni e voti**
>
> 1. Segnala solo ciò che hai verificato di persona o che sai con certezza.
> 2. Per le attività scrivi solo il nome commerciale, come appare sull'insegna. Non inserire telefoni, indirizzi privati, email o dati di altre persone.
> 3. Le segnalazioni restano "in attesa di conferma" finché altri utenti non le confermano. Non sono una garanzia: verifica sempre prima di recarti in un luogo.
> 4. I voti sulle aree cani sono opinioni personali: un voto per area.
> 5. Non segnalare come area cani proprietà private e non invitare altri a entrare in luoghi privati.
> 6. Non usare le segnalazioni per danneggiare un'attività. Segnalazioni false o ripetute possono portare alla sospensione dell'account.
> 7. Le attività possono chiedere una correzione o la rimozione di un dato: verifichiamo e rispondiamo entro 5 giorni lavorativi.
> 8. Le tue segnalazioni e i tuoi voti sono pubblicati senza il tuo nome né i tuoi dati personali, che restano trattati come da informativa privacy.
>
> [ ] Ho letto le regole e segnalo o voto in buona fede.

Revocare l'accettazione blocca solo le nuove segnalazioni e i nuovi voti; quelli esistenti restano nei termini di conservazione.

## 4. Bozze per informativa privacy

**A. Contributi degli utenti**

> Se segnali un luogo o esprimi un voto, trattiamo lo pseudonimo collegato al tuo account e i dati che inserisci (categoria, nome commerciale, posizione, stato) per mostrare la segnalazione nell'app come "Secondo gli utenti VetApp", per verificare le conferme e per gestire le contestazioni. Basi giuridiche: esecuzione del servizio richiesto (art. 6(1)(b) GDPR) e legittimo interesse alla qualità dei dati (art. 6(1)(f)). Destinatari: fornitori tecnici di hosting e database. Conservazione: come indicato nelle regole d'uso. Puoi cancellare i tuoi contributi in qualsiasi momento.

**B. Dati di terzi nelle fonti aperte e nelle segnalazioni**

> Le informazioni sui luoghi provengono da fonti aperte (OpenStreetMap, Overture Maps, Foursquare, dati dei Comuni) e da segnalazioni degli utenti. Possono riguardare attività commerciali, incluse ditte individuali. Se un dato ti riguarda e risulta inesatto o da rimuovere, usa il modulo "Richiedi correzione o rimozione" o scrivi a [contatto dedicato]. Rispondiamo entro un mese.

## 5. Dati dei Comuni

Solo dataset con licenza esplicita **IODL 2.0**, **CC-BY 4.0** o **CC0**, verificata e con versione, tracciati in `data_sources` con fonte, licenza, URL, data di import e testo di attribuzione. Escluse le licenze con clausola NC e i dataset senza licenza. Verificare la presenza di dati personali di persone fisiche ⚖️ (D.Lgs. 36/2006, come modificato dal D.Lgs. 200/2021).

## Condizioni tecniche

1. **Segnalazioni in stato "in attesa"** visibili pubblicamente per "mancante" e "doppione"; per "chiuso" visibili solo ai moderatori finché non sono definitive.
2. **Soglie** configurabili: 5 conferme da account distinti e verificati per il definitivo; soglia separata e più alta per "chiuso"; età minima dell'account per "chiuso".
3. **Anti-sybil:** email verificata; massimo 5 segnalazioni al giorno per account; una segnalazione attiva per luogo e tipo; rilevazione di cluster con congelamento.
4. **Pseudonimi** HMAC-SHA256 con chiave del server fuori dal database; mai esposti; ricalcolo alla cancellazione dell'account.
5. **Canale di contestazione** per il titolare: modulo con verifica proporzionata, sospensione dello stato negativo durante l'esame, esito motivato entro 5 giorni lavorativi, log.
6. **Categorie:** "area cani" non selezionabile come luogo mancante in v1; posizione approssimata per le categorie a domicilio.
7. **Stelle:** solo su aree cani esistenti e pubbliche (tag `leisure=dog_park`, senza gestore commerciale o tariffa); un voto per utente e area; media visibile con almeno 3 voti; nessun testo.
8. **Consenso `contribution_rules`:** versionato, accettato prima della prima segnalazione o voto, revocabile, non bloccante per l'app.
9. **Nome:** lunghezza massima, filtro su insulti e nomi di persone, nessun campo di contatto.
10. **Conservazione:** non confermate eliminate a 90 giorni; dati del segnalatore pseudonimi per 12 mesi dall'esito; poi solo contatori.
11. **Allineamento della chat:** pseudonimizzare `reporter_owner_id` in `ChatResponseReport` e definire la conservazione di `reported_answer`.

## Dove serve un legale umano ⚖️

- Soglie di esenzione DSA e obblighi residui (artt. 11–17).
- Legittimo interesse per i nomi di ditte individuali e per le posizioni a domicilio.
- Invasione di terreni (art. 637 c.p.) per le aree private, e responsabilità del titolare.
- Valutazione dei tag OSM che definiscono un'area cani pubblica.
- Tempi di risposta e verifica proporzionata nella contestazione.
- Periodi di conservazione proposti.

---

## Appendice — non attivo (decisione del proprietario, 2026-10-03)

Le parti seguenti restano come riferimento se il perimetro verrà riaperto. Non vanno implementate.

**Foto.** Persone riconoscibili: artt. 96–97 L. 633/1941 e art. 10 c.c. richiedono il consenso, salvo eccezioni. Minori: vietati. Targhe: sfocatura o rifiuto. Abitazioni: vietato identificarle. Metadati EXIF (GPS, dispositivo) rimossi lato server, con ricodifica: il rischio più grave. Licenza non esclusiva, senza vendita e senza pubblicità di terzi; i diritti morali sono inalienabili in Italia (artt. 20–22 L. 633/1941 ⚖️). Pre-moderazione obbligatoria.

**Testo libero.** Lunghezza massima, filtro abusi, niente telefoni, URL o nomi di persone, segnalazione e moderazione.

**Conferme su recinzione, acqua, illuminazione.** Fattibili come voti, ma il perimetro ridotto li ha esclusi per semplicità.

**Valutazioni di veterinari, negozi e attività.** Sconsigliate in v1: diffamazione; asimmetria con il segreto professionale, che impedisce una replica adeguata; obblighi Omnibus su recensioni verificate (Dir. UE 2019/2161); conflitto con le sponsorizzazioni; possibili limiti deontologici FNOVI ⚖️; dati sanitari che emergono dal contenuto.
