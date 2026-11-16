# E-mail per chi lascia l'app: calendario e testi (decisione A, build 40)

Data: 2026-11-16. Proposta della sessione Registrazione, **da approvare**: i testi li decide la Normativa ([12](../compliance/12_avvisi_prima_della_cancellazione.md), [16](../compliance/16_recupero_account_dopo_la_cancellazione.md)), il calendario dei 120 giorni è codice della sessione Pricing (`packages/core/domain/subscription/retention.py`). Nel backend **non esiste ancora un invio di e-mail**: oggi ci sono solo il calendario, la scelta S/P e la prova a secco.

## 1. Le tre strade e cosa fa ciascuna

| Strada | Chi | Cosa succede | Durata |
|---|---|---|---|
| **Elimina** | preme «Elimina l'account» | disattivato subito; ripristino con la stessa e-mail; poi cancellato | 30 giorni (tetto di legge, doc 16 §1) |
| **Metti in pausa** | preme «Metti in pausa» | account inattivo, dati conservati, si rientra accedendo | **vedi §3: il «senza limite» è una decisione della Normativa** |
| **Senza piano** (esistente) | prova finita o piano scaduto | dati conservati, avvisi D+0/30/60/90 e 14/7/3/1 giorni prima | 120 giorni; ora anche la pausa ferma l'orologio |

«Elimina subito» (senza recupero) resta; per i minori di 14 anni resta la cancellazione immediata, senza sequenza.

## 2. «Elimina»: quattro e-mail di servizio (nessuna offerta, nessun invito a restare)

Per chi ha chiesto di andarsene non si manda nulla di commerciale, nemmeno con il consenso: sarebbe pressione su una richiesta (art. 21 GDPR; artt. 24–25 Codice del consumo). Sono messaggi sulla richiesta fatta, quindi non serve consenso. Calendario (codice già pronto e provato: `packages/core/domain/account_deletion/notices.py`, relativo alla data vera della cancellazione, quindi si sposta con `ACCOUNT_DELETION_GRACE_DAYS`):

| # | Quando | Oggetto |
|---|---|---|
| D1 | subito | «Abbiamo ricevuto la tua richiesta: eliminiamo il tuo account Quokka» |
| D2 | 7 giorni prima (giorno 23) | «Tra 7 giorni cancelliamo il tuo account Quokka» |
| D3 | il giorno prima (giorno 29) | «Domani cancelliamo il tuo account Quokka» |
| D4 | a cancellazione fatta | «Il tuo account Quokka è stato eliminato» |

Se l'utente ripristina, la sequenza si ferma e parte un solo messaggio di sicurezza («Hai ripristinato il tuo account; se non sei stato tu, cambia la password»). Chi sceglie «Elimina subito» riceve solo D4.

## 3. «Metti in pausa»: il punto che decide la Normativa

Il proprietario vuole la pausa **senza limite di tempo**. Il doc 16 §1 e §7 giustifica la pausa come scelta dell'utente **con un tetto di 4 mesi** e dice che il rischio sul limite di conservazione (art. 5(1)(e) GDPR) è basso proprio per quel tetto. Senza tetto quella valutazione non vale più. Opzioni, in ordine di preferenza:

1. **Senza scadenza automatica, con promemoria annuale** e una cancellazione automatica solo dopo un lungo silenzio (proposta: 24 mesi senza accedere, con avvisi a 23 mesi, 1 mese e 7 giorni prima). Il tetto è un'impostazione (`PAUSE_MAX_MONTHS`, vuota = nessuno).
2. Pausa senza scadenza e senza cancellazione automatica, con solo il promemoria annuale. Più vicina alle parole del proprietario, più esposta sul limite di conservazione.
3. Pausa con tetto di 4 mesi (doc 16 com'è): la più sicura, ma non è «senza limite».

Calendario (con l'opzione 1; i giorni cambiano se la Normativa sceglie altro):

| # | Quando | Oggetto |
|---|---|---|
| P1 | subito | «Il tuo account Quokka è in pausa» |
| P2 | dopo 6 mesi | «Il tuo account Quokka è ancora in pausa» (stato dell'account) |
| P3 | ogni 12 mesi | «Un anno dopo: i tuoi dati sono ancora qui» (stato dell'account) |
| P4–P6 | solo se c'è il tetto: 1 mese prima, 7 giorni prima, il giorno prima | avviso di cancellazione, come D2/D3 |

Sono tutte di servizio (versione S): dicono dove sono i dati e come uscire. Una versione P, che invita a tornare, esce solo con consenso commerciale in corso e maggiorenne, come nel doc 12 (regole 5, 6, 9).

## 4. Le 8 e-mail dei 120 giorni, riviste (rilettura)

Cambia il **blocco comune** del doc 12 (S e P), il resto resta: si aggiunge la pausa e si dice cosa resta dopo la cancellazione. Regola 7 del doc 12 aggiornata: **la sequenza si ferma se l'utente sceglie un piano, mette in pausa o elimina l'account**; scaricare i dati non la ferma.

## 5. Cosa deve dire ogni e-mail sui dati

Ogni e-mail ha tre blocchi, con le stesse parole ovunque (testi da approvare):

**Quando.** «Se non fai nulla, il {data_cancellazione} cancelliamo il tuo account e i tuoi dati: animali, chat, documenti, foto, promemoria e annunci.»

**Cosa resta.** «Dopo la cancellazione conserviamo solo: (1) un codice, senza il tuo nome né la tua e-mail, con la data e il motivo della cancellazione, per poter dimostrare che l'abbiamo fatta (fino a 5 anni); (2) le fatture, se ne hai, per obbligo di legge, presso chi le emette. Le copie di sicurezza si sovrascrivono entro {N} giorni.» (`{N}`: oggi il progetto è sul piano gratuito, senza copie del fornitore: da verificare, doc 16 §9.2. Non dire «anonimo»: è un dato pseudonimizzato, doc 16 §9.1.)

**Come evitarlo.** «Per non far cancellare l'account: scegli un piano {link_riattiva} oppure mettilo in pausa {link_pausa}. Per non perdere i dati, scarica una copia {link_scarica_dati}: la copia non ferma la cancellazione.»

Nell'e-mail D1–D3 il terzo blocco è «Se hai cambiato idea, accedi con questa e-mail {link_recupera}» e non cita piani né pausa (non è un'offerta: è la via per tornare). In D4 non c'è il terzo blocco.

## 6. Testi pronti (italiano, da approvare)

**D1** (oggetto sopra). «Ciao {nome}, il {data} ci hai chiesto di eliminare il tuo account. Lo disattiviamo subito e lo cancelliamo definitivamente il {data_fine}. Se hai cambiato idea, fino a quel giorno basta accedere con questa e-mail {link_recupera} (se serve, reimposta la password). Dopo non potremo più recuperare nulla. Se non sei stato tu, accedi subito e cambia la password, oppure scrivici. [blocco Quando][blocco Cosa resta] Questa è una comunicazione di servizio sulla tua richiesta. {titolare}, {contatto}.»

**D2.** «Ciao {nome}, il {data_fine} cancelliamo il tuo account e i tuoi dati, come ci hai chiesto. Mancano 7 giorni. Se hai cambiato idea, accedi con questa e-mail {link_recupera}. [Cosa resta] {titolare}, {contatto}.»

**D3.** «Ciao {nome}, domani, {data_fine}, cancelliamo il tuo account e i tuoi dati. Questa è l'ultima e-mail prima della cancellazione. Per fermarla accedi oggi con questa e-mail {link_recupera}. [Cosa resta] {titolare}, {contatto}.»

**D4.** «Ciao {nome}, il tuo account Quokka è stato eliminato e i tuoi dati sono stati cancellati dai nostri sistemi. [Cosa resta] Non ti scriveremo più per questo. {titolare}, {contatto}.» (l'indirizzo si legge prima della cancellazione dell'identità e non si conserva dopo l'invio.)

**P1.** «Ciao {nome}, il tuo account è in pausa. Non lo vedi più e non ti scriviamo per altro. Conserviamo i tuoi dati finché non decidi tu: per tornare basta accedere con questa e-mail. Puoi eliminarlo quando vuoi {link_elimina}. [Cosa resta se lo elimini] Comunicazione di servizio. {titolare}, {contatto}.»

**P2 / P3.** «Ciao {nome}, il tuo account è in pausa da {durata}. I tuoi dati sono ancora qui. Per tornare accedi con questa e-mail {link_recupera}; per scaricare una copia {link_scarica_dati}; per eliminarlo {link_elimina}. [Cosa resta se lo elimini] Comunicazione di servizio. {titolare}, {contatto}.»

**Blocco comune dei 120 giorni (S).** «Cosa puoi fare. Per tenere l'account scegli un piano {link_riattiva} oppure mettilo in pausa {link_pausa}: in pausa non lo cancelliamo e i dati restano. Per non perdere i dati scarica una copia {link_scarica_dati}: la copia non ferma la cancellazione. Se non fai nulla, il {data_cancellazione} cancelliamo l'account e i dati collegati e non si può annullare. [Cosa resta] {nota_minorenni} Comunicazione di servizio. {titolare}, {contatto}.» Il blocco P è lo stesso con l'etichetta «Comunicazione commerciale» e la revoca, come nel doc 12 §3.

## 7. Domande per la Normativa ⚖️

1. Pausa: quale opzione del §3 (e, con tetto, quanti mesi)? Il «senza limite» è conciliabile con l'art. 5(1)(e)?
2. Il promemoria annuale di una pausa senza tetto è un messaggio di servizio (non serve consenso) se non contiene inviti a tornare?
3. Per chi è in pausa o senza piano e vuole tornare: la frase «mettilo in pausa» dentro le e-mail dei 120 giorni è informazione o invito commerciale? Qui è scritta nella versione S.
4. «Cosa resta»: la frase sul codice è accettabile? I «5 anni» e `{N}` restano da confermare (doc 16 §7 e §9.1).
5. Niente versione commerciale per D1–D4: confermi?
6. Gli account 14–17: stessi testi con `{nota_minorenni}`? Quelli sotto 14 restano senza sequenza.

## 8. Cosa serve nel codice (non ancora costruito)

- Un invio di e-mail (oggi non c'è nessun fornitore; nuovo fornitore e nuovo paese vanno nell'inventario [06](../security/06_inventario_dati_fornitori.md) prima del rilascio) e il modello dei testi nelle 5 lingue.
- Per D1–D3: una colonna `last_notice` su `account_deletion_requests` (SQL idempotente) e un passo del lavoro programmato; D4 parte dal lavoro di cancellazione, con l'indirizzo letto prima di cancellare l'identità.
- Per la pausa: una tabella `account_pauses` (id, data inizio, ultimo avviso; RLS, riga nel test della cancellazione, riga nell'inventario) e due pulsanti nella finestra «Elimina account». La pausa ferma l'orologio dei 120 giorni (codice Pricing).
- Nessun testo di e-mail né conteggio nei log.
