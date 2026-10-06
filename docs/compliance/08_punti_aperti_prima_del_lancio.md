# Punti aperti prima del lancio pubblico

Registro, aggiornato 2026-10-06 (punti 25 e 26: permessi Android e pubblicazione su Play; punti 27 e 28: consenso alla cartella clinica e anonimizzazione del riepilogo). Precedente aggiornamento 2026-10-04, dopo il riscontro dell'Orchestratore. Pareri di riferimento: [06](06_radar_mappe_sponsorizzazioni.md) e [07](07_contributi_utenti.md). I numeri restano stabili per i riferimenti nei pareri; le voci chiuse sono state tolte.

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
| Consenso alla cartella clinica (chat) | Attivo. Testo v2 dal 2026-10-06, che descrive la lettura reale | Sì: punti 27 e 28 |
| Contributi verso OpenStreetMap | Non implementati | — |

## Dubbi per voce (per la discussione con l'utente)

| Voce | Dubbio preciso | Rischio concreto o da far confermare | Cosa lo scioglie | Test (pochi invitati) / Lancio |
|---|---|---|---|---|
| Informativa privacy completa (artt. 13–14 GDPR) | Il consenso «Privacy» v1 diceva che l'informativa completa era consultabile dalle Impostazioni: non esiste. Dal 2026-10-06 (v2) riassume i trattamenti e dice che è in preparazione. Già oggi trattiamo dati di tester reali: la sintesi non sostituisce l'informativa art. 13 | Rischio concreto e attuale | Informativa raggiungibile dalle Impostazioni e dalla registrazione prima del primo invito (bozza in [09](09_informativa_privacy_bozza.md)); poi nuova versione del testo di consenso | Alta / Alta |
| Consenso alla cartella clinica | La v1 prometteva «solo le informazioni rilevanti, mai l'intera cartella»: la chat riceve le tre voci più recenti (fino a 1.200 caratteri di documento ciascuna) e, per «spiega l'esame», fino a due documenti (3.500 caratteri). Corretto nel testo v2. Residui: la domanda in chat dice ancora la frase vecchia, i consensi dati con la v1 restano validi, il riepilogo nello stato della conversazione non è anonimizzato | Concreto: consenso non informato per quelli dati con la v1 o con la domanda in chat | Domanda in chat da `INLINE_QUESTION_IT`; chiedere di nuovo i consensi v1; filtrare il riepilogo nello stato; oppure limitare ciò che si invia (scelta del proprietario, vedi 03) | Media / Alta |
| Overture Maps | (a) Licenza per record: il campo `sources` può indicare origini con termini diversi dal CDLA-P-2.0. (b) Dati di ditte individuali senza informativa art. 14 né legittimo interesse documentato. Uso commerciale e share-alike: nessun dubbio (parere del 2026-10-03) | (a) da far confermare; (b) rischio concreto | (a) verifica di `sources` e filtro dei record incompatibili; (b) informativa, legittimo interesse documentato, canale di opposizione attivo | Media / Alta |
| Luogo chiuso | Affermazione non verificata su attività identificabili: danno economico immediato se falsa. Cinque conferme possono essere fabbricate, perché email ed età dell'account non sono verificate | Rischio concreto | Email verificata ed età dell'account; conferma di un moderatore prima che il luogo sparisca; contestazione con sospensione durante l'esame | Media / Alta |
| Luogo mancante | Nome di una ditta individuale; posizione di abitazioni di pet sitter ed educatori a domicilio | Concreto per il domicilio; da far confermare per le ditte individuali | Legittimo interesse documentato; per le categorie a domicilio, posizione approssimata (non l'indirizzo esatto) | Bassa-media / Media-alta |
| Doppione o posizione errata | Posizione errata usata per danneggiare un concorrente (concorrenza sleale) | Da far confermare | Canale di contestazione; conferme multiple (già presenti) | Bassa / Media |
| Aree cani mancanti | Area privata confermata come pubblica: invasione di terreni (art. 637 c.p.), abitazioni identificabili | Concreto per l'area privata; da far confermare la responsabilità | Confronto con il dataset comunale; rimozione immediata alla richiesta; parere legale | Bassa / Media-alta |
| Motivazione delle rimozioni (art. 17 DSA) | Obbligo verso chi ha segnalato, ora che le segnalazioni sono attive | Da far confermare (⚖️) | Motivazione già scritta da `scripts/radar/remove_reported_place.py` in `radar_place_overrides.reason`; collegamento alla segnalazione e «le mie segnalazioni» (punto 22) | Bassa / Media |
| Badge «Più scelto» sul piano Pro | Affermazione non verificata: pratica commerciale potenzialmente ingannevole (artt. 21–22 cod. cons.) se non riflette un dato reale | Concreto se la scelta non è documentata; oggi nessun pagamento reale | Toglierlo o sostituirlo con una formula verificabile. Instradato dall'Orchestratore | Bassa / Media |
| «5 giorni lavorativi» nelle regole | Promessa di tempi non presidiata | Basso: è un testo | Processo presidiato, oppure testo senza tempi (punto 21) | Bassa / Media |
| Permessi Android sui media | `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` e `READ_EXTERNAL_STORAGE` (fino ad Android 12) sono aggiunti dal plugin `open_filex`; `READ_MEDIA_IMAGES` e `CAMERA` li dichiara l'app. Nessuna funzione li usa | Concreto per Google Play: foto e video solo per accesso ampio e frequente, con dichiarazione e revisione. Minimizzazione ⚖️ | Rimozione con `tools:node="remove"` (raccomandazione in [05](05_permessi_dispositivo_os.md), sezione «Audit del manifest») | Bassa (gli APK di test non passano da Play) / Alta |

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
| 25 | Permessi Android non necessari: `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, `READ_EXTERNAL_STORAGE` (fino ad Android 12); consigliato togliere anche `CAMERA` | Vengono dal manifest dell'app (`READ_MEDIA_IMAGES`, `CAMERA`) e dal plugin `open_filex` (gli altri). Nulla nel codice li usa. Policy Google Play su foto e video: accesso ampio solo con dichiarazione. Raccomandazione tecnica, con il codice da aggiungere, in [05](05_permessi_dispositivo_os.md), sezione «Audit del manifest» | «APK e App nativa» (esegue), Orchestratore (instrada) | Prima della pubblicazione su Play; non urgente per i test |
| 26 | Preparazione alla pubblicazione su Google Play: `INTERNET` nel manifest principale (oggi solo in `src/debug` e `src/profile`: gli APK di test sono debug), firma release (oggi `signingConfig` di debug in `app/build.gradle.kts`), modulo «Sicurezza dei dati» coerente con l'informativa, dichiarazione dei servizi in primo piano (tipo posizione) | Una build release potrebbe non avere rete senza `INTERNET`. Il modulo deve dichiarare foto e video, registrazioni audio, posizione (compresi i percorsi delle passeggiate), file, email e identificativi. Dichiarazione dei servizi in primo piano: da verificare nel modulo corrente | «APK e App nativa» (manifest e firma), proprietario (moduli Play) | Prima della pubblicazione su Play |
| 27 | Consenso alla cartella clinica: allineare la domanda in chat e trattare i consensi dati con la v1 | Il testo v2 (2026-10-06) descrive la lettura reale, ma `chat_orchestrator.py` (circa riga 713) chiede ancora «Guarderò solo le informazioni rilevanti»: sostituzione pronta in `INLINE_QUESTION_IT` (`consent_text.py`). I consensi dati con la v1 restano validi perché `send_chat_message.py` non confronta la versione: opzioni in [03](03_consenso_cartella_clinica.md). Alternativa per il proprietario: limitare ciò che si invia | Sessione Chat LLM interna (codice), proprietario (alternativa) | Prima del prossimo invito a nuovi tester |
| 28 | Riepilogo della cartella clinica non anonimizzato nello stato della conversazione | `SituationModel.known_medical_context` è il testo originale; lo ricevono in chiaro l'estrazione del situation model (`situation_model_builder.py`, «Situation known so far») e il planner dell'intervista (`interview_planner.py`, «Case so far»), cioè il fornitore esterno. Correzione: anonimizzare il riepilogo quando entra nello stato (due punti in `chat_orchestrator.py`). Dettagli in [02](02_pii_anonymization.md) | Sessione Chat LLM interna | Prima del prossimo invito a nuovi tester |

## Risolti

- **Frase del consenso «Privacy» che prometteva l'informativa completa nelle Impostazioni** (2026-10-06): il testo v2 non lo promette più e dice che è in preparazione. L'informativa completa resta il punto 6.
- **Testo del consenso alla cartella clinica che prometteva «mai l'intera cartella»** (2026-10-06): sostituito dalla v2; restano i punti 27 e 28.

Le voci chiuse nelle versioni precedenti sono state tolte.
