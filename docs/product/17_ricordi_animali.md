# 17 — Ricordi: quando un animale non c'è più

Stato: **proposta, in attesa di approvazione del proprietario** (16/11/2026).
Nessuna riga di codice è stata scritta: si costruisce solo dopo il via.

Richiesta del proprietario: «Sposta nei ricordi: l'animale deceduto viene
spostato in una parte dedicata dentro Animali, non di immediato accesso (in
fondo in basso). Altissima empatia. Va inserita la data della perdita. Va
chiesto se si vogliono ricordare con promemoria ad hoc il compleanno e le
passeggiate preferite, con le foto. Se problemi di privacy, bypassa.»

---

## 0. Cosa c'è già oggi nell'app (e cosa non va)

Una versione minima esiste già, costruita mesi fa:

| Cosa c'è | Problema |
|---|---|
| Pulsante «Sposta nei ricordi» nella modifica dell'animale | Non chiede la data: mette sempre **oggi**. |
| La data viene salvata (`memorial_date_label`) | **Non viene riletta**: alla riapertura dell'app la data sparisce e nella lista Ricordi resta solo la nascita. |
| Pagina «Ricordi» | Si apre da un'icona **in alto**, accanto al «+»: è di immediato accesso, il contrario di quanto chiesto. |
| Riga di ogni ricordo | Ha un **cestino** a portata di dito: con un tocco di troppo si cancella per sempre. |
| Notifiche | Compleanno e promemoria dell'animale già si fermano. |
| Home, calendario, lista Promemoria | **Continuano a mostrare** i promemoria dell'animale (vaccini scaduti, farmaci) dopo la perdita. |
| Messaggio «Fatto? Registralo» | Può ancora comparire per un promemoria dell'animale. |
| Tornare indietro | **Non esiste**: se lo sposti per errore puoi solo cancellarlo. |
| Testo «Presto: le passeggiate più lunghe…» | Promessa vuota dentro una pagina di lutto. |

Questa proposta sostituisce tutto questo.

---

## 1. Principi

1. **Il ricordo lo decide la persona, mai l'app.** Nessun promemoria-ricordo è
   acceso da solo: tutti spenti finché la persona non li accende.
2. **Silenzio immediato su ciò che riguarda un animale vivo.** Dal momento
   dello spostamento: nessun vaccino, farmaco, visita, pesata, compleanno
   «normale» (con «pensa a un regalo»), nessun «Fatto?».
3. **Niente si perde.** Spostare nei ricordi non cancella nulla: profilo, foto,
   passeggiate, documenti, storia clinica e anche i promemoria restano
   conservati. Per questo l'errore si può sempre annullare.
4. **Parole semplici, senza retorica.** Niente «ponte dell'arcobaleno», niente
   «angelo», niente frasi religiose: non sappiamo cosa crede la persona.
   Frasi brevi, che funzionano per un cane come per un pesce rosso.
5. **Senza genere grammaticale.** Il sesso dell'animale a volte manca e un
   «lo/la» sbagliato in quel momento fa male: tutte le frasi sono scritte in
   modo che non serva (es. «per {nome}» invece di «che lo riguardano»).
6. **Privacy prima della bellezza.** Le foto non compaiono mai nella notifica
   sulla schermata di blocco: compaiono solo dentro l'app, dopo il tocco.

---

## 2. Dove sta la sezione

- **Dentro Animali, in fondo alla lista**, dopo l'ultimo animale: una riga
  sobria, colori tenui, senza badge o numeri colorati.

  ```
  ─────────────────────────────────────
   ✦  Ricordi                        2 ›
      Gli animali che hanno condiviso la tua strada
  ```

- La riga compare **solo se c'è almeno un ricordo**.
- Sta in fondo **anche quando si usa il filtro per specie** (non si filtra).
- L'icona attuale in alto accanto al «+» **viene tolta**.
- Non compare in Home, nel menu, nelle Impostazioni, né altrove.

Se tutti gli animali sono nei Ricordi, la lista Animali non dice più
«Nessun pet ancora — Crea pet» ma un testo che non mette fretta (§9) e, sotto,
la stessa riga Ricordi.

---

## 3. Il flusso «Sposta nei ricordi»

### 3.1 Da dove si parte
Modifica animale → in fondo, sopra «Elimina», il pulsante già presente
**«Sposta nei ricordi»** (resta lì: è un gesto voluto, non deve stare in
prima vista nella scheda).

### 3.2 Passo 1 — la data (pagina intera, non un piccolo popup)

```
  ┌──────────────────────────────────────┐
  │        [foto profilo, rotonda]       │
  │                                      │
  │     Ci dispiace tanto per Moka.      │
  │                                      │
  │  Qui puoi custodire il suo ricordo.  │
  │  Moka lascerà la lista Animali e non │
  │  ti manderemo più promemoria, farmaci│
  │  o auguri per Moka. Profilo, foto,   │
  │  passeggiate e documenti restano nel │
  │  tuo account finché non li elimini:  │
  │  puoi rivederli e scaricarli quando  │
  │  vuoi.                               │
  │                                      │
  │  Data della perdita                  │
  │  [ 14/11/2026            📅 ]         │
  │  Se non ricordi il giorno esatto,    │
  │  va bene una data indicativa.        │
  │                                      │
  │  [ Continua ]                        │
  │   Annulla                            │
  └──────────────────────────────────────┘
```

- Data proposta: **oggi**. Non si può scegliere una data futura né una data
  prima della nascita (se la nascita è nota).
- «Annulla» torna indietro senza cambiare nulla.

### 3.3 Passo 2 — i promemoria del ricordo (facoltativo, chiesto con garbo)

Compare **solo se almeno una voce è possibile** (vedi §5.1); altrimenti si
salta e si conferma direttamente.

```
  Vuoi che Quokka ti aiuti a ricordare?

  Se ti fa piacere, possiamo mandarti un pensiero in alcuni giorni
  speciali, con le sue foto. Puoi cambiare idea quando vuoi.

  [  ] Il giorno del compleanno
       Con la foto profilo e le foto dei compleanni passati.
  [  ] Le passeggiate preferite                       (solo cani)
       Nel giorno di una passeggiata salvata tra le preferite,
       con il percorso e le foto di quel giorno.
  [  ] Le foto di questo giorno               (da decidere, §12)
       Quando ci sono foto scattate in quel giorno negli anni
       passati. Al massimo una volta a settimana.

  [ Sposta nei ricordi ]
    Indietro
```

- Tutti gli interruttori **spenti** di partenza.
- Il pulsante principale è lo stesso sia che si accenda qualcosa sia che no:
  non c'è un «No grazie» che faccia sentire in colpa.

### 3.4 Dopo la conferma
- Si torna alla lista Animali; l'animale non c'è più nella lista, c'è la riga
  Ricordi in fondo.
- Messaggio in basso per 8 secondi: **«Moka è ora nei Ricordi.»** con il
  pulsante **«Annulla»** (per il tocco sbagliato immediato).

---

## 4. Cosa succede a tutto il resto (subito e in silenzio)

| Parte dell'app | Cosa succede | Si recupera se annullo? |
|---|---|---|
| **Promemoria** (visite, vaccini, ricorrenti) | Non suonano più, spariscono da Home, calendario, lista Promemoria e conteggi. **Non** vengono cancellati né segnati «fatti» (non finiscono nello storico clinico). | Sì, tornano come prima. |
| **Farmaci** (cicli con dosi) | Come sopra: niente più notifiche di dose. | Sì. |
| **Notifiche già programmate** | Tolte subito dal telefono (il piano notifiche si ricalcola). Quelle già comparse nella tendina per quell'animale vengono rimosse. | Si riprogrammano da sole. |
| **Compleanno «normale»** e «Compleanno in arrivo: pensa a un regalo» | Mai più. Al loro posto, solo se scelto, il promemoria-ricordo (§5). | — |
| **«Fatto? Registralo nello storico»** | Non compare più per quell'animale. | — |
| **Passeggiata in corso** per quell'animale (caso raro) | Viene chiusa e salvata in silenzio. | Resta salvata. |
| **Avvio passeggiata, widget Android** | L'animale non compare più tra quelli da portare a spasso. | Sì. |
| **Pesate e condizione corporea** | Nessun invito a pesare. Il grafico resta consultabile nella pagina del ricordo, senza «Aggiungi pesata». | Sì. |
| **Galleria** | La cartella dell'animale esce dalle cartelle principali; le foto restano tutte e si vedono nella pagina del ricordo. Si possono **aggiungere** foto (succede spesso: si ritrovano foto vecchie). | Sì. |
| **Documenti e storia clinica** | Restano consultabili e si possono **aggiungere** documenti (per esempio un referto finale o un certificato). | Sì. |
| **Chat** | L'animale non si può più scegliere per una nuova conversazione. Le conversazioni passate restano nella lista Chat, leggibili ed eliminabili come oggi (vedi §12). | Sì. |
| **Consenso «la chat può leggere la cartella clinica»** | Si **spegne** (indicazione di MARKETING e NORMATIVA, doc compliance 17 §B.2 punto 4): anche scrivendo in una vecchia conversazione, la chat non legge più la cartella di quell'animale né i Ricordi. | No: se l'animale torna tra gli animali, la chat chiede di nuovo il consenso, come per un animale nuovo. |
| **«Scarica i miei dati»** | Comprende i Ricordi (stanno nel profilo dell'animale, già esportato; da verificare in fase 2). | — |
| **Mercatino** | Nessun effetto: gli annunci non sono legati agli animali (dal 2026 niente animali in vendita). | — |
| **Statistiche e badge passeggiate** | Restano conservati; nella pagina del ricordo diventano una frase sola (§6). | Sì. |
| **Home** | L'animale sparisce da chip, calendario, legenda, agenda e conteggi. Nessuna scheda «ricordo» in Home. | Sì. |
| **Statistiche interne (portale admin)** | Già oggi contano a parte gli animali nei Ricordi. Nessun cambio. | — |

---

## 5. I promemoria del ricordo

### 5.1 Quali sono e quando si possono accendere

| Promemoria | Possibile solo se | Quando arriva |
|---|---|---|
| Compleanno | la data di nascita è nota | ogni anno nel giorno del compleanno, alle **10:00** |
| Passeggiate preferite | è un cane e ha almeno una passeggiata preferita salvata (massimo 5) | ogni anno nel giorno di ciascuna preferita, alle 10:00 |
| Foto di questo giorno *(da decidere)* | ci sono foto con data di scatto | nel giorno in cui esistono foto scattate in anni passati, **al massimo una volta a settimana**, alle 10:00 |

Regole comuni:
- Ore 10:00 e non 9:00: non al risveglio, non la sera.
- **Al massimo una notifica-ricordo al giorno per animale**; se due cadono lo
  stesso giorno vince il compleanno, poi la passeggiata.
- Non arrivano mai **prima della data della perdita** né nel giorno stesso.
- Si spengono uno per uno dalla pagina del ricordo, in qualsiasi momento.
- Se la persona spegne le notifiche del telefono o esce dall'account, si
  fermano come tutte le altre.

### 5.2 Cosa mostra la notifica (schermata di blocco)
Solo testo, **nessuna foto** (chi guarda il telefono non deve vedere nulla di
privato; le foto sono in uno spazio protetto e non vanno copiate nella
memoria pubblica del telefono). Testi esatti in §9.

### 5.3 Cosa si apre toccandola
La pagina del ricordo di quell'animale, aperta direttamente su:
- **Compleanno** → la foto profilo grande e, sotto, le foto scattate nei
  giorni dei compleanni passati (± 3 giorni). Se non ce ne sono, solo la foto
  profilo.
- **Passeggiata preferita** → la mappa del percorso, distanza e durata, e le
  foto scattate durante quella passeggiata (la galleria le riconosce già
  dall'ora di scatto).
- **Foto di questo giorno** → le foto scattate in quel giorno negli anni
  passati.

### 5.4 Privacy (il «bypass» richiesto)
- Nessuna foto nella notifica; nessun luogo né percorso nella notifica.
- Il percorso della passeggiata contiene posizioni vicine a casa: resta dove
  è oggi (spazio privato dell'account) e si vede solo dentro l'app, come già
  succede per le passeggiate.
- Nessun dato nuovo esce verso servizi esterni: tutto si calcola sul telefono.
- Nessun consenso nuovo: è una funzione che la persona accende per sé, non è
  marketing (nessun prodotto, nessun negozio, nessun «regalo»).

---

## 6. La pagina del ricordo (una per animale)

Si apre toccando un animale nella lista Ricordi. Dall'alto in basso:

1. **Foto profilo grande**, nome, e una riga: «Dal 3 mar 2012 al 14 nov 2026»
   (o «Fino al 14 nov 2026» se la nascita non è nota).
2. **Foto** — griglia delle foto, con «Aggiungi foto».
3. **Passeggiate preferite** (solo cani che ne hanno) — le preferite con mini
   mappa, e una frase: «Insieme avete fatto 214 passeggiate, 380 km.»
4. **Promemoria del ricordo** — gli interruttori del §3.3, con lo stesso testo.
5. **Documenti e storia clinica** — una riga che apre la cartella come oggi.
6. **Scheda** — una riga che apre i dati (razza, microchip, ecc.) in sola
   lettura; da lì «Modifica» resta possibile (per correggere la data della
   perdita).
7. *(da decidere, §12)* **Una cosa pratica** — riquadro tenue, solo se c'è un
   microchip: «Se Moka era iscritto all'anagrafe degli animali d'affezione,
   di solito il decesso va comunicato: il tuo veterinario o l'ufficio della
   tua ASL o del Comune ti dicono come e entro quando.» *(testo approvato da
   MARKETING e NORMATIVA il 16/11/2026, compliance 17 §B.5: nessun termine in
   giorni perché varia da regione a regione; niente moduli, sanzioni o
   collegamenti; l'app non registra se il decesso è stato comunicato; mai
   mostrato senza microchip)*
8. In fondo, piccoli e separati:
   - **«Riporta tra gli animali»** (testo semplice)
   - **«Elimina per sempre»** (rosso, testo semplice)

Nella **lista Ricordi** le righe non hanno più il cestino: la cancellazione
definitiva si fa solo dalla pagina del ricordo, con conferma.

Il testo «Presto: i vostri momenti più belli…» viene tolto.

---

## 7. Tornare indietro (spostamento fatto per errore)

Due strade:
1. **Subito**: il pulsante «Annulla» nel messaggio di 8 secondi (§3.4).
2. **Dopo**: pagina del ricordo → «Riporta tra gli animali» → conferma.

Effetto: l'animale torna nella lista Animali con tutto; la data della perdita
si cancella; i promemoria del ricordo si spengono; promemoria e farmaci
tornano attivi. Quelli con date nel frattempo passate compaiono come scaduti:
il messaggio di conferma lo dice.

---

## 8. Cosa vede la persona, in breve

| Dove | Prima | Dopo |
|---|---|---|
| Home | l'animale in chip, calendario, agenda | non c'è più, nessuna traccia |
| Animali | l'animale in lista | non c'è; riga «Ricordi» in fondo |
| Promemoria | i suoi promemoria | non ci sono |
| Chat | lo si sceglie per nuove domande | non si sceglie più; le vecchie restano |
| Galleria | la sua cartella | non c'è; le foto sono nella pagina del ricordo |
| Notifiche | vaccini, farmaci, compleanno | solo i ricordi scelti, se scelti |

---

## 9. Testi esatti (italiano; le altre lingue le fa «Revisione traduzioni»)

### Animali
| Chiave (proposta) | Testo |
|---|---|
| `petsListMemoriesRowTitle` | Ricordi |
| `petsListMemoriesRowSubtitle` | Gli animali che hanno condiviso la tua strada |
| `petsListEmptyOnlyMemoriesTitle` | Nessun animale nella lista |
| `petsListEmptyOnlyMemoriesSubtitle` | Quando vorrai, potrai aggiungere un nuovo profilo. |
| `petsListEmptyOnlyMemoriesAction` | Aggiungi un animale |

### Flusso «Sposta nei ricordi»
| Chiave | Testo |
|---|---|
| `petsEditMemorialAction` (esiste) | Sposta nei ricordi |
| `memorialMoveSorry` | Ci dispiace tanto per {name}. |
| `memorialMoveBody` | Qui puoi custodire il suo ricordo. {name} lascerà la lista Animali e non ti manderemo più promemoria, farmaci o auguri per {name}. Profilo, foto, passeggiate e documenti restano nel tuo account finché non li elimini: puoi rivederli e scaricarli quando vuoi. *(allineato al testo suggerito da Normativa, compliance 17 §B.3)* |
| `memorialMoveDateLabel` | Data della perdita |
| `memorialMoveDateHelp` | Se non ricordi il giorno esatto, va bene una data indicativa. |
| `memorialMoveContinue` | Continua |
| `memorialRemindTitle` | Vuoi che Quokka ti aiuti a ricordare? |
| `memorialRemindBody` | Se ti fa piacere, possiamo mandarti un pensiero in alcuni giorni speciali, con le sue foto. Puoi cambiare idea quando vuoi. |
| `memorialRemindBirthday` | Il giorno del compleanno |
| `memorialRemindBirthdayHelp` | Con la foto profilo e le foto dei compleanni passati. |
| `memorialRemindWalks` | Le passeggiate preferite |
| `memorialRemindWalksHelp` | Nel giorno di una passeggiata salvata tra le preferite, con il percorso e le foto di quel giorno. |
| `memorialRemindPhotos` | Le foto di questo giorno |
| `memorialRemindPhotosHelp` | Quando ci sono foto scattate in quel giorno negli anni passati. Al massimo una volta a settimana. |
| `memorialMoveConfirm` | Sposta nei ricordi |
| `memorialMoveDone` | {name} è ora nei Ricordi. |
| `commonUndo` (se non esiste) | Annulla |

### Lista Ricordi e pagina del ricordo
| Chiave | Testo |
|---|---|
| `petsMemoriesTitle` (esiste) | Ricordi |
| `petsMemoriesSubtitle` (cambia) | Gli animali che hanno condiviso la tua strada. |
| `petsMemoriesEmpty` (cambia) | Qui non c'è ancora nessun ricordo. |
| `petsMemoriesWithUsRange` (esiste) | Con noi dal {from} al {to} → **diventa** «Dal {from} al {to}» |
| `petsMemoriesWithUsUntil` (esiste) | Con noi fino al {date} → **diventa** «Fino al {date}» |
| `memorialPagePhotos` | Foto |
| `memorialPageAddPhoto` | Aggiungi foto |
| `memorialPageWalks` | Passeggiate preferite |
| `memorialPageWalksTogether` | Insieme avete fatto {count} passeggiate, {km} km. (plurale: «1 passeggiata») |
| `memorialPageReminders` | Promemoria del ricordo |
| `memorialPageRecords` | Documenti e storia clinica |
| `memorialPageProfile` | Scheda |
| `memorialPageChipNote` *(da decidere; testo approvato da Normativa)* | Se {name} era iscritto all'anagrafe degli animali d'affezione, di solito il decesso va comunicato: il tuo veterinario o l'ufficio della tua ASL o del Comune ti dicono come e entro quando. |
| `memorialPageBirthdayPhotos` | Le foto dei suoi compleanni |
| `memorialPageNoBirthdayPhotos` | Non ci sono ancora foto dei compleanni passati. |
| `memorialPageOnThisDay` | Foto di questo giorno |

> Nota sul testo dell'anagrafe: «iscritto» è maschile. Se il punto 7 viene
> approvato, il testo si sceglie in base al sesso salvato (iscritto /
> iscritta) e, se il sesso non è noto, diventa «Se il microchip di {name} era
> iscritto all'anagrafe…». Per le altre lingue, al posto di «ASL o Comune»:
> «l'ente che tiene l'anagrafe del tuo paese (in Italia, l'ufficio della ASL o
> del Comune)» (indicazione di Normativa).

### Tornare indietro
| Chiave | Testo |
|---|---|
| `memorialRestoreAction` | Riporta tra gli animali |
| `memorialRestoreTitle` | Riportare {name} tra gli animali? |
| `memorialRestoreBody` | Se lo spostamento è stato un errore, {name} torna nella lista Animali con tutti i suoi dati. Tornano attivi anche i promemoria e i farmaci che erano in corso: controllali, alcune date potrebbero essere già passate. |
| `memorialRestoreConfirm` | Riporta tra gli animali |
| `memorialRestoreDone` | {name} è di nuovo tra i tuoi animali. |

### Eliminare per sempre
| Chiave | Testo |
|---|---|
| `petsMemoriesRemoveAction` | Elimina per sempre |
| `petsMemoriesRemoveTitle` (cambia) | Eliminare per sempre il ricordo di {name}? |
| `petsMemoriesRemoveBody` (cambia) | Profilo, foto, passeggiate, documenti e promemoria di {name} verranno cancellati e non si potranno recuperare. Se vuoi tenerne una copia, scarica prima foto e documenti. |
| `petsMemoriesRemoveConfirm` (cambia) | Elimina per sempre |

### Notifiche
| Chiave | Titolo | Testo |
|---|---|---|
| `notificationsMemoryBirthday` | Oggi è il compleanno di {name} | Se ti va, le sue foto sono qui. |
| `notificationsMemoryWalk` | {years, plural, =1{Un anno fa} other{{years} anni fa}}, una passeggiata con {name} | Una delle vostre preferite. Se ti va, puoi rivederla. |
| `notificationsMemoryPhotos` | {years, plural, =1{Un anno fa} other{{years} anni fa}}, con {name} | Ci sono foto di questo giorno. Se ti va, sono qui. |

Parole **escluse** di proposito: «ponte dell'arcobaleno», «angelo»,
«per sempre nel cuore», «avrebbe compiuto», «morto», «defunto»,
«buon compleanno», «auguri», «regalo».

---

## 10. Come si costruisce (fase 2, per chi programma)

### Dati
- Nessuna tabella nuova. Tre colonne nuove in `pet_profiles`, tutte spente di
  partenza:
  `memorial_birthday_reminder boolean not null default false`,
  `memorial_walks_reminder boolean not null default false`,
  `memorial_photos_reminder boolean not null default false`.
- La data della perdita usa la colonna già esistente `memorial_date_label`
  (stesso formato della data di nascita), che finalmente viene **anche letta**.
- SQL idempotente nuovo: `scripts/setup/ricordi_animali.sql`
  (`alter table … add column if not exists`), stesse righe in
  `supabase_schema.sql`. Lo lancia il proprietario.
- Le policy RLS di `pet_profiles` coprono già le colonne nuove; la
  cancellazione account cancella già la riga intera; inventario dati: alla riga
  «Profilo animale» si aggiunge «data della perdita, scelte dei promemoria del
  ricordo».
- Backend: nessuna rotta nuova (l'app scrive `pet_profiles` direttamente, come
  oggi, protetta da RLS). Il consenso alla cartella clinica si spegne con la
  rotta già esistente `PUT /pets/{pet_id}/medical-record-consent`.

### App (solo file di animali, promemoria, notifiche + il minimo necessario)
- `pets/`: modello e store (lettura data, 3 scelte), lista Animali (riga in
  fondo, togliere icona in alto, stato vuoto), pagina Ricordi, **nuova pagina
  del ricordo**, **nuovo flusso** «Sposta nei ricordi» (2 passi), ripristino.
- `reminders/`: `ReminderEntry` riceve anche `petId` (già presente nel
  database) così il filtro non dipende dal nome; filtro «animale nei ricordi»
  in lista Promemoria, scheda, completamento «Fatto?».
- `home/` e `app/shell/`: **solo** il filtro dei promemoria dei ricordi
  (una riga ciascuno) e l'apertura della pagina del ricordo dal tocco della
  notifica. Avviso la sessione UI/UX prima di toccare Home.
- `notifications/`: nuova categoria «ricordi» nel piano notifiche, con le
  regole del §5.1; tocco `memory:<id>` → pagina del ricordo.
- `dog_walks/`: chiusura silenziosa di una passeggiata in corso; lettura delle
  preferite e delle foto per la pagina del ricordo.
- Nessun permesso Android nuovo; nessuna build APK.

### Controlli
- Test del piano notifiche: niente vaccini/farmaci/compleanno normale dopo la
  perdita; i ricordi solo se accesi, mai prima della data, max 1 al giorno,
  foto max 1 a settimana, 29 febbraio.
- Test filtri: promemoria dell'animale nei ricordi assenti in Home, lista,
  scheda; presenti di nuovo dopo il ripristino.
- Test del flusso: data futura rifiutata, passo 2 saltato se nulla è possibile,
  «Annulla» ripristina.
- Suite completa: pytest, ruff, mypy, `flutter analyze`, test Flutter.
- Da verificare in fase 2: che «Elimina per sempre» cancelli anche i file foto
  nello spazio di archiviazione e non solo le righe (le righe collegate si
  cancellano già in cascata).

### Coordinamento
- Chiavi di testo nuove/cambiate (§9) → sessione «Revisione traduzioni EN ES
  DE FR».
- Testo anagrafe: già approvato da MARKETING e NORMATIVA (16/11/2026).
- Quando il codice è su main → avvisare MARKETING e NORMATIVA (scrive le righe
  di it/02 §3 e §7) e Sicurezza (riga dell'inventario dati).
- Verificare che «Scarica i miei dati» comprenda le 3 colonne nuove.
- Righe in Home e shell → avviso alla sessione UI/UX.

---

## 11. Cosa NON facciamo (di proposito)

- Nessun promemoria per l'**anniversario della perdita**: per molte persone è
  il giorno più difficile; non lo proponiamo (si può aggiungere solo se il
  proprietario lo chiede).
- Nessuna scheda «ricordo» in Home e nessun ricordo «a sorpresa».
- Nessun invito a prendere un nuovo animale, nessun prodotto, nessun negozio.
- Nessuna foto nelle notifiche.
- Nessuna condivisione del ricordo (né social né collegamento): tutto resta
  privato.
- Nessuna IA che «riporta in vita» voce o immagine, nessun testo scritto
  dall'IA.
- Nessuna informazione su sepoltura o cremazione (servirebbero fonti
  ufficiali, Regolamento CE 1069/2009) e nessuna promessa di supporto
  psicologico.

Questi limiti seguono il parere di MARKETING e NORMATIVA
(`docs/compliance/17_nuove_sezioni_around_the_world_e_ricordi.md`, parte B):
nessun consenso nuovo, nessun avviso legale speciale.

---

## 12. Decisioni che chiedo al proprietario

1. **«Le foto di questo giorno»** (foto scattate nello stesso giorno negli anni
   passati): la includo come terza voce, spenta e al massimo una volta a
   settimana? *Consiglio: sì — è come ho capito la frase «altre foto al
   compleanno di quella foto».*
2. **Riquadro anagrafe/microchip** nella pagina del ricordo (§6 punto 7):
   lo includo? *Consiglio: sì, è un dovere del proprietario e rientra nella
   missione dell'app; testo rivisto da Normativa, senza scadenze in giorni.*
3. **Chat passate** dell'animale: restano nella lista Chat come oggi, o le
   sposto dentro la pagina del ricordo? *Consiglio: restano dove sono — la
   chat è di un'altra sessione e spostarle è un lavoro a parte.*
4. **Testi del §9**: vanno bene così? Ogni parola si può cambiare.
