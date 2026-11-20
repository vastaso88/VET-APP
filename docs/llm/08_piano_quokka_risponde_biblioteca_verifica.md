# Piano approvato il 20/11/2026 (versione finale della giornata): Quokka risponde, le fonti verificano, la biblioteca cresce dalle risposte

## Contesto

Prova del 20/11 (86 domande, giudice alla cieca, `.local/chat_eval/biblioteca/report.md`): la chat
che risponde **solo** dai testi scaricati è poco utile (0,74 su 2; Quokka oggi 1,56; Haiku a
memoria 1,73; Sonnet 1,91), perché i testi aperti sono per l'85% studi per ricercatori. Funzionano
invece: le citazioni scritte dal codice (fedeli, 1,89), le leggi e le guide ufficiali per
proprietari, la brevità. I modelli a memoria sono utili ma sbagliano dove una fonte li
correggerebbe (museruola).

Decisioni del proprietario (17-20/11) che questo piano raccoglie:
- la chat risponde in modo naturale e utile; ciò che è verificabile viene verificato e segnato
  (asterisco e riferimento breve), e l'utente sa sempre cosa è verificato;
- niente schede scritte a mano; niente revisione veterinaria; niente studi su farmaci e chirurgia;
- **elenco bianco di fonti** da consultare, ampliato man mano che arrivano le domande;
- le fonti che non si possono scaricare si leggono **solo per rispondere a quella domanda**;
- le risposte accreditate **popolano la nostra biblioteca**, scritta per il modello e non per
  l'uomo (compatta), ordinata per non ripetersi, con sostituzione quando arriva di meglio;
- così nel tempo le risposte diventano più veloci mantenendo la qualità;
- un indice di verifica della risposta, da provare.

## Come funziona una risposta

1. **Capire la domanda**: specie, tema, se c'è pericolo, quali fatti servono.
2. **Guardare nella biblioteca** (la casella specie × tema) con una **prova di sufficienza**: per
   ognuno dei 2-4 fatti che servono a questa domanda deve esserci una nota accreditata, non scaduta
   e con punteggio buono (legge, guida ufficiale, oppure almeno due fonti d'accordo). Se è così:
   si risponde subito dalla biblioteca. Veloce e quasi gratis.
3. **Se manca un fatto, o la nota c'è ma è debole o scaduta**: lettura su richiesta delle fonti
   dell'elenco bianco, solo per quei fatti (link diretto se lo conosciamo, altrimenti ricerca
   limitata ai siti dell'elenco). Non conta «la biblioteca ha qualcosa», conta «ha abbastanza e di
   buona qualità».
   **La ricerca si fa subito, mentre l'utente aspetta** (decisione del proprietario, 20/11): la
   chat mostra un messaggio breve con un'animazione di testo, sul modello «Sto cercando la risposta
   più affidabile per questo caso…» (parole esatte alla Normativa, senza promesse), e intanto legge
   le fonti che renderebbero verde la risposta. Le prime risposte su un tema sono più lente; le
   successive trovano le note e sono veloci e meno care.
   - Tempo massimo di attesa: **20 secondi** (decisione del proprietario, 20/11): se scade, la
     chat risponde con ciò che ha, segnato in giallo, e la casella va nella coda notturna.
   - **Nessuna corsia per le urgenze** (decisione del proprietario, 17/11 e ribadita il 20/11):
     Quokka non gestisce le urgenze. Una domanda su un caso grave segue lo stesso percorso di tutte
     le altre, con la stessa attesa; che la situazione è urgente lo dice la risposta, perché lo
     dicono le fonti. Nessun avviso anticipato, nessun primo messaggio separato, nessun passo
     d'urgenza scritto da noi.
   - Tecnica: la risposta in due tempi (prima «sto cercando», poi il testo) richiede una piccola
     modifica a server e app (oggi la chat risponde in un colpo solo): entra con la build che porta
     asterischi e indice.
4. **Quokka scrive** la risposta: naturale, entro 180 parole, con i paletti di sicurezza. Leggi e
   guide ufficiali comandano; il resto viene dalle conoscenze del modello.
5. **Verifica**: ogni fatto controllabile è confrontato con note e passi letti. Sostenuto →
   asterisco e riferimento breve scritto dal codice (mai ripetuto nella chat). Contraddetto da una
   legge o guida ufficiale → frase riscritta dalla fonte. Niente → resta senza asterisco. Il
   controllore non toglie frasi.
6. **Imparare**: i fatti verificati in questa risposta diventano note di biblioteca (vedi sotto).
7. **Indice di verifica** e riga di trasparenza.

## La biblioteca: note compatte, scritte per il modello

- **Griglia** di circa 12 gruppi di specie × 12 temi di pronto uso (alimentazione, ambiente, cura
  quotidiana, comportamento e convivenza, prevenzione, segni per cui andare dal veterinario, cose
  tossiche, cuccioli e anziani, riproduzione, viaggi, doveri e leggi, fine vita). Le specie rare
  usano il loro gruppo.
- **Una nota = un fatto**, in forma compatta: specie, tema, affermazione, condizioni in cui vale,
  fonte o fonti (ente o autori, anno, link, livello), data di verifica, punteggio, scadenza.
  Nessuna frase copiata dalla fonte; **nessun dato dell'utente** (mai nomi, casi personali, testo
  della domanda).
- **Entra solo ciò che è accreditato**: il fatto deve essere stato trovato in un passo di una
  fonte dell'elenco bianco e confermato dal controllo. Le frasi «a memoria» del modello non
  entrano mai: è la difesa contro l'errore che si ripete.
- **Testi interi** solo per le fonti che si possono conservare (leggi, enti pubblici e articoli
  con licenza aperta). Per le altre: solo la nota e il link.

### Niente ripetizioni e sostituzione del meglio («come si fa»)

Prima di salvare una nota si cercano le note simili nella stessa casella:
- stesso fatto, altra fonte → non si duplica: si aggiunge la fonte e il punteggio sale;
- fatto nuovo → nuova nota;
- fatto in contrasto → vince il **punteggio**, calcolato dal codice: (1) livello della fonte:
  legge, poi guida ufficiale, poi società scientifica, poi rassegna, poi studio singolo; (2) numero
  di fonti indipendenti d'accordo; (3) fonte scritta per proprietari; (4) anno più recente;
  (5) indice di citazione della rivista come ultimo spareggio. A parità di livello e in disaccordo:
  restano entrambe, segnate «fonti discordi», e la chat lo dice.
- La nota superata non si cancella: resta archiviata con la data (si può sempre tornare indietro).
- Scadenza a **6 mesi** (decisione del proprietario, 20/11; leggi: controllo della vigenza); una
  nota scaduta va riletta alla fonte.
- Controllo a campione ogni settimana con il giudice indipendente; il «non mi è stata utile»
  dell'utente abbassa la priorità di una nota e la manda a ricontrollo.

### Miglioramento continuo (perché la prima risposta non resti per sempre)

Il rischio di «prima la biblioteca» è che una nota mediocre, una volta salvata, impedisca di
cercare di meglio. Cinque rimedi, tutti fuori dal tempo di risposta dell'utente tranne il primo:
1. **Prova di sufficienza** a ogni domanda (sopra): una nota debole non basta a fermare la ricerca.
2. **Coda notturna**, solo per ciò che la ricerca fatta subito non ha risolto (tempo scaduto, sito
   non raggiungibile, nessuna fonte migliore trovata): di notte il bibliotecario riprova e, se
   trova di meglio, sostituisce.
3. **Fonte nuova nell'elenco**: tutte le note delle caselle che quella fonte copre vengono
   ricontrollate contro di essa.
4. **Campione di controllo**: per una piccola quota delle domande servite dalla biblioteca (per
   esempio 1 su 20) si rifà comunque la lettura dalle fonti, di notte, e si confronta: se il
   risultato ha punteggio più alto, sostituisce.
5. **Segnale dell'utente**: «non mi è stata utile» o «quale fonte?» forzano una lettura nuova.
Tetto di spesa giornaliero per le letture notturne; contatori: note migliorate per settimana e
quota di risposte verdi, che deve salire.

### L'elenco bianco delle fonti

- Un file unico: sito o documento, livello, scritto per chi, specie e temi coperti, **si può
  conservare il testo? sì/no**, raggiungibile dallo strumento sì/no, data del controllo.
- Si amplia dalle domande: ogni domanda senza fonte viene contata (solo specie + tema); ogni
  settimana si propongono nuove fonti per le caselle più chieste. Una fonte entra solo con la regola
  di ammissione (`docs/product/21_biblioteca_regole_di_ammissione.md`) e il parere della Normativa
  sul sito: mai in automatico dal web aperto.

### Partire già pieni

Prima del lancio le circa mille domande già raccolte (forum, giri di prova, test) vengono passate
nel sistema fuori dall'app: la biblioteca nasce già con le note sulle domande più comuni. Stima:
qualche ora di macchina e circa 20 USD.

## Indice di verifica (da provare)

Calcolato dal codice dalle note usate, non dichiarato dal modello. Tre livelli con colore, icona e
parola (mai solo colore, niente testo colorato, niente rosso): verde «Verificata su fonti
ufficiali», giallo «In parte verificata», grigio «Conoscenze generali dell'IA». Si chiama
«verifica delle fonti», non «affidabilità». L'indice vale per tutte le risposte, anche
quando il caso è grave: non c'è un trattamento a parte.
**Cancello**: le risposte verdi devono risultare più corrette delle grigie per il giudice alla
cieca; altrimenti l'indice non entra nell'app.

## Stime (da misurare)

| | Domanda già in biblioteca | Domanda nuova (lettura su richiesta) |
|---|---|---|
| Tempo in più | 1-3 secondi | 5-15 secondi |
| Costo per risposta | circa 0,5 centesimi di dollaro | 1,5-2,5 con ricerca; 0,5-1 con link diretto |

Ricerca web di Anthropic: 10 USD ogni 1000 ricerche (listino). La quota di domande «nuove» scende
man mano che la biblioteca si riempie: è il numero da seguire. Spazio: 172 testi interi = 6,9 MB;
le note sono molto più piccole (stima: 10.000 note in pochi MB). La biblioteca resta un archivio di
sola lettura separato dalle tabelle degli utenti: nessun effetto sulla loro esperienza.

## Rischi e come si tengono sotto controllo

- **Diritti**: non conservare il testo abbassa il rischio, ma accumulare nel tempo molte note
  prese dallo stesso sito riservato può valere, sommato, come copiarlo; e alcuni siti vietano
  l'uso automatico o commerciale (MSD chiede un permesso). Parere della Normativa sito per sito
  prima di metterlo nell'elenco; eventuale tetto di note per sito; permessi dove servono.
- **Siti non raggiungibili**: molti bloccano i programmi delle IA. Prova tecnica prima di contarci.
- **Errore che si ripete**: entra solo ciò che ha una fonte; punteggio, scadenza, campione
  settimanale, archivio delle note superate.
- **Privacy**: nessun dato dell'utente nelle note né nelle ricerche; riga nell'inventario dei
  fornitori; contatore delle domande senza fonte solo per specie e tema.
- **Dipendenza**: la lettura dal web funziona solo con Anthropic; con la riserva valgono le note
  già in biblioteca.
- **Calendario** (lancio 10-20 dicembre): se i cancelli non passano in tempo si lancia con la chat
  di oggi ripulita e il resto si accende dopo.

## Passi

1. **Controlli preliminari** (1-2 giorni): prova tecnica sui 20 siti più utili (raggiungibili?
   tempo? costo? la sola lettura ha una tariffa?) e parere della Normativa sugli stessi siti e
   sull'accumulo di note.
2. **Lavoro A, chat più utile** (in corso, sessione Chat LLM interna): via il testo fisso a parole
   chiave, pericolo deciso dalle regole, comportamento pericoloso verso persone e altri animali.
   File: `packages/core/application/services/chat_orchestrator.py`, `natural_answer_prompt.py`,
   `safety_gate.py`, `packages/core/domain/safety/`.
3. **Lavoro B, verifica + note** nello strumento di prova: riuso di
   `scripts/eval/chat_quality/library_chat.py` (ricerca, citazioni dal codice); nuovo: formato
   delle note, regola di punteggio, ricerca dei simili, lettura su richiesta.
4. **Lavoro C, elenco bianco e griglia** (sessione Manuale, licenze alla Normativa): file
   dell'elenco, assegnazione delle mille domande alle caselle, testi interi solo dove ammesso.
5. **Prova 2** sulle stesse 86 domande, stesso giudice alla cieca. Bracci: Quokka oggi, Quokka A,
   Quokka A + verifica dalla biblioteca, Quokka A + verifica + lettura su richiesta, Haiku a
   memoria. In più: stesso giro ripetuto due volte, per vedere che al secondo passaggio le risposte
   usano le note e sono più veloci senza peggiorare.
   **Cancelli**: utilità almeno 1,73; urgenze e sicurezza non sotto oggi; inventate sopra 1,70;
   tutte le domande di legge giuste; al massimo 3 falsi allarmi su 57; asterischi fedeli almeno
   1,85; zero correzioni sbagliate; entro 180 parole; nessuna nota con dati dell'utente; note
   fedeli alla fonte (campione giudicato); indice verde più corretto del grigio.
6. **Rapporto al proprietario**, poi **tornata corposa con gli utenti di prova** (giro 4, strumento
   in `.local/synthetic_users/giro4/`), poi costruzione nell'app dietro un interruttore, revisione
   delle 5 lingue, pagina «Fonti e licenze», prova umana.

## Verifica

Prova 2: rapporto con tabella, esempi affiancati, conteggi (asterischi, falsi allarmi, correzioni,
note create/unite/sostituite, quota di domande servite dalla biblioteca al secondo passaggio, tempo
e costo). Costruzione: `uv run pytest`, `ruff`, `mypy`; controllo automatico sulle trascrizioni del
giro 4 (apertura urgente quando serve, nessuna dose o terapia, nessun sintomo inventato, citazioni
complete e non ripetute, ogni fonte citata nell'elenco bianco).
