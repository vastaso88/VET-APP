# Prestazioni: galleria, passeggiate, badge, calendario (16/11/2026)

Segnalazione del proprietario sulla build 38: galleria di Thor, vecchie passeggiate,
badge e calendario della Home "caricano, ma ci perde una vita".

## In breve

La distanza dal server **non** è la causa. Le attese venivano dal telefono, che scaricava
troppo e male. Le correzioni sono tutte nel codice di caricamento dell'app Flutter; il
backend e il database non sono cambiati e non serve nessun SQL.

## Cosa ho misurato (senza account reali, senza toccare la produzione)

- Richiesta anonima a `/health` della produzione, 4 prove da questo PC in Italia:
  collegamento sicuro 0,10-0,28 s, risposta completa 0,19-0,41 s (tipico 0,2 s).
  Il percorso è punto d'ingresso Vercel a Francoforte e funzione a Dublino (`fra1` → `dub1`):
  la distanza dal server vale circa un quinto di secondo a richiesta, non decine di secondi.
- Galleria, passeggiate, badge, promemoria e animali **non passano dal backend Vercel**: il
  telefono parla direttamente con Supabase (Irlanda). Il backend Vercel serve a chat, notizie,
  abbonamento e poco altro. Quindi la regione di Vercel non c'entra con queste sezioni.
- Indici e regole del database controllati nello script `supabase_schema.sql`: `dog_walks`
  ha l'indice su `owner_id` e su `pet_id`, `pet_photos` su `(pet_id, created_at)`; le
  regole dei piani (`plan_access_rules.sql`) toccano solo le scritture, non le letture.
  Il database non è il collo di bottiglia.

Non ho potuto misurare tempi sul telefono: servirebbero un account reale e la produzione,
vietati. I numeri "dopo" qui sotto sono quindi **stime dalle dimensioni dei dati**, non
cronometri. Da verificare con la prossima build sul telefono del proprietario.

## Cause trovate

1. **Le miniature erano foto intere.** Ogni quadratino della galleria, ogni avatar e ogni
   copertina di cartella scaricava la foto a 1600 px (300-500 KB) per mostrarla a circa
   100 px. Una galleria di 40 foto sono 12-20 MB al primo giro. La cache su disco del
   7 ottobre c'è in `main` e funziona, ma aiuta solo dal secondo giro in poi, e sparisce a
   ogni disinstallazione, cambio di identificativo dell'app o uscita dall'account.
2. **Troppi scaricamenti insieme, e doppioni.** Tutti i quadratini di un giorno partivano
   nello stesso istante (30 scaricamenti paralleli che si rubano la banda: il primo
   quadratino arrivava lento quanto l'ultimo), e la stessa foto chiesta da avatar,
   griglia e copertina partiva due o tre volte.
3. **Memoria senza limite.** La cache in memoria teneva ogni foto a piena risoluzione mai
   mostrata, per tutta la sessione: più foto, più il telefono rallentava.
4. **Passeggiate richieste tre volte, con i percorsi GPS.** All'apertura della scheda
   dell'animale lo storico, le didascalie della galleria e il grafico del Monitoraggio
   chiedevano ciascuno tutte le passeggiate di tutti gli animali, percorso GPS compreso, anche
   quando serviva solo la data. Il bottone Badge poi aspetta quel caricamento.
5. **Monitoraggio a richieste in fila.** Pesi, passeggiate, curve di crescita e taglia
   partivano una dopo l'altra: tempo = somma, non il più lento.
6. **Calendario della Home fermo sullo scheletro.** I promemoria sono salvati sul telefono
   dall'ultima volta e caricati subito, ma `loadReminders()` aspettava comunque la risposta di
   Supabase (fino a 12 s) prima di mostrarli. Il calendario restava vuoto finché la rete non
   rispondeva, anche con i dati già in mano.

## Cosa ho cambiato

| Dove | Cambiamento |
|---|---|
| `pet_photo_repository.dart` | `loadThumbnail`: miniatura 512 px (circa 30 KB) da memoria, disco, oggetto `_t.jpg` in Storage, oppure ricavata dalla foto e salvata; le foto nuove salvano subito anche la miniatura |
| `pet_photo_repository.dart` | per le foto vecchie la miniatura viene creata una volta sul telefono e offerta a Storage (in silenzio, senza paywall): da lì in poi anche un altro telefono scarica 30 KB invece di 400 |
| `pet_photo_fetch_queue.dart` (nuovo) | massimo 6 scaricamenti insieme, uno solo per foto, prima le foto richieste per ultime (quelle ora a schermo); cache in memoria a capienza limitata |
| `pet_photo_repository.dart` | cancellazione foto e cartella dell'animale tolgono anche le miniature; l'elenco dei file ora è paginato (prima si fermava a 100) |
| griglia, avatar, copertine cartelle | usano `loadThumbnail`; il visore a schermo intero continua a usare la foto intera |
| `dog_walks_repository.dart` | `loadWalkSummaries` (senza percorso GPS) per galleria e Monitoraggio; una sola richiesta condivisa se più schermate chiedono insieme, svuotata a ogni scrittura per non servire dati vecchi |
| `monitoring_tab.dart` | le quattro richieste partono insieme |
| `reminders_repository.dart` | se la copia salvata sul telefono è già caricata per questo utente, il calendario la mostra subito e si aggiorna dietro |

Nessun permesso Android nuovo, nessuna tabella o colonna nuova, nessuna build APK.
Le miniature sono oggetti dello stesso bucket privato `pet-photos`, nella stessa cartella
`<utente>/<animale>/`: non hanno una riga in `pet_photos`, quindi limiti, conteggi ed
esportazione non le vedono, e la cancellazione dell'account (che svuota la cartella) le
elimina insieme alle foto.

## Tempi prima e dopo (stime dalle dimensioni, vedi sopra)

| Scenario (4G, circa 20 Mbit/s reali) | Prima | Dopo |
|---|---|---|
| Galleria di 40 foto, primo giro, foto vecchie | 12-20 MB, circa 6-10 s | stesso scaricamento una sola volta (si crea la miniatura), poi 1,5 MB |
| Galleria di 40 foto, primo giro, foto nuove o già "convertite" | 12-20 MB | circa 1,2 MB (40 × 30 KB), sotto 1 s di dati |
| Galleria, secondo giro | disco, istantanea | disco, istantanea (miniature: meno memoria) |
| Scheda Passeggiate / Badge | 1-3 richieste complete con percorsi | 1 richiesta condivisa |
| Calendario Home all'avvio | attende Supabase | mostra subito la copia salvata |

Le foto già nella galleria del proprietario hanno quindi un solo primo giro "lento" (come
oggi); da quel momento, e su ogni altro telefono, sono leggere.

## E un utente in un altro continente?

Oggi il database (Supabase) è in Irlanda e il backend (Vercel) a Dublino: tutto in Europa.
Distanze tipiche di andata e ritorno verso Dublino (ordini di grandezza, non misure mie):
Stati Uniti costa est circa 80-100 ms, costa ovest 150-170 ms, Brasile 200-220 ms,
Singapore 170-200 ms, Australia 280-320 ms. Ogni nuova connessione sicura costa 2-3 di
questi viaggi prima del primo dato.

Cosa succede, in ordine di peso:

1. **Le foto sono il problema, non le richieste piccole.** Una richiesta da 5 KB in Australia
   costa circa 1 s la prima volta e poi 0,3 s; una foto da 400 KB su un collegamento lento a
   lunga distanza costa molti secondi. Le miniature (30 KB) e la cache sul telefono, fatte
   ora, tagliano la quantità di dati di circa 12 volte e sono la risposta più efficace per
   chiunque sia lontano. **Costo: già fatto. Impatto sul GDPR: nessuno.**
2. **Cache sul telefono**: dopo il primo giro i dati sono locali. Promemoria e animali
   sono già salvati sul telefono; la galleria lo è. Resta da estendere, se serve, a
   passeggiate e pesi (oggi sempre riletti all'apertura). Sono poche migliaia di byte, non un
   problema nemmeno a 300 ms.
3. **CDN per le foto.** Una rete di distribuzione porta i file vicino all'utente. Il bucket
   è privato e le foto si scaricano con la sessione dell'utente: perché una CDN le tenga in
   copia servirebbero indirizzi firmati con scadenza e intestazioni di cache lunghe (le foto
   non cambiano mai: ogni foto nuova ha un nome nuovo). Non l'ho attivato: serve verificare
   con Supabase cosa mette già in cache sul suo bordo per i bucket privati, e va valutato
   il lato GDPR (vedi sotto). Con le miniature il guadagno aggiuntivo è modesto: conviene
   rifare la misura dopo che gli utenti lontani esistono davvero.
4. **Repliche del database in altri continenti.** Supabase offre repliche in lettura nei
   piani a pagamento superiori, per regione, e non replica i file dello Storage. Costa
   molto più dell'attuale, aggiunge complessità (una scrittura va comunque in Irlanda) e,
   soprattutto, porta dati personali fuori dall'UE. Oggi non è giustificato.
5. **Funzioni Vercel in più regioni**: con il database in un solo posto, una funzione a
   Singapore che parla con Dublino per ogni richiesta peggiora le cose. Non farlo finché il
   database non è distribuito.

**GDPR.** Tenere tutto in UE è un vantaggio da non buttare: nessun trasferimento extra-UE
da giustificare, il registro fornitori (`docs/security/06_inventario_dati_fornitori.md`) resta
com'è. Una CDN con punti di presenza fuori dall'UE o una replica in un altro continente
sono trasferimenti: richiedono una riga nuova nell'inventario, accordo con il fornitore (DPA e
clausole contrattuali standard) e un aggiornamento dell'informativa, prima del rilascio.
Le foto di animali possono contenere persone sullo sfondo: vanno trattate come dato personale.

**Raccomandazione.** Restare in Europa. Le miniature e la cache sul telefono, già fatte,
bastano per essere usabili ovunque. Rivalutare CDN (solo con provider in UE o con le
garanzie sopra) quando ci sono utenti reali fuori Europa e una misura dei loro tempi; le
repliche solo se la lettura dei dati strutturati diventa il collo di bottiglia, cosa che
con il volume atteso non si vede.

## Da sapere, non ancora fatto

- Il visore a schermo intero scarica ancora la foto intera (giusto: serve nitidezza). Si
  potrebbe mostrare subito la miniatura mentre arriva la foto grande.
- Le miniature delle foto vecchie nascono quando qualcuno apre la galleria: nessuno
  script le crea in blocco. Se serve uniformare, si può fare uno script una tantum con la
  chiave del backend (azione dell'amministratore, non automatica).
- Il disco-cache viene svuotato a ogni uscita dall'account (voluto, per privacy) e a ogni
  disinstallazione: il primo giro dopo il cambio di identificativo dell'app
  (`net.quokkapet.app`) sarà "freddo" per tutti.
- La Home non è stata toccata. Il calendario mostrava lo scheletro anche per un altro motivo
  di disegno (`FutureBuilder` ricreato a ogni cambiamento dei promemoria): lo segnalo a
  "UI/UX e funzionalità base", non l'ho cambiato.
