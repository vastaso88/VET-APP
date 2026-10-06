# Informativa privacy: bozza (artt. 13–14 GDPR)

> **BOZZA. Non pubblicare così com'è.** Da far rivedere da un legale prima del primo tester invitato (registro [08](08_punti_aperti_prima_del_lancio.md), punto 6). I campi tra [parentesi quadre] vanno compilati o verificati. Le note per il revisore in fondo vanno tolte prima della pubblicazione.

Versione di prova: 2026-10-06 (aggiunti i permessi del dispositivo e i percorsi delle passeggiate; allineata alla sintesi «Privacy» v2 del catalogo di consensi).

## 1. Chi tratta i tuoi dati

[Ragione sociale], [sede], [P.IVA / codice fiscale]. Contatto privacy: [indirizzo di servizio, registro punto 9]. Responsabile della protezione dei dati: [non designato / da valutare, art. 37 GDPR].

## 2. Quali dati trattiamo

| Categoria | Esempi | Da dove vengono |
|---|---|---|
| Account | Email, nome, data di registrazione, scelte di consenso con data e versione | Tu, in registrazione. La password è gestita dal fornitore di autenticazione |
| Animali | Nome, specie, razza, età, peso, note, foto e video | Tu |
| Documenti e cartella clinica | Documenti caricati, eventi clinici. Possono contenere dati tuoi o di terzi (es. nome, codice fiscale) | Tu |
| Chat | Domande, risposte, allegati, messaggi vocali (trascritti per la risposta) | Tu e il sistema |
| Posizione | Posizione GPS, solo con il permesso del dispositivo; oppure indirizzo inserito a mano. Per le passeggiate, il percorso: punti GPS con data, ora e precisione, collegati al tuo account e al tuo animale | Tu, tramite il dispositivo |
| Contributi | Segnalazioni di luoghi, stelle sulle aree cani, voti. Associati a uno pseudonimo, non al tuo nome | Tu |
| Dati tecnici | Indirizzo IP e registri dei server | Il sistema, per funzionamento e sicurezza |
| Abbonamento | Piano scelto, inizio e fine della prova. Nessun dato di pagamento: i pagamenti non sono ancora attivi | Tu e il sistema |

### Permessi del dispositivo

L'app chiede un permesso solo quando usi la funzione che lo richiede. Se lo neghi, quella funzione resta disattivata e il resto dell'app continua a funzionare.

| Permesso | Quando serve | Cosa riceviamo |
|---|---|---|
| Posizione, mentre usi l'app | Impostare la tua zona, vedere luoghi e attività vicini, registrare le passeggiate | Le coordinate rilevate. Durante una passeggiata attiva la posizione continua a essere rilevata anche con l'app in secondo piano, e una notifica visibile lo segnala [verificare nel codice che il rilevamento si fermi alla fine della passeggiata] |
| Microfono | Registrare un messaggio vocale per la chat | La registrazione, che viene trascritta [verificare il fornitore: oggi risulta Groq] |
| Notifiche | Ricordarti vaccini e cure | Nessun dato: serve solo a mostrare gli avvisi |
| Foto, video e documenti | Aggiungere foto e video dei tuoi animali, allegare documenti | Solo i file che scegli. Per sceglierli l'app usa il selettore del sistema e non legge la tua galleria; per scattare usa la fotocamera del sistema [valido dopo la correzione del manifest, registro punto 25] |

## 3. Perché trattiamo i dati e su quale base

| Finalità | Base giuridica | Note |
|---|---|---|
| Creare e gestire l'account, erogare il servizio (animali, promemoria, chat, passeggiate) | Esecuzione del contratto, art. 6(1)(b) | Senza questi dati il servizio non può essere erogato |
| Rispondere alle domande in chat, anche con un fornitore di IA esterno | Esecuzione del contratto, art. 6(1)(b) | Le risposte sono generate da un sistema di IA e sono segnalate come tali (art. 50 AI Act) |
| Far leggere alla chat la cartella clinica di un tuo animale | Consenso, art. 6(1)(a), revocabile | Testo nella schermata di consenso (documento 03). Legge le tre voci più recenti o, per spiegare un esame, fino a due documenti |
| Mostrare luoghi vicini; raccogliere segnalazioni e stelle | Esecuzione del contratto, art. 6(1)(b); per i contributi [legittimo interesse, art. 6(1)(f): ⚖️ da confermare] | Le segnalazioni possono portare alla rimozione di un luogo |
| Email di marketing | Consenso, art. 6(1)(a), facoltativo | Revocabile in qualsiasi momento dalle Impostazioni |
| Analisi d'uso | Consenso, art. 6(1)(a), facoltativo | [Oggi non risulta alcuno strumento di analisi attivo: confermare o eliminare la voce] |
| Sicurezza, prevenzione degli abusi, obblighi di legge | Obbligo legale, art. 6(1)(c); legittimo interesse, art. 6(1)(f) | |

## 4. Chi riceve i dati

| Fornitore | Cosa riceve | Dove |
|---|---|---|
| Supabase | Database, autenticazione, archiviazione di allegati e foto | [regione del progetto: da indicare] |
| Vercel | Hosting del server applicativo | [da verificare] |
| Groq | Testo delle domande e dei documenti per la risposta; audio per la trascrizione; immagini per l'analisi | [da verificare: paese e garanzie] |
| Nominatim (OpenStreetMap) | Indirizzo inserito a mano, per trovarne le coordinate | [da verificare] |
| Server di tile OpenStreetMap | Indirizzo IP e aree di mappa richieste | [da sostituire o confermare, registro punto 1] |
| Overpass (dati OpenStreetMap) | Centro di una cella di griglia e indirizzo IP della richiesta; non la tua posizione precisa | [da verificare] |
| Google (Firebase App Distribution) | Solo per le versioni di prova: email del tester | [da verificare: paese e garanzie] |

**Dati su luoghi e attività.** I luoghi del radar provengono da OpenStreetMap, Overture Maps e dai dataset dei Comuni. Non contengono dati tuoi, ma possono riguardare titolari di attività individuali. Se sei il titolare di una scheda e vuoi rettificarla o opporti, scrivi al contatto privacy (art. 21 GDPR).

## 5. Come usiamo l'IA

Le risposte della chat sono generate da un sistema di IA. Prima di inviare il testo al fornitore, il sistema toglie automaticamente alcuni dati personali riconoscibili: email, telefoni, codice fiscale, indirizzi con numero civico, nomi preceduti da un'etichetta o noti dall'account. Non può riconoscerli tutti: per esempio un nome di persona scritto in mezzo a una frase. Immagini e audio partono così come sono. [Nota per il revisore: due chiamate al fornitore ricevono il riepilogo della cartella clinica senza filtro, registro 08, punto 28. Finché non è corretto, non scrivere che la cartella clinica viene filtrata.]

## 6. Per quanto tempo conserviamo i dati

| Dato | Periodo |
|---|---|
| Account e profilo animali | Fino alla cancellazione dell'account [procedura da definire] |
| Cartella clinica e documenti | Fino alla rimozione da parte tua o alla cancellazione dell'account [da confermare] |
| Chat | [da definire] |
| Percorsi delle passeggiate | [da definire: sono dati di posizione che possono rivelare abitudini e abitazione] |
| Segnalazioni e voti | Pseudonimo e voti cancellati 12 mesi dopo la chiusura della segnalazione; il contenuto resta senza riferimenti a te [da confermare] |
| Registri tecnici | [da definire con l'hosting] |
| Prova dei consensi | Per la durata del rapporto e il tempo di prescrizione [da confermare] |

## 7. I tuoi diritti

Puoi chiedere l'accesso ai tuoi dati, la rettifica, la cancellazione, la limitazione, la portabilità, e puoi opporti ai trattamenti basati sul legittimo interesse (artt. 15–21 GDPR). Puoi revocare i consensi in qualsiasi momento dalle Impostazioni, con la stessa facilità con cui li hai dati (art. 7(3)). Puoi proporre reclamo al Garante per la protezione dei dati personali. Le richieste vanno al contatto privacy indicato sopra; la risposta arriva entro un mese (art. 12(3)) [termine da confermare].

## 8. Minori

Il servizio è riservato a persone maggiorenni [da confermare l'età minima e le verifiche].

## 9. Decisioni automatizzate

Non prendiamo decisioni automatizzate con effetti giuridici su di te (art. 22 GDPR). [Nota per il revisore: la rimozione automatica di un luogo a 5 conferme riguarda dati di attività che possono appartenere a persone fisiche: valutare.]

## 10. Modifiche

Questa informativa può cambiare. Ti avvisiamo nell'app [modalità da definire]. Versione: [numero]. Data: [data]. Sarà consultabile dalle Impostazioni e dal link nella registrazione. Dal 2026-10-06 il testo di consenso «Privacy» (v2) non promette più una pagina che non esiste e dice che l'informativa completa è in preparazione: alla pubblicazione quel testo va aggiornato con una nuova versione.

---

## Note per il revisore (da eliminare prima della pubblicazione)

1. Non dichiarare anonimizzazione completa, pagamenti attivi o analisi d'uso: il filtro a regole (default in produzione) è una riduzione del rischio, non una garanzia; non ci sono pagamenti reali; `pubspec.yaml` non contiene SDK di analisi.
2. Foursquare: aggiungerlo alla tabella 4 solo se e quando il dato viene importato (registro, punto 19).
3. Il link all'informativa dalle Impostazioni e dalla registrazione è un prerequisito del primo invito.
4. Trasferimenti extra-UE (Groq, Vercel, Google): verificare le garanzie, per esempio le clausole contrattuali standard.
5. Il contatto privacy è un segnaposto: vedi registro, punto 9.
6. Testo di riferimento del consenso «Privacy»: `packages/core/domain/consent/account_consent_text.py` (v2, 2026-10-06). È una sintesi che deve restare coerente con questa informativa e dice che quella completa è «in preparazione»: alla pubblicazione sostituire la frase e passare a v3.
7. Permessi del dispositivo: le frasi su foto, video e fotocamera valgono solo dopo la correzione del manifest Android. Oggi il manifest dichiara ancora `READ_MEDIA_IMAGES` e, tramite il plugin `open_filex`, `READ_MEDIA_VIDEO` e `READ_MEDIA_AUDIO` (registro, punto 25; dettagli in [05](05_permessi_dispositivo_os.md)). Se `CAMERA` resta dichiarato, citare anche la fotocamera tra i permessi richiesti.
8. Percorsi delle passeggiate: il backend li conserva (`WalkSession.route`). Definire il periodo di conservazione e valutare se servono davvero tutti i punti GPS dopo la chiusura della passeggiata (minimizzazione).
