# Punti aperti prima del lancio pubblico

Registro, aggiornato 2026-10-28 (verificati nel codice i punti 25, 27 e 28, ora chiusi; punto 26 ridotto ai moduli di Play; nuovo punto 29: numero di telefono facoltativo). Aggiornamenti precedenti: 2026-10-06 (punti 25–28) e 2026-10-04, dopo il riscontro dell'Orchestratore. Pareri di riferimento: [06](06_radar_mappe_sponsorizzazioni.md) e [07](07_contributi_utenti.md). I numeri restano stabili per i riferimenti nei pareri; le voci chiuse sono state tolte.

**Regola del proprietario:** se non ci sono problemi legali si va avanti. Se ci sono dubbi legali la funzione non va nell'app: si tiene l'opzione per il futuro dietro un flag, oppure si toglie se già presente.

**Decisione attuale dell'utente (2026-10-04): «Procedi con tutto, poi discutiamo sui punti».** Nulla è spento. I dubbi sono elencati sotto, da discutere con l'utente tramite l'Orchestratore.

**Stesso criterio per test e lancio:** il trattamento avviene già durante i test, con dati di tester reali. Cambiano gravità ed esposizione, non la regola.

**Correzione:** una versione precedente di questo registro dava Overture «spenta»: è attiva. Il dubbio riguarda i punti sotto, non l'uso commerciale.

## Stato delle funzioni

| Funzione | Stato | Dubbio aperto |
|---|---|---|
| Radar da OpenStreetMap | Attivo in produzione | Sì: tile e Overpass (punti 1–2) |
| Dati dei Comuni di Milano, Bologna, Torino | Attivi, con attribuzioni applicate | Sì: licenza CC BY 3.0 IT (Milano); avviso di data per Torino (dataset ultimo aggiornamento 2019-06-05) |
| Overture Maps | Attivo: 15.852 luoghi in `radar_places_open`, serviti da `main` 6bbd3bb | Sì, vedi sotto |
| Foursquare | Non confermato come importato | Sì: applicabilità di Apache 2.0 ai dati (diritto sui generis UE) |
| Stelle sulle aree cani pubbliche | Attive | No (rischio basso) |
| Canale di rettifica e opposizione per i titolari | Attivo, con il contatto provvisorio | Sì, punto 9 |
| Segnalazione «luogo chiuso» | Attiva: contata, non visibile; a 5 conferme il luogo sparisce | Sì |
| Segnalazione «luogo mancante» | Attiva | Sì |
| Segnalazione «doppione o posizione errata» | Attiva | Sì (minore) |
| Aree cani mancanti (etichetta «verifica») | Attive | Sì |
| Segnalazioni dalla chat | Attive. Pseudonimo con HMAC e sale (`packages/core/domain/feedback/pseudonym.py`); identità dimenticata 12 mesi dopo la chiusura (`scripts/radar/cleanup_reports.py`) | Sì: il testo passa dal filtro a regole (default in produzione), che non riconosce i nomi di persona senza etichetta (punto 8). Verificare che lo script sia schedulato |
| Consenso alla cartella clinica (chat) | Attivo. Testo v3 dal 2026-10-14 (la v2 del 2026-10-06 aveva corretto la v1, che prometteva troppo). Un consenso dato con una versione precedente non vale più (`effective_decision`); la domanda in chat usa lo stesso testo; il riepilogo passa dal filtro prima di uscire verso il fornitore | No. Resta una scelta del proprietario: limitare ciò che si invia invece di descriverlo (vedi 03) |
| Contributi verso OpenStreetMap | Non implementati | — |

## Dubbi per voce (per la discussione con l'utente)

| Voce | Dubbio preciso | Rischio concreto o da far confermare | Cosa lo scioglie | Test (pochi invitati) / Lancio |
|---|---|---|---|---|
| Informativa privacy completa (artt. 13–14 GDPR) | Il consenso «Privacy» v1 diceva che l'informativa completa era consultabile dalle Impostazioni: non esiste. Dal 2026-10-06 (v2) riassume i trattamenti e dice che è in preparazione. La sintesi in app dice «nome ed email», ma l'account ha anche cognome, telefono e foto profilo facoltativi: serve una v3 (in attesa del via dell'Orchestratore). Già oggi trattiamo dati di tester reali: la sintesi non sostituisce l'informativa art. 13 | Rischio concreto e attuale | Informativa raggiungibile dalle Impostazioni e dalla registrazione prima del primo invito (bozza in [09](09_informativa_privacy_bozza.md), bozze per paese in `<paese>/02_*`); poi nuova versione del testo di consenso | Alta / Alta |
| Consenso alla cartella clinica | La v1 prometteva «solo le informazioni rilevanti, mai l'intera cartella». Corretto: la v2 (2026-10-06) descrive la lettura reale e la v3 (2026-10-14) aggiunge categorie, date e malattie in corso; i consensi dati con una versione precedente non valgono più e la chat li richiede sul testo nuovo | Chiuso nel codice (verificato il 2026-10-28) | Nessuna azione obbligatoria. Eventuale riduzione dei dati inviati: scelta del proprietario, vedi 03 | Bassa / Media |
| Overture Maps | (a) Licenza per record: il campo `sources` può indicare origini con termini diversi dal CDLA-P-2.0. (b) Dati di ditte individuali senza informativa art. 14 né legittimo interesse documentato. Uso commerciale e share-alike: nessun dubbio (parere del 2026-10-03) | (a) da far confermare; (b) rischio concreto | (a) verifica di `sources` e filtro dei record incompatibili; (b) informativa, legittimo interesse documentato, canale di opposizione attivo | Media / Alta |
| Luogo chiuso | Affermazione non verificata su attività identificabili: danno economico immediato se falsa. Cinque conferme possono essere fabbricate, perché email ed età dell'account non sono verificate | Rischio concreto | Email verificata ed età dell'account; conferma di un moderatore prima che il luogo sparisca; contestazione con sospensione durante l'esame | Media / Alta |
| Luogo mancante | Nome di una ditta individuale; posizione di abitazioni di pet sitter ed educatori a domicilio | Concreto per il domicilio; da far confermare per le ditte individuali | Legittimo interesse documentato; per le categorie a domicilio, posizione approssimata (non l'indirizzo esatto) | Bassa-media / Media-alta |
| Doppione o posizione errata | Posizione errata usata per danneggiare un concorrente (concorrenza sleale) | Da far confermare | Canale di contestazione; conferme multiple (già presenti) | Bassa / Media |
| Aree cani mancanti | Area privata confermata come pubblica: invasione di terreni (art. 637 c.p.), abitazioni identificabili | Concreto per l'area privata; da far confermare la responsabilità | Confronto con il dataset comunale; rimozione immediata alla richiesta; parere legale | Bassa / Media-alta |
| Motivazione delle rimozioni (art. 17 DSA) | Obbligo verso chi ha segnalato, ora che le segnalazioni sono attive | Da far confermare (⚖️) | Motivazione già scritta da `scripts/radar/remove_reported_place.py` in `radar_place_overrides.reason`; collegamento alla segnalazione e «le mie segnalazioni» (punto 22) | Bassa / Media |
| Badge «Più scelto» sul piano Pro | Affermazione non verificata: pratica commerciale potenzialmente ingannevole (artt. 21–22 cod. cons.) se non riflette un dato reale | Concreto se la scelta non è documentata; oggi nessun pagamento reale | Toglierlo o sostituirlo con una formula verificabile. Instradato dall'Orchestratore | Bassa / Media |
| «5 giorni lavorativi» nelle regole | Promessa di tempi non presidiata | Basso: è un testo | Processo presidiato, oppure testo senza tempi (punto 21) | Bassa / Media |
| Numero di telefono facoltativo | Nessuna funzione lo usa: dubbio di minimizzazione e limitazione della finalità (art. 5(1)(b)–(c) GDPR) | Basso: facoltativo, modificabile, cancellato con l'account e dichiarato nelle informative | Usarlo per qualcosa (verifica o recupero dell'account) oppure togliere il campo | Bassa / Media |

## Punti da chiudere

| # | Punto | Perché | Chi decide | Quando va deciso |
|---|---|---|---|---|
| 1 | Fornitore di tile commerciale o self-hosting (radar e passeggiate) | Oggi i tile OpenStreetMap sono richiesti direttamente. Policy d'uso: niente uso intensivo o come servizio primario | Proprietario (budget) | Prima del lancio pubblico |
| 2 | Istanza Overpass propria o estratto OSM dell'Italia | Overpass pubblico condiviso: risposte 429/504 e policy d'uso | Proprietario e Mappe interattive | Prima dell'aumento di utenti |
| 3 | User-Agent di produzione con contatto tecnico (`OVERPASS_USER_AGENT`) | Il default in `settings.py` ha solo l'URL del sito; la policy Overpass chiede un contatto reale | Mappe interattive | Prima del deploy di produzione |
| 4 | Monetizzazione delle schede delle cliniche | Vincoli FNOVI, codice del consumo, DSA; mai nelle urgenze | Proprietario e legale | Prima del primo pagamento di una struttura |
| 5 | Revisione legale dei punti ⚖️ dei pareri 06 e 07 | Soglie DSA, FNOVI, Omnibus, artt. 96–97 L. 633/1941, art. 637 c.p., legittimo interesse, licenze | Proprietario (sceglie il legale) | Prima del lancio pubblico |
| 6 | Informativa privacy completa (artt. 13–14 GDPR), raggiungibile dalle Impostazioni e dalla registrazione | Vedi la tabella dei dubbi; bozza in [09](09_informativa_privacy_bozza.md). Alla pubblicazione, il testo di consenso «Privacy» (oggi v2, «in preparazione») passa a v3 | Proprietario e legale | **Prima del primo tester invitato** |
| 7 | Termini di servizio completi | Oggi c'è solo la clausola di accettazione (v1), che non elenca le regole; regole della piattaforma (DSA, art. 14) | Proprietario e legale | Prima del lancio pubblico |
| 8 | Anonimizzazione: limiti del filtro a regole | Il filtro a regole è il default in produzione (`noop` viene sostituito): toglie email, telefoni, codice fiscale, partita IVA, IBAN, URL, indirizzi con civico, nomi con etichetta o noti dall'account. Non riconosce i nomi di persona senza etichetta, né immagini e audio ([02](02_pii_anonymization.md)). Le informative non devono dichiarare anonimizzazione completa: è una riduzione del rischio | Sessione Chat LLM interna e proprietario | Prima di descriverla nelle informative |
| 9 | Contatto stabile in `SUPPORT_CONTACT_EMAIL` | Il default in `settings.py` è ancora un indirizzo personale provvisorio. Serve per gli artt. 16, 17, 21 GDPR e per gli artt. 11–12 DSA. «Contattaci» e «Fonti dati» già lo leggono dal backend. Si sostituisce con una variabile d'ambiente, nessuna build | Proprietario | **Prima del primo tester invitato** (l'informativa deve indicarlo) |
| 10 | Punto di contatto DSA per utenti e autorità (artt. 11–12) | Obbligo anche per le piccole imprese | Proprietario | Prima del lancio pubblico |
| 11 | Accettazione della v2 delle regole d'uso da parte di chi aveva accettato la v1 | Punto indicato in 07 (elenco dei punti da verificare). Implementazione da verificare | Proprietario e legale | Prima del lancio pubblico |
| 14 | Pagina «Fonti dati» (Impostazioni → Info): attribuzioni già mostrate | Il backend va allineato (punto 24) | Mappe interattive | Prima del lancio |
| 15 | Motivazione delle rimozioni: codici standard e collegamento alla segnalazione | Oggi `remove_reported_place.py` scrive codice e testo in `radar_place_overrides.reason`. Da fare: elenco dei codici; collegamento alla segnalazione dell'utente (art. 17 DSA, ⚖️ conferma) | Mappe interattive (collegamento), proprietario (codici) | Prima del lancio |
| 17 | Piano Free e prezzi reali | Oggi sono segnaposto; nessun piano limita o aggiunge funzioni | Proprietario | Fase marketing (rimandato) |
| 18 | Recensioni di strutture sanitarie | Sconsigliate in v1 (parere 07) | Proprietario | Non prima di una nuova analisi |
| 19 | Overture Maps e Foursquare: verifica dei record e dell'informativa | Vedi la tabella dei dubbi | Proprietario, legale, Mappe interattive | Prima del lancio |
| 20 | Protezioni contro le segnalazioni abusive: cluster, email verificata, età dell'account | Implementati: limite di 5 segnalazioni al giorno per account (`radar_reports.py`), riconoscimento di una segnalazione già presente e di un voto già espresso. Non implementati: rilevazione di cluster, email verificata, età dell'account | Mappe interattive e area auth | Prima del lancio, o prima della decisione su «luogo chiuso» |
| 21 | Tempo di risposta nelle regole («5 giorni lavorativi») | Promessa: processo presidiato oppure testo senza tempi (raccomandato) | Proprietario | Da discutere |
| 22 | Consegna della motivazione al segnalatore | Il servizio non conserva l'identità. Proposta: pseudonimo ricalcolato con HMAC dall'utente autenticato; schermata «le mie segnalazioni» con esito e motivazione solo per le sue | Mappe interattive e proprietario | Prima del lancio |
| 23 | Luogo chiuso attivo | Attivo per decisione dell'utente. Per la regola andrebbe spento o con conferma del moderatore. Da discutere, con i rischi in tabella | Utente, tramite l'Orchestratore | Da discutere |
| 24 | Attribuzioni nel backend (`data_sources.attribution`) | Le stringhe nell'app sono quelle approvate. Il backend va allineato quando gli script saranno liberati | Mappe interattive | Prima del lancio |
| 26 | Pubblicazione su Google Play: moduli in Play Console | Nel codice è fatto: `INTERNET` nel manifest principale e firma release da variabili d'ambiente (`ANDROID_KEYSTORE_PATH`, serve la chiave). Restano i moduli: «Sicurezza dei dati» coerente con l'informativa (da dichiarare anche numero di telefono facoltativo, foto profilo, annunci del Mercatino con foto e zona approssimata, percorsi delle passeggiate, registrazioni audio, file, email e identificativi) e dichiarazione dei servizi in primo piano (tipo posizione), da verificare nel modulo corrente | Proprietario (moduli Play) | Prima della pubblicazione su Play |
| 29 | Numero di telefono facoltativo senza funzione | In registrazione e nel profilo c'è un campo telefono, salvato nei metadati dell'account, che nessuna funzione usa. Raccogliere un dato senza scopo è un dubbio di minimizzazione e limitazione della finalità (art. 5(1)(b)–(c) GDPR), attenuato dal fatto che è facoltativo, modificabile, cancellato con l'account e descritto nelle informative (bozze del 2026-10-28). Tenerlo solo se serve a breve (per esempio verifica o recupero dell'account), altrimenti togliere il campo | Proprietario | Prima del lancio pubblico |

## Risolti

- **Frase del consenso «Privacy» che prometteva l'informativa completa nelle Impostazioni** (2026-10-06): il testo v2 non lo promette più e dice che è in preparazione. L'informativa completa resta il punto 6.
- **Testo del consenso alla cartella clinica che prometteva «mai l'intera cartella»** (2026-10-06): sostituito dalla v2; restano i punti 27 e 28.

- **Permessi Android non necessari e manifest** (ex punto 25, verificato il 2026-10-28): il manifest dell'app ha i marcatori `tools:node="remove"` per `READ_MEDIA_*` e `READ_EXTERNAL_STORAGE`, non dichiara `CAMERA` e dichiara `INTERNET`. Resta da guardare il manifest fuso della build release (`processReleaseManifest`).
- **Consenso alla cartella clinica e riepilogo non anonimizzato** (ex punti 27 e 28, verificato il 2026-10-28): consenso v3 con `effective_decision`, domanda in chat dallo stesso testo, riepilogo anonimizzato quando entra nello stato della conversazione.
- **Animali nel Mercatino** (decisione del proprietario, 2026-10-26): vietati in tutti i paesi, solo oggetti per animali. Regola aggiornata il 2026-10-28 nei Termini e nelle bozze per paese.

Le voci chiuse nelle versioni precedenti sono state tolte.
