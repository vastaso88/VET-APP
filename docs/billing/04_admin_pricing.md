# Admin PRICING — listini e abilitazioni per piano

Stato: implementato in repository; richiede migrazione SQL e deployment coordinato.

La pagina /pricing nel portale Next.js gestisce prezzi obiettivo per paese ISO-3166,
store Apple/Google, piano Plus/Pro/Ultra, periodicità, valuta e importo in centesimi.
Gestisce inoltre la quota numerica e la checkbox di attivazione per le cinque
funzionalità già controllate nel backend: max_pets, max_chats_per_pet,
daily_questions, max_devices, daily_sonnet_answers.

Ogni salvataggio e cancellazione verifica un nuovo TOTP con Supabase Auth sul
backend FastAPI. L'admin deve essere autenticato e avere email verificata; il
backend utilizza un rate limit persistente e consuma atomicamente il digest
HMAC nello stesso registro anti-replay già usato per i cambi di piano utente.
I codici TOTP non sono mai conservati. Tutte le modifiche entrano in un audit
immutabile (attore, data, valore precedente e valore successivo).

I listini salvati sono SOLO BOZZE INTERNE. Non cambiano App Store Connect o
Google Play Console, e non costituiscono attestazione di prezzi effettivi.
L'app deve visualizzare esclusivamente i prezzi restituiti dagli store.
Non esiste checkout web.

I limiti effettivi vengono letti dalla API FastAPI con cache fino a 15 secondi.
La prova di 14 giorni eredita le quote del Pro. Il trigger Supabase
caller_max_pets applica lo stesso tetto alle scritture dirette Flutter; le altre
quote sono controllate dai servizi già esistenti. Non esponiamo checkbox per
funzioni non ancora dotate di una verifica server-side specifica.

## Deployment

1. Verificare l'applicazione di scripts/setup/plan_access_rules.sql e di
   20261121222500_admin_plan_totp.sql.
2. Applicare supabase/migrations/20261121230000_admin_pricing.sql.
3. Distribuire insieme API FastAPI e portale Next.js con Vercel.
4. Verificare con account amministrativo di test: codice valido, codice errato,
   replay, throttle, salvataggio prezzo, modifica quota e audit.
5. Verificare GET /subscription/status e le scritture dirette dei pet con
   piani Plus/Pro/Ultra, con trial, e con la quota animali disattivata.
6. Verificare prezzi pubblicati e regole di aumento nei rispettivi store.

Le migrazioni SQL non vengono eseguite automaticamente da un merge GitHub.
