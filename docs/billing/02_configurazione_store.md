# Abbonamenti — configurazione, variabili d'ambiente, checklist

Nessuna di queste operazioni è stata fatta: richiedono il proprietario degli account sviluppatore. Non attivare pagamenti reali finché la sezione 7 non è completa.

## Identificativi prodotto (default, sovrascrivibili con `BILLING_CATALOG_JSON`)
| Piano | Periodo | Apple product id | Google subscription / base plan | Prezzo IT indicativo |
| --- | --- | --- | --- | ---: |
| Plus | mensile | `net.quokkapet.plus.monthly` | `quokka_plus` / `monthly` | €4,59 |
| Plus | annuale | `net.quokkapet.plus.yearly` | `quokka_plus` / `yearly` | €45,99 |
| Pro | mensile | `net.quokkapet.pro.monthly` | `quokka_pro` / `monthly` | €8,59 |
| Pro | annuale | `net.quokkapet.pro.yearly` | `quokka_pro` / `yearly` | €85,99 |
| Ultra | mensile | `net.quokkapet.ultra.monthly` | `quokka_ultra` / `monthly` | €15,59 |
| Ultra | annuale | `net.quokkapet.ultra.yearly` | `quokka_ultra` / `yearly` | €155,99 |

L'app mostra sempre il prezzo restituito dallo store. Formato di `BILLING_CATALOG_JSON`: lista di oggetti `{plan, period, apple_product_id, google_product_id, google_base_plan_id}`.

## Variabili d'ambiente del backend
| Variabile | Sviluppo locale | Sandbox (TestFlight / Internal testing) | Produzione | Segreto |
| --- | --- | --- | --- | --- |
| `BILLING_ENABLED` | `false` (o `true` con doppi) | `true` | `true` | no |
| `BILLING_ACCOUNT_TOKEN_SECRET` | valore casuale locale | casuale 32+ byte | casuale 32+ byte, **diverso** dalla sandbox, mai ruotato dopo il lancio | **sì** |
| `BILLING_STORE_ENVIRONMENT` | `sandbox` | `sandbox` | `production` | no |
| `BILLING_VERIFICATION_TOLERANCE_HOURS` | 24 | 24 | 24 (max 72) | no |
| `BILLING_CATALOG_JSON` | vuoto | vuoto o override | vuoto o override | no |
| `BILLING_ADMIN_TEST_GRANTS` | `true` se serve | `true` se serve | ignorato (sempre rifiutato) | no |
| `BILLING_PLAN_OVERRIDES` | account demo/team | idem | account del team e demo (`email:piano,...`): piano fisso senza store, niente ricavi | no (ma dati personali: solo nell'ambiente) |
| `SUBSCRIPTION_TEST_PLAN` | vuoto | vuoto | vuoto (altrimenti tutti sul piano di test) | no |
| `APPLE_BUNDLE_ID` | — | bundle id app | bundle id app | no |
| `APPLE_ISSUER_ID`, `APPLE_KEY_ID` | — | da App Store Connect | idem | no (ma riservati) |
| `APPLE_PRIVATE_KEY` | — | contenuto `.p8` (In-App Purchase key) | idem | **sì** |
| `APPLE_ROOT_CERTIFICATES` | — | Apple Root CA G3 (PEM/base64) | idem | no (pubblico) |
| `GOOGLE_PLAY_PACKAGE_NAME` | — | package Android | idem | no |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | — | JSON service account | idem | **sì** |
| `GOOGLE_PUBSUB_AUDIENCE` | — | URL della rotta `/billing/google/notifications` | idem | no |
| `GOOGLE_PUBSUB_SERVICE_ACCOUNT` | — | e-mail del service account di push | idem | no |
| `ADMIN_SCHEDULER_SECRET` | — | già esistente, usato anche da `/billing/reconcile` | idem | **sì** |

Tutti i segreti solo nelle variabili di Vercel (o equivalente), mai nel repository, nei log o nelle note di rilascio.

## 1. App Store Connect
- [ ] Accordo "Paid Applications" firmato, dati bancari e fiscali.
- [ ] Gruppo di abbonamenti "Quokka" con 6 prodotti (tabella), livelli: Ultra > Pro > Plus (ordine del gruppo = upgrade/downgrade).
- [ ] Prezzi per paese partendo dai prezzi IT; localizzazioni di nome e descrizione.
- [ ] **Nessuna** introductory offer attivata automaticamente (la prova è quella dell'app); decidere con App Review la gestione della prova di 14 giorni (vedi 01 §Vincoli).
- [ ] Capability "In-App Purchase" sul bundle id; StoreKit Configuration file per i test locali in Xcode.
- [ ] Link EULA/Termini e Privacy nella scheda app e nel paywall.

## 2. Google Play Console
- [ ] Profilo pagamenti attivo, account merchant.
- [ ] 3 abbonamenti (`quokka_plus`, `quokka_pro`, `quokka_ultra`) ciascuno con base plan `monthly` e `yearly`, rinnovo automatico.
- [ ] Nessuna offerta di prova attiva per default.
- [ ] Periodo di tolleranza e account hold configurati (es. 7 giorni + 30 giorni).
- [ ] Licence testers (account Google di test, mai reali dei clienti).

## 3. Notifiche
- [ ] Apple: URL produzione e sandbox delle App Store Server Notifications **V2** → `https://<api>/billing/apple/notifications` (sandbox su un deployment con `BILLING_STORE_ENVIRONMENT=sandbox`). Usare "Request a Test Notification" per la prova.
- [ ] Google: topic Pub/Sub, permesso publisher a `google-play-developer-notifications@system.gserviceaccount.com`, sottoscrizione **push** autenticata (OIDC) verso `/billing/google/notifications` con audience = `GOOGLE_PUBSUB_AUDIENCE`. In Play Console → Monetizzazione → RTDN: topic e "Send test notification".
- [ ] Riconciliazione: aggiungere allo scheduler esistente una chiamata `POST /billing/reconcile` con header `X-VetApp-Scheduler` (es. ogni 6 ore).

## 4. Credenziali e autorizzazioni API
- [ ] App Store Connect → Users and Access → Integrations → In-App Purchase key (`.p8`), annotare Key ID e Issuer ID.
- [ ] Google Cloud: service account dedicato, Google Play Android Developer API abilitata; in Play Console invitare il service account con "Visualizzare dati finanziari" e "Gestire ordini e abbonamenti". Nessun altro permesso.
- [ ] Rotazione: chiavi in un vault del proprietario; procedura di revoca annotata in `docs/security/`.

## 5. Variabili d'ambiente del backend
- [ ] Impostare la tabella sopra su un deployment **sandbox** distinto.
- [ ] Eseguire `supabase/migrations/20261121180000_store_billing.sql` (idempotente) e verificare RLS con `scripts/security/check_anon_exposure.py`.

## 6. TestFlight e Google Internal Testing
- [ ] Build `--release` firmata con `in_app_purchase` (Android: permesso BILLING documentato in `docs/compliance/05`).
- [ ] Apple sandbox: account sandbox tester, rinnovi accelerati (mensile = 5 min); provare acquisto, upgrade, downgrade, disdetta, scadenza, rimborso (Transaction Manager/Xcode), Ask to Buy (pendente), ripristino su secondo dispositivo, reinstallazione.
- [ ] Google: licence tester, carte di test "sempre approvata/rifiutata/lenta" (pendente), upgrade con `linkedPurchaseToken`, account hold, revoca da Play Console.
- [ ] Per ogni caso: controllare `/admin/billing/users/<id>` e `store_events`.
- [ ] Tentativo di uso dello stesso acquisto da un secondo account Quokka: deve dare "collegato a un altro account".

## 7. Verifica finale prima del rilascio
- [ ] Tutti i casi della sezione 6 superati in sandbox su entrambi gli store.
- [ ] `docs/security/05_checklist.md` sezioni A e B.
- [ ] Inventario fornitori aggiornato (fatto il 2026-11-21, da confermare col legale).
- [ ] Testi del paywall rivisti per 3.1.2 e Subscriptions policy (prezzo, durata, rinnovo, disdetta, link Termini/Privacy).
- [ ] `BILLING_STORE_ENVIRONMENT=production`, segreti di produzione distinti, `BILLING_ADMIN_TEST_GRANTS` non impostato.
- [ ] Decisione scritta del proprietario per attivare i pagamenti reali.
