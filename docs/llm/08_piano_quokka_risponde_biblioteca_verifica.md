# Piano approvato il 20/11/2026: Quokka risponde, la biblioteca verifica e cita (sostituisce il doc 07)

## Contesto

La prova del 20/11 (86 domande, giudice alla cieca, rapporto in
`.local/chat_eval/biblioteca/report.md`) ha bocciato la chat che risponde **solo** dai testi della
biblioteca:

| | Solo biblioteca | Quokka oggi | Haiku a memoria | Sonnet a memoria |
|---|---|---|---|---|
| Scelta come migliore | 0 | 36 | 17 | 33 |
| Utilità (0-2) | 0,74 | 1,56 | 1,73 | 1,91 |
| Niente di inventato (2 = perfetto) | 1,49 | 1,70 | 1,62 | 1,71 |

Cosa abbiamo imparato dalle due prove:
- **I testi aperti sono per l'85% studi per ricercatori**: veri, ma non rispondono a «cosa faccio
  adesso?». Una chat obbligata a usare solo quelli è poco utile e a volte fuorviante.
- **I modelli a memoria sono utili ma sbagliano proprio dove una fonte li correggerebbe**: sulla
  museruola Haiku sbaglia, la biblioteca no. Sulle leggi la biblioteca è la migliore.
- **Le fonti più utili sono le guide ufficiali per proprietari** (enti pubblici), non gli studi.
- **Quokka di oggi** vince urgenze e brevità; perde utilità per colpa del testo fisso a parole chiave.
- Le citazioni scritte dal codice sono fedeli (1,89 su 2): quel pezzo funziona.

Conseguenza onesta: con i soli testi che abbiamo il diritto di usare, «rispondere solo da fonti
validate» e «essere utile» non stanno insieme. Il piano tiene l'utilità e aggiunge la verifica:
**la chat risponde bene, tutto ciò che si può verificare viene verificato e segnato, e l'utente sa
sempre cosa è verificato e cosa no.** È l'iter 1 proposto dal proprietario il 17/11.

## Come funziona una risposta

1. **Quokka risponde**: modello + paletti di sicurezza, breve (entro 180 parole). Se in biblioteca
   c'è una **fonte ufficiale** sul tema (legge, guida di un ente pubblico), la legge prima di
   scrivere e la segue.
2. **Verifica**: ogni frase con un fatto controllabile (obblighi, numeri, «è tossico», «è
   un'urgenza») viene confrontata con la biblioteca.
   - Un testo la sostiene → **asterisco** e in fondo il riferimento breve («Autore, AAAA» / «MS,
     ordinanza 6/8/2013»), scritto dal codice, mai ripetuto nella stessa chat.
   - Una **legge o guida ufficiale** la contraddice → la frase viene riscritta dalla fonte, con
     asterisco. Solo queste fonti possono correggere; gli studi scientifici possono solo confermare
     (un singolo studio non basta per dare torto al modello: è l'errore visto nella prova).
   - Nessun testo → la frase resta, senza asterisco.
3. **Una riga chiara, una volta per chat**: le frasi con asterisco sono verificate su una fonte, il
   resto viene dalle conoscenze generali dell'IA e può sbagliare (testo esatto alla Normativa).

Sparisce l'«offerta» di risposta a memoria con i due pulsanti: non serve più, perché la chat
risponde comunque e dichiara cosa è verificato.

## I tre lavori

**A. Chat più utile** (sessione Chat LLM interna)
- Togliere o ridurre a regola nel prompt il testo fisso che scatta per parole chiave, secondo
  l'inventario del confronto (`.local/chat_eval/confronto_nudo/report.md` §5): via le domande di
  chiarimento fisse e le aperture fisse; restano i paletti (mai dosi, autolesionismo, ferita a una
  persona, richieste dannose, «sono un'IA»).
- Pericolo deciso soprattutto dalle **regole** già in produzione (2 falsi allarmi contro i 13 del
  «lettore» della prova); correggere i falsi allarmi noti (un fatto passato, come «anni fa ha avuto
  un incidente», non è un'urgenza).
- Comportamento pericoloso verso persone **e altri animali**: sicurezza subito (separare, non
  lasciare soli), specialista con criterio chiaro.
- File: `packages/core/application/services/chat_orchestrator.py`, `natural_answer_prompt.py`,
  `safety_gate.py`, `packages/core/domain/safety/` (`triage_clarification.py`,
  `harmful_requests.py`), `packages/core/domain/localization.py`.

**B. Verifica e citazioni** (sessione Chat LLM interna)
- Riuso del prototipo `scripts/eval/chat_quality/library_chat.py`: ricerca nei testi, scelta dei
  passi, citazioni scritte dal codice, regole della Normativa (docs/compliance/20).
- Controllore ristretto: guarda solo le frasi con fatti controllabili; può aggiungere un asterisco
  o far correggere da fonte ufficiale; non toglie più frasi (nella prova il 38% delle frasi tolte
  era giusto).
- Due varianti da misurare: (1) verifica solo dopo la risposta; (2) fonti ufficiali lette prima +
  verifica dopo.

**C. Biblioteca per proprietari** (sessione Manuale, Normativa per le licenze)
- Priorità alle **guide ufficiali per proprietari con licenza aperta**: oltre a Regno Unito e
  Scozia già presenti, altri enti pubblici con licenza libera (da verificare uno per uno: Galles,
  Irlanda del Nord, Australia, Nuova Zelanda, enti dell'Unione europea, enti federali USA i cui
  testi sono di pubblico dominio) e Ministero della Salute italiano (scarico a mano).
- Leggi italiane complete e aggiornate (già avviato).
- Studi scientifici: restano solo come conferma (asterisco); rassegne prima degli studi singoli;
  nessuno studio guida la risposta.
- Regole in `docs/product/21_biblioteca_regole_di_ammissione.md` (nuovo criterio: «scritto per
  chi»).
- Fonti riservate (MSD e società scientifiche): ferme come deciso; la bozza della lettera resta
  pronta. Opzione consigliata ma non necessaria: mandarla alle tre società degli esotici, dove le
  guide aperte sono più scarse.

## Prova 2 (prima di toccare l'app)

Stesse 86 domande, stesso giudice alla cieca, stesso strumento (`prova/prova.py`). Bracci: Quokka
di oggi, Quokka dopo il lavoro A, Quokka A + verifica (due varianti), Haiku a memoria.

**Si costruisce nell'app solo se** la versione A + verifica:
- è utile almeno quanto Haiku a memoria (1,73) e non peggiora urgenze e sicurezza rispetto a oggi;
- inventa meno di oggi (sopra 1,70) e risponde giusto a tutte le domande di legge;
- al massimo 3 falsi allarmi su 57 domande non urgenti;
- asterischi fedeli (almeno 1,85 su 2) e nessuna correzione sbagliata;
- resta entro 180 parole.
Si misura anche: quante frasi hanno l'asterisco (il numero da far crescere nel tempo), tempo, costo.

## Dopo la prova 2

1. Rapporto al proprietario con esempi affiancati e le frasi fisse da approvare.
2. **Tornata corposa con gli utenti di prova** (giro 4, richiesta del proprietario): strumento già
   pronto in `.local/synthetic_users/giro4/`, utenti nuovi con tutte le specie, domande da forum,
   controllo automatico di ogni risposta. Sulla versione che ha passato i cancelli.
3. Costruzione nell'app dietro un interruttore (la chat di oggi resta finché la nuova non la batte),
   revisione delle 5 lingue, biblioteca nel database (SQL lanciato dal proprietario), pagina «Fonti
   e licenze» in una build.
4. Prova umana del proprietario.

## Rischi

- **Una parte delle risposte resterà senza asterisco**, soprattutto sugli esotici: è dichiarato
  all'utente; cresce con le guide ufficiali e con eventuali permessi.
- **Correzione sbagliata**: limitata alle fonti ufficiali e contata nella prova (deve essere zero).
- **Tempo e costo**: una ricerca e un controllo in più per risposta; da misurare.
- **Calendario**: il lancio è previsto per il 10-20 dicembre; se i cancelli non passano in tempo si
  lancia con la chat di oggi ripulita (lavoro A) e la verifica si accende dopo.

## Verifica

Prova 2: rapporto con tabella, esempi, conteggio di asterischi, falsi allarmi e correzioni.
Costruzione: `uv run pytest`, `ruff`, `mypy`; controllo automatico sulle trascrizioni del giro 4
(apertura urgente quando serve, nessuna dose o terapia, nessun sintomo inventato, citazioni complete
e non ripetute, ogni fonte citata presente in biblioteca con licenza ammessa).
