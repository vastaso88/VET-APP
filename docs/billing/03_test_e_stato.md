# Abbonamenti — test e stato (2026-11-21)

## Test automatici (backend, `uv run pytest`)
- `tests/unit/billing/test_store_billing_service.py`: trial valido/scaduto, piano salvato senza acquisto ignorato, primo acquisto Apple/Google, acknowledge Google, acquisto pendente, prodotto sconosciuto, transazione falsificata, acquisto di un altro account, sottoscrizione già legata, token mancante, ambiente sbagliato, rinnovo, cancellazione fino a scadenza, scadenza per tempo, rimborso, revoca, periodo di tolleranza vs billing retry, upgrade Google, downgrade Apple, notifiche duplicate e fuori ordine, rilettura Google, notifica per account sconosciuto, notifica prima della verifica del client, ripristino, errore temporaneo in acquisto e in riconciliazione con tolleranza limitata, test grant admin.
- `tests/unit/billing/test_store_signatures.py`: JWS Apple autentico, radice non fidata, payload alterato, `alg: none`, decodifica transazione/rinnovo/notifica V2, bundle sbagliato, parsing `subscriptionsv2` e RTDN, token OIDC Pub/Sub (audience, mittente, scadenza, assenza).
- `tests/integration/test_billing_routes.py`: rotte end-to-end con utente B, select-plan che non concede nulla, 503 su store giù, ripristino, notifiche non firmate rifiutate, riconciliazione e test grant protetti.
- `tests/unit/billing/test_renewal_notices.py`, `test_billing_texts.py`: promemoria del rinnovo annuale (una volta sola, chi non lo riceve, importo dello store, lingue, utente B, invio spento), testi rivisti uguali nel codice, nelle ARB e nelle schede dello store.
- Flutter: `renewal_declaration_test.dart`, `cancel_subscription_test.dart` (rinnovo dichiarato, disdetta in vista, 320 px con testo grande), `apps/mobile_app/test/billing/store_subscription_status_test.dart` (parsing; non eseguito in questa sessione: Flutter non installato nel container).

## Test sandbox predisposti (manuali)
Vedi `02_configurazione_store.md` §6. Nessun acquisto reale.

## Stato
| Parte | Stato |
| --- | --- |
| Logica diritti, idempotenza, ordine, proprietà, tolleranza | funzionante, testata con doppi degli store |
| Verifica firme Apple (x5c/ES256), OIDC Pub/Sub | testata con certificati/chiavi generati nei test |
| Chiamate reali App Store Server API / Play Developer API | implementate, **mai eseguite**: servono credenziali e sandbox |
| Migrazione Supabase | scritta, **non applicata** |
| Flutter `in_app_purchase` | scritto, **non compilato né analizzato** qui (manca Flutter); da `flutter pub get`, `flutter analyze`, prova su dispositivo |
| Admin portal | pagina scritta, **non compilata** qui (mancano i node_modules) |
| Produzione | **non pronta**: mancano configurazione store e collaudo sandbox end-to-end |

## Decisione aperta (Rob e proprietario)
- Piano cambiato dal team nel portale (`POST /admin/users/{id}/plan`, tabella di registro `admin_plan_changes`): con `BILLING_ENABLED=true` la verifica successiva con gli store (`sync_plan`) lo sovrascrive, e con `SUBSCRIPTION_TEST_PLAN` impostato non ha effetto; per gli account del team esiste già `BILLING_PLAN_OVERRIDES`. Da decidere se il cambio fatto dal team debba prevalere sugli store, durare fino a una data, o servire solo con il billing spento.
