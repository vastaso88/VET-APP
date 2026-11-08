# Mettere online quokkapet.net: i passi per il proprietario

Servono circa 30 minuti, divisi in tre parti. Non si tocca nessun codice. Il dominio è registrato su **Aruba**.

> I nomi dei menu di Aruba e di Vercel cambiano ogni tanto: se una voce ha un nome un po' diverso, cerca quella che gli somiglia. Non scrivere mai password in chat.

## A. Creare il sito su Vercel (gratis)

1. Entra su vercel.com e tocca **Add New… → Project**.
2. Scegli il repository di Quokka (GitHub) e tocca **Import**.
3. Compila così, e nient'altro:
   - **Project Name**: `quokka-site` (diverso dal progetto del backend).
   - **Root Directory**: tocca *Edit* e scrivi `apps/site`.
   - **Framework Preset**: *Other*. Lascia Build Command e Output Directory come sono già compilati.
4. Prima di toccare **Deploy**, apri **Settings → General** e controlla che l'opzione **Include source files outside of the Root Directory in the Build Step** sia **attiva**.
5. Tocca **Deploy**. Finché i testi legali hanno ancora segnaposto aperti, **il deploy di produzione fallisce**: è voluto, serve a non pubblicare per sbaglio una bozza. Nel registro del deploy compare l'elenco di cosa manca. I deploy di prova (altri rami) riescono e restano in bozza.

## B. Dati dell'azienda (restano fuori dal repository)

I dati della società (ragione sociale, sede, partita IVA, ecc.) compaiono nel sito ma non nei file del progetto, che sono pubblici. Si inseriscono solo su Vercel:

1. Nel progetto: **Settings → Environment Variables**.
2. Per ogni voce dell'elenco qui sotto: **Key** = il nome, **Value** = il dato, **Environments** = solo *Production*, poi **Save**.

   | Key (nome esatto) | Cosa va nel Value |
   |---|---|
   | `QUOKKA_SITE_TITOLARE` | Ragione sociale |
   | `QUOKKA_SITE_SEDE` | Sede legale |
   | `QUOKKA_SITE_CF_PIVA` | Codice fiscale / partita IVA |
   | `QUOKKA_SITE_REA_REGISTRO_IMPRESE_SE_SOCIETA` | Numero REA e registro delle imprese |
   | `QUOKKA_SITE_PEC` | Indirizzo PEC |
   | `QUOKKA_SITE_DPO_O_NON_DESIGNATO` | «Non designato» (salvo diversa indicazione della Normativa) |
   | `QUOKKA_SITE_DATA` | Data dell'ultimo aggiornamento dei testi (per esempio «1 dicembre 2026») |

   Ogni valore deve stare su una sola riga e non contenere questi simboli: `[ ] | * < >` e l'apice rovesciato. Se ne contiene uno, il deploy si ferma e lo dice (senza scrivere il valore).
3. L'elenco definitivo di cosa mostrare lo stabilisce la sessione Normativa: se ne cambia la lista, il deploy lo dice. Il file `apps/site/.env.example` ha sempre l'elenco aggiornato.
4. Dopo aver salvato le variabili: **Deployments →** sul deploy più recente **… → Redeploy**.

## C. Collegare il dominio (Vercel + Aruba)

### C1. Su Vercel
1. Nel progetto `quokka-site`: **Settings → Domains → Add**.
2. Scrivi `quokkapet.net` e conferma. Accetta anche `www.quokkapet.net` (di solito rimanda al dominio principale).
3. Vercel mostra una tabella **«DNS Records»**. **Copia i valori che mostra Vercel**: quelli scritti qui sotto sono solo un esempio.

   | Tipo | Nome (Host) | Valore (esempio) |
   |---|---|---|
   | `A` | vuoto oppure `@` (è il dominio senza `www`) | un indirizzo IP, di solito `76.76.21.21` |
   | `CNAME` | `www` | un nome tipo `cname.vercel-dns.com` (può essere uno specifico del tuo progetto) |

### C2. Su Aruba
1. Entra nell'**Area clienti** Aruba (admin.aruba.it) con il tuo account.
2. Vai su **Domini** (o «I miei prodotti → Domini») e **clicca su `quokkapet.net`**.
3. Cerca **Gestione DNS** (a volte «Pannello di gestione DNS» o «Gestione DNS avanzata»).
4. **Prima cancella i record vecchi**: se ci sono già un record `A` per il dominio senza `www` o un `CNAME` per `www` (per esempio quelli di una pagina di cortesia di Aruba), eliminali. Due indirizzi diversi per lo stesso nome non funzionano. **Non toccare** i record `MX` e `TXT` (servono alla posta).
5. Aggiungi il record `A`: **Aggiungi record**, tipo **A**, nome host **vuoto** (se il pannello non accetta il vuoto, scrivi `@`), valore = l'indirizzo IP che ha mostrato Vercel, **Salva**.
6. Aggiungi il record `CNAME`: tipo **CNAME**, nome host **`www`**, valore = il nome che ha mostrato Vercel (se il pannello lo chiede, termina con un punto), **Salva**.
7. Se non trovi «Gestione DNS» o dice che i DNS non sono gestiti da Aruba, scrivimi: significa che i *nameserver* del dominio puntano altrove e i record vanno inseriti lì.

### C3. Aspettare e controllare
- Aruba applica le modifiche quasi subito, ma in giro per internet possono servire **da 15 minuti a qualche ora** (raramente fino a 24-48 ore). Non c'è nulla da fare, solo aspettare.
- Torna su Vercel → **Settings → Domains**: accanto a `quokkapet.net` deve comparire **Valid Configuration**. Se resta «Invalid», aspetta e ricarica la pagina.
- Il certificato HTTPS (il lucchetto) è automatico, arriva da solo dopo la verifica.
- Apri `https://quokkapet.net/it/privacy/` e controlla.

## Dopo

- Finché la Normativa non toglie i segnaposto dai testi, il sito di produzione non si pubblica: è la protezione che abbiamo voluto. Nel frattempo funziona l'indirizzo provvisorio `*.vercel.app` delle anteprime, che resta in bozza e non compare su Google.
- Indirizzi da usare in Google Play: informativa `https://quokkapet.net/it/privacy/`, cancellazione account `https://quokkapet.net/it/cancellazione-account/`.
- Se qualcosa non va, mandami una schermata della tabella DNS di Vercel e di quella di Aruba (senza password).
