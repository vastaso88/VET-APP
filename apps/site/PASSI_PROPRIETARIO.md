# Mettere online quokkapet.net: i passi per il proprietario

Il sito sta su **Firebase Hosting** (Google), piano gratuito: nessun costo, ammesso anche per un'attività commerciale. Vercel resta per il server dell'app: il suo piano gratuito (Hobby) vale solo per uso non commerciale, quindi non va bene per il sito di una società. Il dominio resta su **Aruba**, posta compresa.

Cosa si pubblica oggi: solo le pagine pronte, cioè la **home** di Quokka con «presto su Google Play», i contatti e, in fondo, la riga con i dati della società. Informativa privacy, termini, assistenza e cancellazione dell'account si aggiungono da sole quando la Normativa chiude i loro punti aperti (il generatore le pubblica appena sono pronte, mai prima).

> I nomi dei menu cambiano ogni tanto: se una voce ha un nome un po' diverso, cerca quella che gli somiglia. Non scrivere mai password in chat.

## A. Dati della società (restano fuori dal repository)

Servono per la riga in fondo al sito (art. 2250 c.c.; la partita IVA va in home per l'art. 35 DPR 633/1972). Li trovi nella visura camerale:

- codice fiscale / partita IVA;
- ufficio del registro delle imprese e numero REA (per esempio «RE-123456»);
- indirizzo completo della sede legale, con CAP.

Me li scrivi in chat e li metto nel file `.local/site/owner.env` di questo computer, che non va mai su GitHub. La ragione sociale e il capitale sociale versato li ho già dall'atto costitutivo.

## B. Pubblicazione (la faccio io)

Dal computer, con l'account Firebase già collegato:

```bash
python apps/site/tools/build.py --release --partial --env-file .local/site/owner.env --out apps/site/dist
cd apps/site
npx firebase-tools deploy --only hosting --project vetapp-test2
```

Il sito compare subito su `https://quokkapet.web.app`. Poi si collega il dominio (parte C).

## C. Collegare quokkapet.net (Firebase + Aruba)

### C1. Su Firebase
1. Apri console.firebase.google.com, progetto **VetApp Test2**, voce **Hosting**.
2. Nel sito **quokkapet** tocca **Aggiungi dominio personalizzato** e scrivi `quokkapet.net`.
3. Firebase mostra dei record: di solito un `TXT` (prova che il dominio è tuo) e uno o due record `A` (indirizzi IP). **Copia i valori che mostra Firebase.**
4. Ripeti con `www.quokkapet.net`, scegliendo di **reindirizzarlo** a `quokkapet.net`.

### C2. Su Aruba
1. Area clienti Aruba → **Domini** → `quokkapet.net` → **Gestione DNS**.
2. **Prima cancella** gli eventuali record `A` del dominio senza `www` e il record `A` o `CNAME` di `www` messi da Aruba (pagina di cortesia). **Non toccare** i record `MX` e i `TXT` della posta.
3. Aggiungi i record mostrati da Firebase: per il dominio senza `www` il nome host è **vuoto** (o `@`).
4. Salva. Servono da 15 minuti a qualche ora; Firebase poi crea da solo il certificato HTTPS (il lucchetto), a volte entro 24 ore.

## D. Verifica del sito per Google Play (Search Console)

Google Play chiede che il sito dell'organizzazione sia **verificato in Search Console** con lo **stesso account Google della Play Console** (se è un altro account, quello riceve una richiesta da approvare).

1. Con l'account della Play Console apri search.google.com/search-console → **Aggiungi proprietà** → **Dominio** → `quokkapet.net`.
2. Google mostra un record `TXT` (`google-site-verification=…`): aggiungilo su Aruba come in C2 (nome host vuoto o `@`), **senza** cancellare l'eventuale TXT di Firebase. Torna su Search Console e tocca **Verifica** (se fallisce, riprova dopo un'ora).
3. In Play Console → **Dettagli account** (o la schermata che chiedeva il sito): sito `https://quokkapet.net`, poi la richiesta di verifica del sito.

## Dopo

- **Pulsante «Scarica»**: quando Google approva l'app, metti il link della scheda Play in `PLAY_STORE_URL` dentro `apps/site/tools/pages_it.py` e ripubblica (parte B): la home mostra il pulsante al posto di «presto su Google Play».
- **Pagine legali**: quando la Normativa chiude i punti aperti di informativa, termini, assistenza e cancellazione account, la stessa pubblicazione le aggiunge. Gli indirizzi per Play Console saranno `https://quokkapet.net/it/privacy/` e `https://quokkapet.net/it/cancellazione-account/`.
- Se qualcosa non va, mandami una schermata della tabella DNS di Aruba e di quella di Firebase (senza password).
