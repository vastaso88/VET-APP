# Recupero dell'account dopo la cancellazione: periodo lecito e testi

Data: 2026-11-16. Richiesta dell'Orchestratore, con la volontà del proprietario: un account cancellato deve potersi recuperare «entro la scadenza dei 4 mesi» con la stessa e-mail. Lo applica la sessione «Registrazione, log-in e recupero credenziali», che usa 30 giorni fino a questo parere. Non è consulenza legale: i punti ⚖️ vanno confermati da un legale.

## 1. Risposta in breve

**Quando l'utente chiede di cancellare, il massimo lecito è 30 giorni.** L'art. 17(1) GDPR chiede di cancellare «senza ingiustificato ritardo» e l'art. 12(3) di dare seguito alla richiesta «senza ingiustificato ritardo e comunque entro un mese». La proroga di altri due mesi esiste solo per richieste complesse o numerose e va comunicata entro il primo mese, con i motivi: non si può usare come regola né come finestra di ripensamento. Quindi **quattro mesi di recupero dopo «Elimina account» non sono leciti**; trenta giorni sì (è già ciò che usa la sessione Registrazione).

**Il risultato voluto dal proprietario si ottiene lecitamente con due strade distinte, scelte dall'utente:**

1. **«Elimina l'account»**: da subito l'account è congelato e, fino a 30 giorni dopo, chi accede con la stessa e-mail può ripristinarlo. Al 30º giorno la cancellazione è definitiva.
2. **«Metti in pausa»**: l'account resta, **senza che sia stata chiesta nessuna cancellazione**, fino a 4 mesi; poi si cancella da solo, con gli avvisi del [doc 12](12_avvisi_prima_della_cancellazione.md). È lo stato «account senza piano» già previsto e giustificato ([it/02](it/02_informativa_privacy_it.md) §3 e §7; [10](10_pareri_dal_2026_11_06.md) §4), ora scelto con un pulsante. Chi è in pausa può cancellare quando vuole: parte allora la strada 1.

Resta sempre il link «Elimina subito», senza recupero.

**Perché la pausa regge:** non è una cancellazione rimandata, ma una scelta dell'utente di non essere cancellato ancora, informata, annullabile e con un tetto (4 mesi). La base è il contratto e il legittimo interesse a farlo ritrovare i suoi dati, come per chi non rinnova. Resta ⚖️ il rapporto con il limite di conservazione (art. 5(1)(e)): il rischio è basso se la pausa non è mai la scelta preimpostata e i 4 mesi restano un massimo.

## 2. Cosa deve fare il sistema nei 30 giorni

1. **Subito:** chiudere le sessioni; nascondere l'account e gli annunci del Mercatino; non inviare niente (e-mail commerciali, notifiche, testi all'IA); nessun uso dei dati per altri scopi. Restano solo i dati che servono a riconoscere e ripristinare (e-mail e identificativi dell'account). Le conversazioni del Mercatino segnalate seguono la regola dell'informativa §7.
2. **Recupero:** accesso con la stessa e-mail e le credenziali (password o link e-mail di reimpostazione: un accesso valido basta). Chi si registra con un'e-mail già presente vede un suggerimento generico («Recupera account»), **senza rivelare se l'account esiste o è in eliminazione**: una ricerca per e-mail permetterebbe di scoprire chi è iscritto.
3. **Al 30º giorno:** cancellazione con lo stesso eraser dell'account (`supabase_account_eraser`), registro tecnico senza dati personali (data e identificativo anonimo, per dimostrare l'adempimento, art. 5(2)), e-mail finale.
4. **Copie di sicurezza:** si sovrascrivono secondo il ciclo del fornitore [da verificare: giorni di conservazione di Supabase]. Se si ripristina da una copia, si riapplicano le cancellazioni già fatte (serve un registro delle cancellazioni).

## 3. Cosa si recupera e cosa no

- **Si recupera** tutto ciò che c'era (animali, chat, documenti, foto, promemoria, annunci), **tranne** i consensi facoltativi: marketing, statistiche, rapporti sugli errori e lettura della cartella clinica tornano «non dati» e si chiedono al primo uso ([15](15_consensi_per_attivita.md), regola 6). Termini e informativa: si riaccettano se la versione corrente è più recente.
- **Piano e pagamenti** non si ripristinano da soli: si sceglie di nuovo. **Decisione per Prezzi:** la prova gratuita non si ripete per la stessa e-mail.

## 4. Cosa resta comunque

- **Fatture e scritture contabili:** 10 anni (art. 2220 c.c.), presso chi le emette; non sono nell'account.
- **Segnalazioni del Mercatino aperte o accolte:** come da informativa §7.
- **Elenco di soppressione del marketing:** l'impronta dell'e-mail (non l'indirizzo) di chi ha revocato il consenso, per non riscrivergli; legittimo interesse.
- **Registro tecnico della cancellazione:** senza dati personali.

## 5. Testi pronti (italiano)

**Finestra «Elimina account»** (dopo la conferma della password):
- Titolo: «Cosa vuoi fare con il tuo account?»
- «**Mettilo in pausa.** Non lo vedi più e non ti scriviamo. Conserviamo i tuoi dati fino a 4 mesi: puoi tornare in ogni momento accedendo con la stessa e-mail. Dopo 4 mesi li cancelliamo.» → «Metti in pausa»
- «**Eliminalo.** Cancelliamo tutto entro 30 giorni. Fino ad allora puoi cambiare idea accedendo con la stessa e-mail. Dopo non si recupera più.» → «Elimina l'account»
- In piccolo: «Vuoi eliminare subito, senza possibilità di recupero? **Elimina subito**». E: «Alcuni dati restano per obbligo di legge, per esempio le fatture. Dettagli nell'informativa.»
- Nessuna delle due strade preselezionata.

**E-mail dopo «Elimina l'account»** (messaggio di servizio, nessuna offerta). Oggetto: «Abbiamo ricevuto la tua richiesta: eliminiamo il tuo account Quokka». Testo: «Ciao {nome}, il {data} ci hai chiesto di eliminare il tuo account. Lo cancelliamo definitivamente il {data_fine}. Se hai cambiato idea, fino a quel giorno basta accedere con questa e-mail e ripristinarlo. Dopo non potremo più recuperare nulla. Se non sei stato tu, accedi subito e cambia la password, oppure scrivici.»

**Schermata all'accesso di un account in attesa:** «Il tuo account è in attesa di eliminazione. Lo cancelliamo il {data_fine}. Vuoi ripristinarlo?» → «Ripristina» e «Elimina subito».

**E-mail finale:** «Il tuo account Quokka è stato eliminato. Abbiamo cancellato i tuoi dati dai nostri sistemi; le copie di sicurezza si sovrascrivono entro {N} giorni. Restano solo i dati che la legge ci obbliga a conservare.» ({N}: da verificare.)

**E-mail all'inizio della pausa:** «Il tuo account è in pausa fino al {data}. Per tornare basta accedere con questa e-mail. Dopo quella data lo cancelliamo, e prima ti avvisiamo.» Poi la sequenza del doc 12.

**Informativa (da inserire in it/02 solo quando il codice esiste, con il marcatore «in attesa del codice»):**
- §7, riga nuova: «Account eliminato, in attesa della cancellazione definitiva | 30 giorni dalla richiesta. In questo periodo l'account non è visibile e non lo usiamo; puoi ripristinarlo accedendo con la stessa e-mail. Poi cancelliamo tutto, tranne ciò che la legge ci obbliga a conservare».
- §7, riga esistente «Account senza piano»: aggiungere «o messo in pausa da te».
- §8: «Quando elimini l'account, per 30 giorni puoi ripristinarlo; se vuoi che sia subito definitivo, scegli “Elimina subito”.»

## 6. Altre vie di richiesta

Una richiesta di cancellazione arrivata per e-mail o tramite il Garante segue la stessa regola (30 giorni, art. 12(3)) e non offre la pausa: si verifica l'identità di chi scrive e si cancella. Gli account chiusi per età (meno di 14 anni) restano fuori: nessun recupero, procedura del [08](08_punti_aperti_prima_del_lancio.md), punto 53.

## 7. Punti aperti ⚖️

1. La pausa di 4 mesi come scelta dell'utente: conferma del legale.
2. Il congelamento di 30 giorni come finestra di ripensamento: è prassi diffusa tra le piattaforme, non una regola scritta: va dichiarato con chiarezza e l'utente deve poter chiedere la cancellazione immediata.
3. Giorni dei backup di Supabase, per l'e-mail finale e l'informativa.

## 8. Risposte alla sessione Registrazione (2026-11-16)

La sessione ha costruito il ripensamento con la durata in un'impostazione (`ACCOUNT_DELETION_GRACE_DAYS`) e ha chiesto conferma.

1. **Durata.** 30 giorni è il massimo per «Elimina account». L'impostazione deve avere un **tetto a 30** (controllo all'avvio, valore predefinito 30), così un valore più alto non entra per errore. I 4 mesi del proprietario si ottengono con la pausa (§1), che è una funzione a parte.
2. **Base giuridica del ripensamento.** Entro i 30 giorni non serve un consenso: è il tempo che la legge dà per eseguire la cancellazione, usato nell'interesse dell'utente a poter revocare. I dati restano bloccati (nessuna funzione, nessun invio, nessun uso per altro) e l'utente lo sa. **Oltre i 30 giorni** non è più l'esecuzione di una cancellazione, ma una conservazione diversa: richiede la scelta esplicita dell'utente (la pausa), non preselezionata e annullabile con la cancellazione immediata. Un consenso nascosto nella finestra di eliminazione non basta.
3. **Testo.** La proposta della sessione va bene, con due aggiunte: «tutti i dati» diventa «i tuoi dati, tranne quelli che la legge ci obbliga a conservare, per esempio le fatture» (altrimenti la frase non è vera) e il collegamento «Elimina subito». Versione: «L'account verrà disattivato subito. Per {N} giorni puoi cambiare idea: accedi con la stessa e-mail (se serve, reimposta la password) e annulla l'eliminazione. Dopo il {data} cancelliamo l'account e i tuoi dati, senza possibilità di recupero. Restano solo i dati che la legge ci obbliga a conservare, per esempio le fatture.» + «Elimina subito, senza possibilità di recupero».
4. **Account chiusi per età (meno di 14 anni).** Nessun ripensamento: non c'è base per trattare quei dati (art. 17(1)(d)) e la cancellazione senza attesa è lecita e la più prudente. Ma **cambia la decisione del 9 novembre** ([08](08_punti_aperti_prima_del_lancio.md), punto 53: nessun lavoro automatico, cancellazione entro 30 giorni con la procedura del team, data corretta solo dopo aver verificato chi scrive): con la cancellazione immediata un errore di battitura nella data non si corregge più. È una scelta di prodotto: la confermano Orchestratore e proprietario.
5. **E-mail occupata durante l'attesa.** Accettabile se: chi prova a iscriversi con quell'e-mail vede un suggerimento («Recupera account») che **non rivela** se l'account esiste né che è in eliminazione (la soluzione della sessione Registrazione è migliore del messaggio specifico che avevo proposto, che permetteva di scoprire chi è iscritto); e se all'accesso c'è «Elimina subito», che libera l'e-mail. «Dati bloccati» vale come nel §2.

### Stato del codice al 16 novembre 2026 e condizioni

La sessione Registrazione ha scritto il ripensamento di 30 giorni (non ancora in produzione): tetto 30 e predefinito 30, testo della finestra del §8.3, «Elimina subito» anche all'accesso, consensi facoltativi azzerati dopo il ripristino, account congelato. Le righe corrispondenti sono in it/02 (§7 e §8), it/03 e it/04 con il marcatore «in attesa del codice» fino al deploy.

6. **Il lavoro che cancella al 30º giorno deve essere acceso insieme al congelamento.** Un account congelato che non viene mai cancellato supera il limite di un mese dell'art. 12(3): senza il lavoro (o un'esecuzione manuale documentata, con un controllo che segnali le scadenze superate) il congelamento non va in produzione. Decisione dell'Orchestratore.
7. **Registro duraturo delle cancellazioni** (oggi solo il numero nel log, che dura poco): serve prima del lancio pubblico, per dimostrare l'adempimento (art. 5(2)) e per riapplicare le cancellazioni dopo un ripristino da backup. **Approvato da Sicurezza il 16 novembre e costruito da Registrazione: vedi §9.**
8. **E-mail** (richiesta di eliminazione, finale, inizio pausa): non obbligatorie per legge; finché il backend non può inviarle, la schermata che conferma l'eliminazione deve mostrare la data della cancellazione definitiva e come ripristinare. Un'e-mail «se non sei stato tu» resta consigliata per la sicurezza.
9. **Pausa di 4 mesi e finestra a due scelte:** non ancora fatte. Finché mancano, il testo della finestra non deve promettere 4 mesi: la volontà del proprietario non è soddisfatta e la decisione resta all'Orchestratore.

## 9. Registro delle cancellazioni e copie manuali del database (2026-11-16)

### 9.1 Il registro (approvato da Sicurezza, costruito da Registrazione)

- **Contenuto:** impronta non reversibile dell'identificativo dell'account, data, motivo (richiesta dell'utente, età, nessun piano). Mai e-mail, nome o contenuti.
- **Natura:** dato pseudonimizzato, quindi **ancora dato personale** (considerando 26 GDPR): la cancellazione dell'account non lo toglie, e nel test della cancellazione non va tra le tabelle senza dati personali ma in una voce a parte («conservato dopo la cancellazione», con motivo e durata).
- **Scopi e basi:** rifare le cancellazioni se si ripristina una copia di sicurezza (obbligo legale: artt. 17 e 5(2) GDPR, art. 6(1)(c)); provare di aver rispettato la richiesta (responsabilizzazione, art. 5(2); legittimo interesse a difendere un diritto, art. 6(1)(f) e art. 17(3)(e)).
- **Durata:** copie di sicurezza più 30 giorni (primo scopo) e **5 anni** dalla cancellazione (seconda ragione: art. 2947 c.c., prescrizione del risarcimento per fatto illecito; le sanzioni amministrative si prescrivono in 5 anni, art. 28 l. 689/1981 ⚖️). Dopo, le righe si cancellano: **serve un lavoro** (per esempio annuale), altrimenti il limite non è rispettato.
- **Impronta:** l'identificativo dell'account è un UUID casuale, quindi basta SHA-256; se gli identificativi non fossero casuali serve HMAC con una chiave segreta tenuta fuori dal database. Non cambiare algoritmo né chiave finché dura il registro, o le impronte non si confrontano più.
- **Diritti delle persone:** dopo la cancellazione non teniamo più l'identificativo, quindi dall'impronta non possiamo risalire a nessuno (art. 11 GDPR): i diritti degli artt. 15–20 si esercitano solo se la persona ci dà elementi per ricostruirla. La prova per l'utente è la conferma di eliminazione che vede.
- **Sicurezza e inventario:** sicurezza a livello di riga senza policy per gli utenti (solo il servizio); riga nell'inventario dei dati ([06](../security/06_inventario_dati_fornitori.md), la scrive Sicurezza); righe in it/02 §3 e §7, scritte con «in attesa del codice».
- **⚖️ Domande per il legale:** (1) i 5 anni per impronta, data e motivo sono proporzionati e coperti dall'art. 17(3)(e)? Sarebbero sufficienti 3 anni? (2) Serve una voce nel registro dei trattamenti (art. 30)? (3) Se una persona si oppone (art. 21), la riga resta per lo scopo di prova?

### 9.2 Copie manuali del database (regola concordata con Sicurezza il 16 novembre)

Le copie automatiche del fornitore (backup e ripristino a un punto nel tempo) sono coperte dal registro: dopo un ripristino si rifanno le cancellazioni. Le **copie manuali** (dump, esportazioni, tabelle copiate sul computer o altrove) no: restano in giro con dati di account già cancellati e sfuggono ai 30 giorni. Regola, in sintesi (il testo di riferimento è di Sicurezza: `docs/security/12_copie_dati_e_backup.md`):

1. **Di norma nessuna copia manuale di dati reali.** Per sviluppo e prove si usano dati sintetici (è già regola del progetto: niente account reali, `SUPABASE_URL` vuoto per le prove locali).
2. **Eccezione solo se serve** (migrazione, indagine su una violazione, ripristino) e solo con l'approvazione scritta **del proprietario, dopo aver sentito Sicurezza** (una sessione di IA consiglia, non approva), annotata in un **elenco delle copie tenuto fuori dal repository**, come il registro delle violazioni, perché dice dove sono i dati: che cosa, dove, chi, perché, data, **scadenza**.
3. **Scadenza breve:** al massimo 30 giorni, come il ripensamento; oltre, solo con una nuova approvazione, un motivo scritto e **dopo aver rifatto sulla copia le cancellazioni del registro** (altrimenti conterrebbe account già cancellati e la frase dell'informativa sulle copie non sarebbe più vera).
4. **Custodia:** cifrata (per esempio un archivio AES-256 con la password nel gestore di password, oppure un disco cifrato), in un luogo privato con accesso limitato; **mai in una cartella sincronizzata** (Drive, OneDrive, iCloud: versioni e cestini moltiplicano le copie); **mai dentro la cartella del progetto o di un worktree**, dove le sessioni di IA la leggerebbero; mai nel repository (pubblico), mai incollata in chat o in strumenti di IA.
5. **Cancellazioni riapplicate:** prima di usare una copia si rifanno le cancellazioni del registro; se non si può, non la si usa. Nel ripristino: si esporta il registro prima, lo si ricarica dopo e si rifanno le cancellazioni, la prima volta a secco (procedura nel documento di Sicurezza).
6. **Alla scadenza** si cancella la copia (anche dai cestini) e si annota la data nell'elenco; l'elenco si controlla ogni mese.
7. **«Scarica i miei dati»** è la copia che l'utente chiede per sé, non una copia del team, e non resta sul server oltre il collegamento (15 minuti).
8. **Chi trova una copia non in elenco** la cancella e avvisa Sicurezza: può essere una violazione ([03](../security/03_procedura_violazioni.md)).

**Copie automatiche di Supabase** (pagine ufficiali lette da Sicurezza il 16 novembre): piano gratuito, nessuna copia del fornitore; Pro, copie giornaliere per 7 giorni (Team 14, Enterprise fino a 30); con il ripristino a un punto nel tempo, a pagamento, 7, 14 o 28 giorni al posto delle giornaliere. Coprono solo il database, non i file dell'archivio. Il piano del progetto è il **gratuito** (verificato dall'Orchestratore nella dashboard il 16 novembre: il piano gratuito non include le copie del progetto): nessuna copia, quindi «copie di sicurezza più 30 giorni» vale **30 giorni**; con il Pro sarebbero 37 (decisione F del proprietario). **Per il lancio pubblico il piano gratuito non basta:** senza copie non si può ripristinare la disponibilità dei dati dopo un incidente (art. 32(1)(c) GDPR); raccomando il Pro. Le copie manuali periodiche non sono un'alternativa al Pro: la regola le ammette solo come eccezione approvata, per esempio una copia cifrata prima di ogni script SQL sul database reale (documento di Sicurezza, §1 e rischio R29). Fonti: supabase.com/docs/guides/platform/backups.
