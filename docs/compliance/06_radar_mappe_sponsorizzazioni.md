# Radar servizi per animali e sponsorizzazioni — parere operativo

Data: 2026-10-03. Richiesto da: Orchestratore progetto (per conto del proprietario).
Riferimenti tecnici: [docs/features/radar_places_overpass.md](../features/radar_places_overpass.md) e codice verificato alla data.

> **Natura del documento.** Questo è un parere tecnico-normativo operativo, non un parere legale. I punti marcati **⚖️ legale umano** richiedono la revisione di un avvocato abilitato prima di essere considerati definitivi, in particolare per le norme deontologiche veterinarie e le sanzioni consumer.

## Sintesi

| # | Tema | Esito | Condizione |
|---|---|---|---|
| 1 | Licenza ODbL dei dati OSM | Fattibile | Attribuzione sempre visibile; database OSM tenuto separato dai dati propri; nessun export bulk |
| 2 | Policy Overpass e tile | Fattibile, ma con un debito da chiudere | Migrare i tile da `tile.openstreetmap.org` a provider commerciale o self-hosting prima del lancio pubblico; User-Agent con contatto |
| 3 | Pubblicità sanitaria veterinaria | Condizionato | Solo contenuti verificabili; niente comparazioni, promesse o urgenze non verificate ⚖️ |
| 4 | Trasparenza commerciale e ranking | Vincolo forte | Ordinamento urgenze per distanza e apertura, mai a pagamento; sponsor etichettati e separati ⚖️ |
| 5 | Privacy e posizione | Fattibile | Solo cella/coordinate minime; informativa aggiornata con OSM e tile provider; niente profilazione per sponsor |
| 6 | Raccomandazione | Radar: sì. Sezione urgenze: sì, ma come informazione non garantita. Sponsorizzazioni: non ora | Decisioni del proprietario sotto |

## Stato attuale verificato (base del parere)

- Overpass riceve solo il **centro della cella** (griglia 0,05°), mai la posizione esatta; cache condivisa per zona; TTL 168 ore; in caso di errore servono dati scaduti (`coverage.status = "stale"`).
- L'ordinamento è **solo per distanza** (`list_nearby_radar_places.py`). Nel dominio radar non esiste alcun concetto di sponsor, promozione o posizionamento a pagamento.
- I tile sono richiesti direttamente a `tile.openstreetmap.org` sia nella mappa del radar (`local_events_page.dart`) sia nelle mappe delle passeggiate (`walk_map_style.dart`), che contiene anche un ramo CARTO.
- L'attribuzione "© OpenStreetMap contributors" è presente sulla mappa e nella scheda del luogo, con il disclaimer "Orari e contatti possono non essere aggiornati".
- `OVERPASS_USER_AGENT` di default è `VET-APP/1.0`, senza un contatto.
- L'import conserva `opening_hours` come **testo libero**. Non esistono nel codice concetti di "urgenza", "24 ore su 24" o "aperto ora".

## 1. Licenza ODbL dei dati OpenStreetMap

**Cosa obbliga:**
- **Attribuzione** (obbligatoria): "© OpenStreetMap contributors" con link al copyright, visibile su ogni schermata che mostra dati OSM. L'implementazione attuale la rispetta; va mantenuta anche in eventuali viste future, export o PDF.
- **Share-alike** (condivisione alle stesse condizioni): si attiva solo se si **distribuisce** un database derivato da OSM. Mostrare singoli luoghi in un'app è un uso di tipo *produced work*: serve l'attribuzione, non la licenza ODbL sul database.

**Il rischio concreto da evitare:** esporre `radar_places_cache` come dataset. Un endpoint bulk, un export, un download o un'API pubblica che restituisce il database equivale a distribuzione del database derivato, con obbligo di rilasciarlo in ODbL. Oggi la tabella ha RLS senza policy e viene letta solo dal backend, e l'API restituisce luoghi filtrati per distanza: è la configurazione corretta. Va mantenuta.

**Separare i dati propri (sponsor) da OSM:**
- Le schede sponsorizzate vanno in una **tabella separata** (es. `sponsor_listings`) che referenzia il luogo OSM per id. Non vanno mai scritte in `radar_places_cache`.
- La composizione avviene **a tempo di query**, nel presentation layer. In questo modo il database OSM resta puro e i dati propri non diventano "derivati" da OSM.
- I dati propri (telefono del sponsor, testo promozionale) **non vanno mai reinviati a OpenStreetMap**: OSM vieta la pubblicità nei propri dati e un contributo ai dati OSM comporta obblighi ODbL.

**Dove serve un legale umano ⚖️:** confermare che il solo uso della cache per servire luoghi singoli agli utenti autenticati non costituisca "database derivato distribuito" nella configurazione finale.

## 2. Policy d'uso di Overpass API e dei tile server

**Overpass (server pubblici):**
- Sono risorse condivise e gratuite con limiti di uso equo. Rispondono con 429 o 504 sotto carico. Il design attuale è corretto: cache per cella, fallback, timeout.
- Lo User-Agent deve identificare l'app **e un contatto**. Il default `VET-APP/1.0` non lo fa: va impostato in produzione (es. `VETAPP/1.0 (contatto: <indirizzo tecnico>)`).
- Per un volume significativo l'uso dei server pubblici non è sostenibile. Opzioni: istanza Overpass propria oppure **estratto OSM dell'Italia** (Geofabrik) importato periodicamente in un'istanza propria. È la strada più pulita e si accorda al piano già descritto nella documentazione tecnica.

**Tile server OSM (`tile.openstreetmap.org`):**
- La policy d'uso dei tile pubblici non consente l'uso intensivo o come servizio primario di un'app. Il radar e le mappe delle passeggiate usano già il server pubblico direttamente.
- Oggi, prima del lancio pubblico, il rischio è basso. Va chiuso **prima** di avere utenti reali in volume. Diventare commerciali (abbonamenti già in arrivo) non è di per sé il criterio: lo è il volume di richieste.
- Opzioni: provider commerciale di tile (MapTiler, Stadia Maps, Mapbox, Thunderforest o simili, ognuno con prezzi, regole di attribuzione e chiavi API) oppure self-hosting dello stack di tile (costo infrastrutturale). Il ramo CARTO in `walk_map_style.dart` ha termini propri da rispettare.
- Soglia operativa proposta: migrare i tile prima del lancio pubblico. Il proprietario deve fissare il budget.

**Dove serve un legale umano ⚖️:** verificare i termini correnti dei provider scelti (la clausola di attribuzione e l'eventuale limite di richieste nei piani gratuiti).

## 3. Pubblicità sanitaria veterinaria in Italia ⚖️

Principi generali (da confermare con legale e con l'Ordine provinciale competente):
- La pubblicità dei professionisti è ammessa purché **veritiera, corretta, non ingannevole** e nel rispetto della dignità professionale (disciplina nazionale sulla pubblicità dei professionisti, integrata dai codici deontologici). Il codice deontologico FNOVI detta limiti più stringenti sulla pubblicità sanitaria veterinaria: il testo esatto degli articoli applicabili va verificato con legale.
- Sono da escludere, con buona probabilità, nelle schede sponsorizzate:
  - comparazioni o superiorità ("il migliore", "più veloce della concorrenza");
  - promesse di risultato o di guarigione;
  - specializzazioni o competenze non possedute (una specializzazione dichiarata senza titolo è ingannevole);
  - disponibilità "24 ore" o "urgenze" **non verificate**;
  - sollecitazione a clienti non richiesti; testimonianze che lascino intendere risultati clinici.
- Sono verosimilmente leciti, se verificati: nome, indirizzo, contatti, orari **verificati dalla struttura**, servizi effettivamente offerti, specie trattate, canali di contatto, logo, prezzi chiari se dichiarati.
- Condizione di ingresso: la struttura deve essere **regolarmente autorizzata** (il controllo di autorizzazione sanitaria spetta all'ASL competente) e deve garantire per iscritto l'accuratezza dei propri dati. Il contratto con la struttura deve prevedere la rimozione immediata di dati non veri.

**Punto critico per le urgenze:** un orario "24 ore" o un servizio di pronto soccorso dichiarato e non vero è un danno potenziale alla salute dell'animale. Il rischio è molto superiore a quello di una pubblicità commerciale ordinaria.

## 4. Trasparenza commerciale, ranking e DSA/Omnibus ⚖️

**Etichetta:** ogni scheda a pagamento deve riportare in modo visibile "Sponsorizzato" (o "Annuncio"), non in caratteri piccoli o nascosti. L'omissione della natura commerciale è un'omissione ingannevole ai sensi del Codice del consumo (D.Lgs. 206/2005). La Direttiva Omnibus (UE 2019/2161, recepita in Italia) rafforza l'obbligo di chiarezza su ranking e posizionamento.

**Criteri di ordinamento dichiarati:** oggi l'app ordina per distanza, ed è una scelta trasparente. Se in futuro comparirà un posizionamento a pagamento:
- i criteri di ranking vanno dichiarati nell'app;
- va esplicitato se il pagamento influenza la posizione;
- le schede sponsor non devono apparire come risultati organici senza distinzione.

**Il caso delle urgenze (il più rischioso):** se una sezione presentata come utile per le urgenze mostra per prima una struttura lontana o chiusa solo perché paga, si tratta di pratica ingannevole (falsa rappresentazione di imparzialità e rilevanza) con potenziale danno all'animale. **Regola vincolante proposta:** nella sezione urgenze l'ordinamento è solo per distanza e stato di apertura, mai per pagamento. Le sponsorizzazioni, se mai, vivono in una sezione separata e dichiarata.

**DSA (Reg. UE 2022/2065):** l'art. 25 vieta gli *interface design* ingannevoli (dark pattern): una scheda sponsor graficamente indistinguibile da una organica lo sarebbe. L'art. 26 impone di indicare che un contenuto è pubblicità, per conto di chi, e i parametri principali di destinazione. L'applicabilità all'app dipende dalla qualifica di piattaforma online e dalle esenzioni per microimprese e piccole imprese (art. 19): va verificata da un legale ⚖️.

**Urgenze e dati OSM non verificati:** OSM non garantisce né copertura né aggiornamento di "emergenza" o "24 ore" (il tag è usato in modo disomogeneo e `opening_hours` è testo libero). Presentare come "urgenza" un dato OSM senza verifica sarebbe un'affermazione non supportata. Regola: finché le strutture non confermano il servizio di urgenza, la sezione va etichettata come informazione non garantita, con invito a telefonare prima di recarsi sul posto. Il disclaimer attuale ("Orari e contatti possono non essere aggiornati") è troppo debole per questo uso: va rafforzato nel contesto urgenze, e lo stato `stale` va mostrato all'utente.

## 5. Privacy: posizione per il radar

**Natura del dato:** la posizione è dato personale (GDPR art. 4(1)). Quella precisa, ripetuta nel tempo, rivela abitudini e luoghi frequentati: va trattata con attenzione proporzionale.

**Base giuridica:** per la funzione richiesta esplicitamente dall'utente ("servizi vicino a me") regge l'esecuzione del servizio (art. 6(1)(b)), senza consenso separato. Servono comunque l'**informativa** (art. 13) con: posizione come dato trattato; **Overpass/OSM** come destinatari dei dati di cella; **provider dei tile** come destinatario, perché riceve indirizzo IP e coordinate delle tile richieste.

**Minimizzazione (già in buona parte presente):**
- Overpass riceve solo il centro di cella. Questo è il punto più forte del disegno attuale.
- Il backend riceve però la posizione esatta a ogni richiesta, perché l'ordinamento per distanza la usa. È un compromesso da decidere: ordinare per distanza dal centro della cella è meno preciso ma non richiede la posizione esatta lato server. Si può anche arrotondare le coordinate sul client prima dell'invio.
- Nessun log, analytics o tabella deve conservare la posizione esatta della richiesta; va conservata solo la chiave di cella.
- Non va creata una cronologia di posizioni per il radar.

**Coerenza con [05_permessi_dispositivo_os.md](05_permessi_dispositivo_os.md):**
- Permesso di posizione **solo in foreground** ("while in use"), mai in background.
- Richiesta **just-in-time** quando l'utente apre la sezione dei servizi vicini, non all'avvio.
- Degradazione graduale: se il permesso è negato, il radar funziona con l'indirizzo inserito manualmente (già previsto dalla funzione Località). Questo rispetta il principio di graceful degradation.

**Profilazione sponsor:** usare la posizione per decidere quali sponsor mostrare è profilazione a fini pubblicitari. Non è necessaria all'erogazione del servizio, quindi richiederebbe un consenso opt-in dedicato. **Raccomandazione: nessuna targetizzazione per posizione in v1.**

## 6. Raccomandazione finale

**Radar servizi (già costruito): fattibile.** Condizioni:
1. Attribuzione OSM mantenuta su ogni vista e nelle eventuali esportazioni.
2. Nessun endpoint bulk o export della cache OSM.
3. User-Agent di produzione con contatto.
4. Piano di migrazione dei tile prima del lancio pubblico.
5. Informativa privacy aggiornata con OSM/Overpass e provider dei tile.

**Sezione "Cliniche e ambulatori" per le urgenze: fattibile solo come informazione non garantita.** Finché le strutture non confermano il servizio di urgenza, la sezione non deve dichiarare 24 ore o pronto soccorso. Il percorso verso una versione affidabile passa dalla verifica dei dati da parte delle strutture (auto-dichiarazione validata), non dal solo dato OSM.

**Sponsorizzazioni: non ora.** Se in futuro saranno introdotte, solo a queste condizioni:
- mai nella sezione urgenze, né in alcuna posizione che alteri l'ordine per distanza o apertura;
- etichetta "Sponsorizzato" ben visibile e grafica distinta dalle schede organiche;
- dati della struttura verificati e garantiti per iscritto;
- nessuna comparazione, promessa o specializzazione non verificata;
- tabella separata e composizione a tempo di query;
- nessuna targetizzazione per posizione;
- parere legale su FNOVI, consumer law e DSA prima di attivare un solo pagamento.

## Decisioni per il proprietario

1. Se consentire mai contenuti a pagamento nel radar. Raccomandazione: al massimo in una sezione directory non urgente, mai nelle urgenze.
2. Modello di verifica delle urgenze: auto-dichiarazione delle strutture con validazione, oppure sola informazione OSM con disclaimer forte.
3. Budget e soglia per migrare i tile (provider commerciale o self-hosting) e per l'istanza Overpass/estratto OSM.
4. Scelta del legale che rivede i punti ⚖️ prima del lancio.
5. Compromesso privacy: ordinamento per distanza precisa (posizione esatta lato server) oppure per distanza dal centro cella (più privato).

## Dove serve un legale umano ⚖️

- Testo esatto degli articoli applicabili del codice deontologico FNOVI e dell'Ordine provinciale.
- Disciplina nazionale della pubblicità dei professionisti applicabile alle strutture veterinarie.
- Recepimento italiano della Direttiva Omnibus e applicabilità di DSA artt. 19, 25, 26 all'app.
- Configurazione finale del database: conferma che non vi sia distribuzione di database derivato da OSM.
- Termini correnti dei provider di tile scelti.
- Contratto tipo con le strutture che espongono schede a pagamento.
