# Brief VetApp — per analisi di marketing e piani di abbonamento

Documento autosufficiente da consegnare a un LLM (o consulente) per studiare posizionamento, marketing e struttura dei piani di abbonamento. Fotografia al 2026-10-06.

---

## 1. Cos'è Quokka in una frase

App che aiuta chi vive con un animale a **capirlo e gestirlo bene** (etologia, relazione, gestione quotidiana, salute, doveri del proprietario), con risposte basate su evidenze e posizioni ufficiali: è uno strumento di divulgazione, non un corso (riposizionamento del 2026-11-01, `docs/product/11_…`). Riunisce in un solo posto: un **assistente IA evidence-based** per capire perché l'animale fa quello che fa, come gestirlo e quando serve il veterinario, il **profilo e lo storico** di ogni animale (cartella clinica, galleria, promemoria) e una **parte "territorio"** (servizi per animali nei dintorni, passeggiate GPS, eventi locali, mercatino dell'usato).

Posizionamento dichiarato: **"supporto, non sostituzione" del veterinario**. L'app orienta e aiuta a decidere meglio; per i casi seri rimanda sempre al professionista.

## 2. Stato del prodotto

- **Fase**: pre-lancio. Build Android distribuite a un gruppo di tester (Firebase App Distribution, build 24); versione web in produzione su Vercel.
- **Mercato iniziale**: Italia (app, copy e normativa in italiano; dati ospitati in UE, Irlanda).
- **Pagamenti**: **nessun addebito reale collegato**. Esiste la logica di abbonamento (trial + scelta piano) ma non un processore di pagamento.
- **Team**: fondatore singolo/piccolo team non tecnico che sviluppa con assistenti IA; costi operativi da tenere molto bassi.

## 3. Target

**Persona primaria — proprietario coinvolto e digitale**: vive l'animale come parte della famiglia, cerca già informazioni online ma si sente disperso tra fonti contraddittorie. Cerca tranquillità, organizzazione, continuità, senso di controllo.

**Persona secondaria — proprietario pragmatico**: vuole una risposta veloce, un'azione consigliata, promemoria chiari, zero complessità.

**Non target in v1**: il veterinario come acquirente. Però i professionisti (veterinari, educatori cinofili, toelettatori) sono visti come **potenziale canale di acquisizione** (vedi §7).

**Specie supportate** (nomenclatura ufficiale): Cane, Gatto, Piccoli mammiferi (coniglio, criceto, cavia, cincillà, gerbillo, furetto), Uccello, Rettili e anfibi (drago barbuto, gecko leopardino, testuggine, serpente del mais, rana, salamandra, axolotl), Pesce. La copertura degli "esotici" è un differenziatore rispetto ad app solo cane/gatto.

## 4. Funzionalità esistenti (già costruite)

### Cuore "capire e ricordare" (ex "salute e memoria")
- **Profili animali multipli**: specie, razza, taglia, dati anagrafici, foto.
- **Chat con assistente IA**:
  - conversazioni multiple con titoli, rinomina, storico;
  - allegati foto e PDF, dettatura vocale;
  - risposte contestualizzate sul profilo dell'animale;
  - **anamnesi prima della risposta**: su sintomi vaghi l'assistente fa domande invece di inventare;
  - **safety gate**: sui casi a rischio rimanda al veterinario; ogni risposta è etichettata come generata da IA e mostra fonti/limiti;
  - **riepilogo per il veterinario** generato dalla conversazione.
- **Cartella clinica**: caricamento di documenti (PDF/foto), accesso dell'assistente solo con **consenso esplicito e revocabile per singolo animale**.
- **Galleria** per animale: cartelle, foto e video, import multiplo. I metadati sensibili (es. posizione GPS nelle foto) vengono rimossi lato server.
- **Promemoria** sanitari e di routine (vaccini, antiparassitari, controlli…).

### Parte "territorio e community"
- **Radar "Servizi per animali"**: mappa di cliniche, ambulatori, negozi, aree cani ecc. da dati aperti (OpenStreetMap, Overture, dati comunali), con chiamata e indicazioni. Funzione **"Segnala!"** per aggiungere luoghi mancanti e **stelle alle aree cani** (contributi della community).
- **Passeggiate GPS** per il cane: tracciamento percorso, storico, preferite (max 5), **badge/traguardi** su distanza cumulativa.
- **Eventi e attività locali** nella zona dell'utente.
- **Mercatino dell'usato** tra utenti (annunci con segnalazione).
- **Curiosità/news** per specie in Home.

### Account e onboarding
- Registrazione, login, recupero credenziali.
- Dopo la registrazione: presentazione dei piani, tutorial, aggiunta del primo animale.
- **Prova gratuita di 14 giorni senza carta**. Alla scadenza l'utente deve scegliere un piano (Plus, Pro o Ultra): il piano Free non esiste più (decisione del 2026-11-06). Senza piano restano solo i propri dati: esportazione, cancellazione dell'account, indicazioni di emergenza. Il parere legale sul blocco senza Free è da rifare.
- Impostazioni: consensi (ToS, privacy, marketing, analytics), località (GPS o indirizzo manuale), layout Home.

## 5. Struttura abbonamento (decisa il 2026-11-06; limiti aggiornati il 2026-11-07, modificabili più avanti)

Tre piani a pagamento, **Plus / Pro / Ultra**, con fatturazione **mensile o annuale** (l'annuale vale 10 mensilità, sconto circa 16,6%). Il piano Pro ha l'etichetta "Consigliato". Non c'è un piano Free.

Le funzioni sono le stesse in tutti i piani (profili, assistente, allegati in chat, promemoria, servizi nei dintorni); cambiano i **limiti**, applicati dal backend:

| | Plus | Pro | Ultra |
|---|---|---|---|
| Animali | 4 | 8 | 15 |
| Chat per animale | 2 | 4 | 6 |
| Domande al giorno | 12 | 25 | 50 |
| Dispositivi contemporanei | 2 | 3 | 3 |
| Prezzo mensile (Italia) | 4,59 € | 8,59 € | 15,59 € |
| Prezzo annuale (Italia) | 45,99 € | 85,99 € | 155,99 € |

Durante la prova valgono i limiti del Pro.

**Test con il pubblico (decisione del 2026-11-07).** Finché dura il test nessuno paga e tutti hanno sempre il piano Pro, anche finita la prova di 14 giorni. Si accende solo dall'ambiente del backend (`SUBSCRIPTION_TEST_PLAN=pro`); l'app non mostra richieste di pagamento né la scelta del piano, ma una dicitura sul periodo di test. Spento (predefinito), tutto resta come descritto qui.

**Dopo la prova, senza abbonamento** (con il test spento): gli Eventi sono bloccati; il Mercatino mostra gli annunci degli altri solo con oggetto, prezzo, foto, città e distanza (niente descrizione, categoria, specie né posizione sulla mappa) e non permette di pubblicare, modificare né segnalare; tutto il resto è bloccato e restano esportazione dei dati, cancellazione dell'account e indicazioni di emergenza. Il filtro è applicato dal backend. Le emergenze non contano mai nelle domande al giorno. I prezzi degli altri paesi sono nella proposta [03_prezzi_per_paese.md](03_prezzi_per_paese.md). Un'idea già emersa è riservare al Pro il riepilogo pre-visita per il veterinario (non decisa).

## 6. Struttura dei costi (rilevante per il pricing)

Questi costi crescono con l'uso e determinano cosa conviene limitare nei piani:

| Voce | Cosa la fa crescere | Note |
|---|---|---|
| **LLM della chat** | numero di messaggi, lunghezza conversazioni, allegati analizzati | Oggi su provider a basso costo (Groq, tier gratuito con tetto giornaliero condiviso). Al lancio diventa la voce variabile principale |
| **Storage** | foto/video in galleria, PDF della cartella clinica, allegati chat, percorsi GPS | Supabase (UE). I percorsi GPS vecchi vengono già "potati" per risparmiare spazio |
| **Backend** | richieste API | Vercel serverless, costo contenuto |
| **Mappe/dati luoghi** | consultazioni radar | Dati aperti con cache condivisa, costo marginale basso |

Le leve naturali per differenziare i piani sono quindi: **messaggi IA al giorno/mese**, **numero di animali**, **spazio di archiviazione** (galleria/video/cartella), **funzioni premium** (riepilogo vet, analisi documenti, storico illimitato).

## 7. Idee di marketing già raccolte (da validare)

- **Hook di acquisizione**: "14 giorni gratis, nessuna carta richiesta".
- **Feedback degli utenti**: nessun premio in settimane gratis legato a un voto o a una recensione (positiva o negativa): tolto il 2026-11-03 per decisione del proprietario, non è accettabile legalmente. Resta l'idea di chiedere a tutti gli utenti cosa serve per renderli pienamente soddisfatti, senza premi.
- **Segnalazione bug in chat**: 1 settimana gratis per ogni bug risolto, verificato a mano, con tetto mensile per utente.
- **Professionisti come promoter**: codici referral per clinica, portale/riepilogo pre-visita per il vet, widget co-brandizzato, account pro gratuito in cambio di referral, comitato scientifico di veterinari, contenuti formativi (ECM).
- **Community/dati aperti**: le segnalazioni di luoghi rendono il radar migliore della concorrenza. Una collaborazione con OpenStreetMap è stata accantonata come idea futura.
- **Sponsorizzazioni nel radar** (attività locali in evidenza): aspetti normativi in valutazione.

## 8. Vincoli e principi da rispettare

- **Mai** comunicare l'app come alternativa alla visita veterinaria. Nessuna promessa diagnostica.
- Trasparenza IA (AI Act / disclosure) e GDPR: dati sanitari degli animali ma **dati personali dei proprietari**. Consensi granulari già implementati.
- Nessun premio (settimane gratis o altro) legato a voti o recensioni: deciso dal proprietario il 2026-11-03, non è accettabile legalmente e viola le policy degli store (Google Play/App Store).
- I premi in giorni di abbonamento non hanno valore in denaro, non sono trasferibili e hanno un tetto.
- Senza il Free, dopo la prova chi non si abbona deve comunque poter esportare i propri dati, cancellare l'account e trovare le indicazioni di emergenza (obblighi GDPR e di sicurezza).

## 9. Concorrenza da considerare (non ancora analizzata a fondo)

App di gestione pet (diari salute, promemoria), app di telemedicina/chat veterinaria a pagamento, app per passeggiate e community cinofile, assistenti IA generici (ChatGPT ecc.) usati "fai da te". Il differenziatore atteso è il **tutto-in-uno contestualizzato sul singolo animale** + **affidabilità/sicurezza** + **specie esotiche** + **territorio italiano**.

---

## 10. Domande per l'analisi

1. Quale modello di monetizzazione conviene a questo prodotto e a questo stadio: freemium, trial con paywall, abbonamento unico, a consumo, ibrido?
2. Servono davvero 3 piani (Plus/Pro/Ultra) o ne bastano 2? Cosa mettere in ciascuno, partendo dalle leve di costo del §6?
3. Quale fascia di prezzo mensile/annuale è credibile per il mercato italiano pet-care, considerando il confronto con un consulto veterinario e con le app concorrenti?
4. Conviene un **piano "famiglia/multi-animale"** o un prezzo per animale aggiuntivo?
5. Come usare la componente B2B2C (veterinari, educatori, negozi): piano professionale a pagamento, referral, sponsorizzazioni nel radar?
6. Quali funzioni tenere gratuite come **motore di acquisizione e retention** (es. radar, passeggiate, promemoria) e quali sono il vero "momento aha" da mettere dietro paywall?
7. Strategia di lancio: canali (social, community cinofile, cliniche, gruppi di proprietari di esotici), messaggi chiave e metriche da monitorare (conversione trial→pagante, retention a 30 giorni, costo IA per utente).
8. Rischi: costo IA per utente superiore al prezzo, percezione di "app medica".
