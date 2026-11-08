# Mettere online quokkapet.net: i passi per il proprietario

Servono circa 20 minuti. Non si tocca nessun codice. Prima di cominciare: il sito è pronto in `apps/site` ed è già sul repository (ramo `main`, dopo il passaggio dell'Orchestratore).

## A. Creare il sito su Vercel (gratis)

1. Entra su vercel.com con il tuo account e tocca **Add New… → Project**.
2. Scegli il repository di Quokka (GitHub) e tocca **Import**.
3. Compila così, e nient'altro:
   - **Project Name**: `quokka-site` (diverso dal progetto del backend).
   - **Root Directory**: tocca *Edit* e scrivi `apps/site`.
   - **Framework Preset**: *Other*.
   - Build Command, Output Directory, Install Command: lasciali vuoti. Environment Variables: nessuna.
4. Tocca **Deploy**. Dopo un minuto compare un indirizzo del tipo `quokka-site-xxxx.vercel.app`: aprilo e controlla che il sito si veda.

## B. Collegare il dominio

1. Nel progetto `quokka-site`: **Settings → Domains → Add**.
2. Scrivi `quokkapet.net` e conferma. Vercel propone anche `www.quokkapet.net`: accetta (di solito reindirizza `www` al dominio principale).
3. Vercel mostra una tabella **«DNS Records»** con i record da inserire. **Copia i valori che mostra Vercel, non quelli scritti qui.** In genere sono due:

   | Tipo | Nome (Name / Host) | Valore |
   |---|---|---|
   | `A` | `@` (il dominio nudo) | indirizzo IP che indica Vercel (storicamente `76.76.21.21`) |
   | `CNAME` | `www` | il nome che indica Vercel (storicamente `cname.vercel-dns.com`) |

## C. Inserire i record dove sta il DNS del dominio

Il DNS si gestisce nel sito dove hai comprato il dominio (o dove hai spostato i "nameserver", per esempio Cloudflare).

1. Entra lì e cerca **DNS** (a volte «Zona DNS» o «Gestione DNS») di `quokkapet.net`.
2. Se ci sono già record `A` o `CNAME` per `@` o `www` (per esempio quelli di una pagina di parcheggio del registrar), **eliminali**: due indirizzi diversi per lo stesso nome non funzionano.
3. Aggiungi i due record della tabella di Vercel. Se il DNS è su **Cloudflare**, metti la nuvoletta su **grigio** («Solo DNS»).
4. Salva. Torna su Vercel: dopo da 1 minuto a qualche ora, accanto al dominio compare **Valid Configuration**.
5. Il certificato HTTPS (il lucchetto) è automatico. Apri `https://quokkapet.net/it/privacy/` e controlla.

## Dopo

- Il sito resta in **modalità bozza** (non compare su Google) finché non decidi di pubblicarlo davvero. Quando i testi legali sono definitivi lo dici all'Orchestratore: si cambia un'impostazione e si ricarica.
- Indirizzi da usare in Google Play: informativa `https://quokkapet.net/it/privacy/`, cancellazione account `https://quokkapet.net/it/cancellazione-account/`.
- Se qualcosa non va, mandami una schermata della tabella DNS di Vercel e di quella del registrar.
