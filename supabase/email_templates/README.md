# E-mail di Supabase Auth in it / en / de / fr / es

Pronte da incollare in **Dashboard → Authentication → Email Templates**. Nulla qui scrive su Supabase.
I file `.html` sono generati da `scripts/i18n/build_email_templates.py` (modifica lo script, poi
`python scripts/i18n/build_email_templates.py`; `--check` dice se i file sono vecchi). I soggetti sono in `subjects.txt`.

| File | Template nel dashboard | Usato dall'app oggi |
|---|---|---|
| `confirm_signup.html` | Confirm signup | sì (registrazione) |
| `recovery.html` | Reset Password | sì (`resetPasswordForEmail`) |
| `email_change.html` | Change Email Address | no (la UI non cambia l'email), ma il template è pronto |
| `magic_link.html` | Magic Link | no (l'accesso è con password), pronto |
| `reauthentication.html` | Reauthentication | no, pronto (mostra `{{ .Token }}`) |
| — | Invite user | non usato: lasciare il default |

## Come viene scelta la lingua

Supabase ha **un solo template per tipo di email, per tutto il progetto**: non esiste "un template per lingua".
Ogni file contiene quindi le cinque lingue in un `{{ if … }}{{ else if … }}{{ else }}` e sceglie dal
metadato utente `preferred_locale`:

- scritto **alla registrazione** dall'app (`signUpWithPassword` in `supabase_auth_remote_data_source.dart`:
  `preferred_locale` = `it|en|de|fr|es`, più `preferred_locale_variant` = `en-GB`, `de-CH`, …);
- tenuto aggiornato da `PUT /account/preferences` (`SupabaseAuthProvider.update_preferred_locale`), quindi
  chi cambia lingua dopo riceve le email nella lingua nuova;
- se il metadato manca (account vecchi, registrati prima di MULTILANG) vale **italiano**.

Il metadato dice solo la lingua, non la variante: en-GB/US/AU ricevono lo stesso inglese, de/de-AT/de-CH lo stesso tedesco
("Sie"), fr/fr-BE/fr-CH lo stesso francese ("vous"). Le email non contengono valute, date o unità, quindi non serve altro.

## Cosa configurare (azioni dell'utente, serve il login umano al dashboard)

1. **Incolla corpo e soggetto**: per ogni tipo, *Subject heading* = riga **A)** di `subjects.txt`, *Message body* = il file `.html`.
   Usa **Preview**: se il soggetto mostra il codice `{{ if … }}` invece del testo, usa la riga **B)** (soggetto neutro it · en).
   Il corpo supporta sempre i template Go.
2. **Verifica con account di prova** (uno per lingua, registrati dall'app con quella lingua; email di test, non dati personali):
   conferma registrazione e recupero password. Controllare anche un utente **senza** `preferred_locale`: deve arrivare in italiano e non
   fallire. Se `.Data` non fosse disponibile nel progetto, la mail uscirebbe in italiano: in quel caso segnalarlo, non c'è altra
   strada con un template unico (alternativa: un'Auth Hook "Send Email" lato backend, più lavoro).
3. **SMTP personalizzato** (Authentication → SMTP Settings). Il mittente predefinito di Supabase è limitato (pochissime email
   all'ora, solo membri del team) e non adatto a una app pubblica. Servono: un provider SMTP, un dominio con **SPF, DKIM e DMARC**,
   un indirizzo mittente tipo `no-reply@<dominio>`.
4. **Mittente**: Supabase permette *un solo* "Sender name" per progetto, quindi non è localizzabile: usare `VetApp`
   (non è una parola da tradurre). Il *soggetto* è invece localizzato (punto 1).
5. **URL** (già descritti in `docs/auth/01_brainstorm.md`): Site URL, Redirect URLs (`https://…/**`, `http://localhost:8090/**`,
   `vetapp://auth-callback`). Con più domini per paese i link restano gli stessi: la lingua della pagina è quella dell'app.
6. **Authentication → Providers → Email**: tenere *Confirm email* attivo; per il cambio email *Secure email change* manda il
   link a entrambi gli indirizzi (il template è lo stesso, con `{{ .Email }}` e `{{ .NewEmail }}`).

## Limiti noti

- Il cuore dell'invio (rate limit, consegna) dipende dal provider SMTP, non dal template.
- Gli scanner di link di alcuni client di posta possono "consumare" il link monouso: se succede in produzione, passare ai link con
  `token_hash` (`{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=signup`) e gestirli nell'app.
- Testi senza nome dell'utente di proposito (il nome può mancare).
- Le traduzioni sono bozze da rileggere da un madrelingua prima del lancio (stesso trattamento delle ARB).
