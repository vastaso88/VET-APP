# Abbonamenti App Store / Google Play — architettura

Stato: **implementato e testato con doppi degli store; non ancora collaudato in sandbox, non attivo in produzione.**

## Principio
Il backend è l'unica fonte dei diritti. Un piano a pagamento nasce solo da:
1. una verifica server-side con l'API dello store (App Store Server API, Google Play Developer API `subscriptionsv2`), oppure
2. una notifica firmata dallo store (App Store Server Notifications V2 con catena x5c fino ad Apple Root CA G3; RTDN via Pub/Sub push con token OIDC Google).

Ciò che l'app dichiara su un pagamento non è mai creduto. `POST /subscription/select-plan` non concede più nessun piano (409 `plan_change_requires_store_purchase`; nel test pubblico risponde come prima senza salvare nulla).

## Flusso
```
App (in_app_purchase)            Backend FastAPI                       Store
 GET /billing/catalog  ───────▶  id prodotto centralizzati
 queryProductDetails   ─────────────────────────────────────────────▶ prezzi localizzati
 GET /billing/account-token ──▶  HMAC(secret, owner_id) → UUID
 buy(applicationUserName=token) ────────────────────────────────────▶ appAccountToken / obfuscatedAccountId
 purchaseStream: purchased
 POST /billing/purchases/verify ▶ verifica con l'API dello store ────▶
                                  token == quello dell'utente?  sottoscrizione già di un altro? → 409
                                  salva store_subscriptions, aggiorna subscriptions.plan
                                  Google: acknowledge server-side
 ◀── complete_transaction=true   (pendente: false, la transazione resta aperta)
 completePurchase()
                                  POST /billing/apple/notifications  ◀── ASSN V2 (firmate)
                                  POST /billing/google/notifications ◀── Pub/Sub push (OIDC)
                                  POST /billing/reconcile (scheduler) ──▶ ricontrollo periodico
```

## Componenti
| Livello | File |
| --- | --- |
| Dominio | `packages/core/domain/subscription/store.py` (stati, catalogo prodotti, `grants_access`, `best_plan`) |
| Porte | `packages/core/application/ports/store_billing.py` |
| Servizio | `packages/core/application/services/store_billing.py` (`StoreBillingService`) |
| Apple | `packages/infrastructure/billing/apple_app_store.py`, `jose.py` (ES256, catena x5c) |
| Google | `packages/infrastructure/billing/google_play.py` (OAuth service account RS256, subscriptionsv2, acknowledge, OIDC Pub/Sub) |
| Persistenza | `packages/infrastructure/persistence/supabase/supabase_store_billing.py`, doppio in memoria |
| Rotte | `apps/api/routes/billing.py`, admin in `apps/api/routes/admin.py` (`/admin/billing/*`) |
| Migrazione | `supabase/migrations/20261121180000_store_billing.sql` (fonte; la copia richiesta dal setup è `scripts/setup/store_billing.sql`, deve restare identica: lo verifica `tests/unit/test_billing_migration_copy.py`, che indica quale file copiare sull'altro) |
| Flutter | `lib/features/billing/data/store_billing_controller.dart`, `presentation/widgets/store_subscription_section.dart` |
| Admin portal | `apps/admin_portal/app/billing/page.tsx` |

## Regole
- **Identità**: ogni sottoscrizione dello store (`store`, `store_subscription_id`) appartiene a un solo account (vincolo unico). Il token d'acquisto è un HMAC dell'id utente (non reversibile, non è l'id Supabase). Acquisto senza token o con il token di un altro → rifiutato; una sottoscrizione già legata a un account non si sposta (anomalia `claim_attempt_by_another_account` registrata). Non esiste un trasferimento automatico: un eventuale trasferimento si fa a mano dal team dopo verifica (procedura da scrivere prima del lancio).
- **Trial**: i 14 giorni restano quelli di `subscriptions.trial_ends_at`, creati alla prima lettura dal backend; legati all'account, quindi reinstallare o cambiare dispositivo non li riavvia. Le offerte di prova degli store non vengono mai scelte dall'app (`_productKey` salta le offerte promozionali).
- **Piano**: `subscriptions.plan` è lo specchio del miglior abbonamento verificato (`sync_plan`), ricalcolato a ogni `/subscription/status` con billing attivo. Un piano salvato senza acquisto verificato non vale.
- **Stati con accesso**: `active`, `canceled` (rinnovo disattivato, fino alla scadenza), `in_grace_period` (fino a `grace_expires_at`). Senza accesso: `pending`, `billing_retry`, `on_hold`, `paused`, `expired`, `revoked`, `refunded`, `replaced`.
- **Idempotenza**: `store_events` (chiave `store,event_id`): una notifica duplicata non cambia nulla. **Ordine**: una notifica Apple firmata prima dell'ultimo evento applicato è registrata come `stale_ignored`; Google rilegge sempre lo stato dall'API, quindi l'ordine non conta.
- **Errori temporanei**: un errore dello store in acquisto non concede nulla (503). In riconciliazione si segna `verification_error_at` e si mantiene solo lo stato già verificato, con tolleranza `BILLING_VERIFICATION_TOLERANCE_HOURS` (default 24, max 72) e solo per un abbonamento attivo con rinnovo automatico. `owner_limits_lookup` con billing attivo non è più fail-open: usa l'ultimo esito verificato in memoria per al massimo 1 ora, poi "nessun accesso".
- **Upgrade/downgrade**: Google crea un nuovo token con `linkedPurchaseToken` → il vecchio diventa `replaced`; Apple mantiene `originalTransactionId` e cambia `productId` (il downgrade vale dal rinnovo, come dice lo store).
- **Rimborso/revoca**: `REFUND`/`REVOKE` (Apple), `voidedPurchaseNotification` e `SUBSCRIPTION_REVOKED` (Google) tolgono l'accesso subito.
- **Ambienti**: un deployment accetta solo `BILLING_STORE_ENVIRONMENT` (sandbox o production), mai entrambi.
- **Account del team e demo**: `DEVELOPER_EMAILS` resta come prima (accesso illimitato, nessun piano richiesto, anche con billing attivo). `BILLING_PLAN_OVERRIDES` (`email:piano,...`, solo variabile d'ambiente) tiene un account su un piano fisso senza store; `/subscription/status` lo dichiara con `plan_source: "override"`. Togliere l'email dalla variabile rimette l'account sotto lo store al controllo successivo. Nessuna richiesta può attivarlo.
- **Admin test**: `POST /admin/billing/test-grant`, solo admin, rifiutato in produzione e se `BILLING_ADMIN_TEST_GRANTS` non è `true`; crea un diritto `admin_test` marcato come anomalia, separato dai flussi pubblici.

## Vincoli delle policy (da riverificare sulle versioni correnti prima dell'invio)
- **Apple App Review 3.1.1**: contenuti digitali solo con In-App Purchase; nessun link o invito a pagare fuori dall'app (il pannello sito `BillingAccountPanel` resta solo su web). **3.1.2**: abbonamenti auto-rinnovabili con durata minima 7 giorni, valore continuativo; nel paywall devono comparire titolo, durata, prezzo, rinnovo automatico, link a Termini (EULA) e Privacy, e il pulsante "Ripristina acquisti" (presente). **Prova gratuita gestita dall'app senza IAP**: 3.1.1 descrive la prova gratuita a tempo come IAP non consumabile a prezzo zero; la prova di 14 giorni lato backend va verificata con App Review (rischio di rifiuto) — eventuale soluzione: prodotto "Prova gratuita" a prezzo 0 o introductory offer.
- **Apple 5.1.1(v)**: cancellazione account in app (già presente); spiegare che la cancellazione dell'account non disdice l'abbonamento nello store.
- **Google Play Payments policy**: contenuti digitali solo con Google Play Billing; **Subscriptions policy**: informazioni chiare su prezzo, periodicità, rinnovo e come disdire; link alla gestione abbonamenti (presente). Acquisti da riconoscere (acknowledge) entro 3 giorni o vengono rimborsati (fatto server-side).
- **UE**: recesso di 14 giorni e fatture gestiti dagli store come venditori (Apple/Google sono merchant of record); nessun dato di pagamento passa da Quokka.
- Nessun checkout web o Stripe per gli abbonamenti dell'app.
