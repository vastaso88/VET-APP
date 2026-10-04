# Informativa privacy: bozza (artt. 13–14 GDPR)

> **BOZZA. Non pubblicare così com'è.** Da far rivedere da un legale prima del primo tester invitato (registro [08](08_punti_aperti_prima_del_lancio.md), punto 6). I campi tra [parentesi quadre] vanno compilati o verificati. Le note per il revisore in fondo vanno tolte prima della pubblicazione.

Versione di prova: 2026-10-04.

## 1. Chi tratta i tuoi dati

[Ragione sociale], [sede], [P.IVA / codice fiscale]. Contatto privacy: [indirizzo di servizio, registro punto 9]. Responsabile della protezione dei dati: [non designato / da valutare, art. 37 GDPR].

## 2. Quali dati trattiamo

| Categoria | Esempi | Da dove vengono |
|---|---|---|
| Account | Email, nome, data di registrazione, scelte di consenso con data e versione | Tu, in registrazione. La password è gestita dal fornitore di autenticazione |
| Animali | Nome, specie, razza, età, peso, note, foto | Tu |
| Documenti e cartella clinica | Documenti caricati, eventi clinici. Possono contenere dati tuoi o di terzi (es. nome, codice fiscale) | Tu |
| Chat | Domande, risposte, allegati, messaggi vocali (trascritti per la risposta) | Tu e il sistema |
| Posizione | Posizione GPS, solo con il permesso del dispositivo; oppure indirizzo inserito a mano | Tu |
| Contributi | Segnalazioni di luoghi, stelle sulle aree cani, voti. Associati a uno pseudonimo, non al tuo nome | Tu |
| Dati tecnici | Indirizzo IP e registri dei server | Il sistema, per funzionamento e sicurezza |
| Abbonamento | Piano scelto, inizio e fine della prova. Nessun dato di pagamento: i pagamenti non sono ancora attivi | Tu e il sistema |

## 3. Perché trattiamo i dati e su quale base

| Finalità | Base giuridica | Note |
|---|---|---|
| Creare e gestire l'account, erogare il servizio (animali, promemoria, chat) | Esecuzione del contratto, art. 6(1)(b) | Senza questi dati il servizio non può essere erogato |
| Rispondere alle domande in chat, anche con un fornitore di IA esterno | Esecuzione del contratto, art. 6(1)(b) | Le risposte sono generate da un sistema di IA e sono segnalate come tali (art. 50 AI Act) |
| Far leggere alla chat la cartella clinica di un tuo animale | Consenso, art. 6(1)(a), revocabile | Testo nella schermata di consenso (documento 03) |
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

Le risposte della chat sono generate da un sistema di IA. [Nota per il revisore: oggi i testi inviati al fornitore non sono anonimizzati automaticamente. Non scrivere che lo sono finché l'anonimizzazione non è attiva, registro 08, punto 8.]

## 6. Per quanto tempo conserviamo i dati

| Dato | Periodo |
|---|---|
| Account e profilo animali | Fino alla cancellazione dell'account [procedura da definire] |
| Cartella clinica e documenti | Fino alla rimozione da parte tua o alla cancellazione dell'account [da confermare] |
| Chat | [da definire] |
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

Questa informativa può cambiare. Ti avvisiamo nell'app [modalità da definire]. Versione: [numero]. Data: [data]. È consultabile in qualsiasi momento dalle Impostazioni: la schermata di consenso lo promette, quindi il collegamento va creato prima del primo invito.

---

## Note per il revisore (da eliminare prima della pubblicazione)

1. Non dichiarare anonimizzazione attiva, pagamenti attivi o analisi d'uso: oggi il filtro PII è `noop`, non ci sono pagamenti reali e `pubspec.yaml` non contiene SDK di analisi.
2. Foursquare: aggiungerlo alla tabella 4 solo se e quando il dato viene importato (registro, punto 19).
3. Il link all'informativa dalle Impostazioni e dalla schermata di consenso è un prerequisito del primo invito.
4. Trasferimenti extra-UE (Groq, Vercel, Google): verificare le garanzie, per esempio le clausole contrattuali standard.
5. Il contatto privacy è un segnaposto: vedi registro, punto 9.
6. Testo di riferimento del consenso «Privacy»: `packages/core/domain/consent/account_consent_text.py`, che promette l'informativa completa.
