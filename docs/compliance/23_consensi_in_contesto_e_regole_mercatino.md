# Consensi in contesto: interruttori nell'app e accettazione delle regole del Mercatino

Data: 2026-11-21. Parere breve richiesto dall'Orchestratore su una proposta della UI/UX (richiesta del proprietario: consensi all'inizio di ogni attività e spunte «in giro» per cambiarli, non solo in Impostazioni). Non è consulenza legale; i punti ⚖️ vanno a un legale.

## 1. La proposta della UI/UX

- Interruttori **solo per i consensi veri**, con la stessa chiave di Impostazioni (mai due stati diversi), «Attiva» e «Non ora» di pari peso al primo uso: (a) Chat: nel menu della conversazione e nella schermata vuota, «L'assistente può leggere la cartella clinica di {animale}»; (b) Cartella clinica e referti: lo stesso interruttore accanto all'avviso nella pagina di caricamento e in cima alla scheda referti; (c) Profilo: «Novità via e-mail» (solo maggiorenni) e «Rapporti sugli errori» (solo nelle build che li inviano), in un gruppo «Privacy»; (d) Impostazioni: elenco raggruppato per attività.
- **Nessun interruttore** per Mercatino, passeggiate, radar e posizione (base contrattuale; la posizione è un permesso del telefono).
- Mercatino, al primo accesso: casella «Ho letto le regole» (accettazione, non consenso).

## 2. Parere: va bene, con cinque correzioni

1. **Attivare vuol dire informare** (artt. 7, par. 2, e 13 GDPR). Ogni «Attiva» fuori da Impostazioni mostra prima le due o tre righe essenziali (che cosa, a chi vanno i dati, cioè al fornitore di IA, e come si revoca) con «Leggi come viene usata»; il consenso si salva solo dopo «Attiva», con la **versione del testo mostrato**. L'interruttore con la sola etichetta non basta. **Spegnere**: un tocco, subito, senza conferme che ostacolino (art. 7, par. 3: revocare è facile come dare).
2. **«Non ora» senza pressione.** Il pari peso è giusto, ma dopo «Non ora» l'app non rifà la richiesta da sola a ogni apertura: l'interruttore resta disponibile e al massimo c'è una proposta quando l'utente chiede qualcosa che richiede la cartella (una volta per sessione). Richieste ripetute sono pressione e il consenso non sarebbe libero (considerando 42; linee guida EDPB sui modelli ingannevoli). L'app e la chat funzionano **anche senza**.
3. **Stesse parole ovunque**, quelle di Impostazioni, e stessa versione: «Consenti all'assistente di leggere la cartella clinica di {animale}», «Invia rapporti sugli errori», «Email di marketing». **«Novità via e-mail» no**: non dice che è pubblicità; per l'e-mail commerciale serve un consenso specifico (art. 130 Codice privacy): «Email di marketing: novità e offerte di Quokka». Solo maggiorenni (confermato), mai pre-attivata, link di revoca in ogni e-mail. Se la build raccoglie le statistiche, anche «Analisi d'uso» nello stesso gruppo. Dopo un cambio di versione del testo: «Da confermare» ovunque e la funzione resta spenta finché non si riconferma.
4. **Niente interruttori per Mercatino, passeggiate, radar e posizione: giusto.** La base è il contratto o il permesso del telefono; un finto «consenso» sarebbe fuorviante (se la base non è il consenso, non lo si chiede). Al primo uso, al massimo una **nota informativa** («che cosa fa, quali dati usa») con un solo pulsante «Ho capito», che non è una spunta né un consenso. La schermata prima del permesso di sistema per la posizione resta com'è.
5. **Mercatino: «Ho letto le regole» non basta**, perché non accetta nulla. Testo: «Ho letto e accetto le regole del Mercatino», con collegamento alle regole, casella **non pre-spuntata**, versione e data registrate (come per le regole dei contributi). Va dichiarata come **accettazione** (condizione del servizio), mai come «consenso». Le regole devono dire: niente animali; i messaggi sono tra maggiorenni; **il nostro team può leggere una conversazione se una delle due persone la segnala** (art. 15 Costituzione; art. 616 c.p. ⚖️). L'avviso fisso in testa alla conversazione non c'è ancora (registro 08, punto 41): va aggiunto.

## 3. Che cosa è un interruttore e che cosa no

| Che cosa | Natura | Come si presenta |
|---|---|---|
| Termini e Informativa privacy | accettazione obbligatoria | schermata «Prima di continuare» |
| «Quokka non gestisce le urgenze» ([22](22_clausola_quokka_non_gestisce_urgenze.md)) | riconoscimento obbligatorio | schermata una volta per versione, **non un interruttore** |
| Regole del Mercatino | accettazione del servizio | casella al primo accesso |
| Lettura della cartella clinica da parte dell'assistente (per animale) | **consenso**, facoltativo | interruttore, con le regole dei punti 1 e 2 |
| Email di marketing; rapporti sugli errori; analisi d'uso | **consensi**, facoltativi | interruttori nel gruppo «Privacy» |
| Posizione, notifiche, fotocamera e simili | permesso del sistema | richiesta del sistema, preceduta da una nota informativa |

## 4. Aperti

1. ⚖️ Se la casella «Ho letto e accetto le regole del Mercatino», con la riga sulla lettura delle conversazioni segnalate, basta come accettazione specifica di quella clausola (art. 1341, c. 2, c.c. ⚖️ 24; [22](22_clausola_quokka_non_gestisce_urgenze.md) §3).
2. Testo completo delle regole del Mercatino con la riga sul team e avviso fisso in testa alla conversazione: UI/UX e Normativa (registro 08, punto 41).
3. Il testo del consenso sulla cartella clinica (v4, [03](03_consenso_cartella_clinica.md)) resta quello che si mostra prima di «Attiva»: va solo accorciato in due o tre righe più il collegamento al testo intero.
