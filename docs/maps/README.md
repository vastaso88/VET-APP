# Maps Docs

Documentazione della "gestione mappe": tre feature basate su geolocalizzazione (passeggiate con il cane, mercatino dell'usato geolocalizzato, attività/eventi nei dintorni) che condividono una fondazione comune di Località. Nasce come continuazione del brainstorm "Località" in `docs/settings/01_brainstorm.md`, ma ha una cartella propria perché il materiale copre design di dominio, schema dati e scelte tecniche che vanno oltre una singola voce di brainstorm.

## Documenti
- `01_localita_fondamenta_condivise.md` — design della fondazione condivisa "Località" (permessi, precisione, storage) e delle tre feature che la usano.
- `02_confronto_difficolta_mvp.md` — confronto sforzo/rischio/costo tra le tre feature, per sequenziare il lavoro.
- `03_handoff_ui_ux.md` — come integrare le tre feature nelle schermate reali (dove va ciascuna, cosa è già pronto, cosa resta aperto: notifiche push, eventuale aggregazione marketplace esterna).

## Stato implementazione (2026-09-19)
Costruite in questa sessione (dominio Python, servizi applicativi, schema Supabase, data/domain layer Flutter, demo harness `/demo/maps`): fondamenta Località, passeggiate con il cane (incluso `evaluate_badges`), mercatino dell'usato, attività/eventi nei dintorni. Non ancora costruite: le schermate di produzione e la navigazione reale — handoff avviato con la sessione "UI/UX e funzionalità base" (vedi `03_handoff_ui_ux.md`).
