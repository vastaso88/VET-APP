# Confronto difficoltà/costo MVP tra le tre feature mappe

Per sequenziare il lavoro anche quando si vuole vedere le tre feature progredire "in parallelo" (come richiesto): non c'è un vincolo d'ordine tra loro una volta pronta la fondazione condivisa `geo`/`location` (vedi `01_localita_fondamenta_condivise.md`), ma hanno profili di rischio/sforzo diversi.

| | Passeggiate (dog-walk) | Mercatino | Attività |
|---|---|---|---|
| Sforzo (dominio+backend+data layer) | Medio — stream GPS live, distanza cumulativa, controller Flutter con stato | Basso-Medio — CRUD + fuzzing + soglia segnalazioni | Basso — CRUD + filtro distanza, la forma dati più semplice |
| Nuove dipendenze esterne | `geolocator` (condivisa con tutte e 3) | nessuna oltre `flutter_map` (condivisa) + un bucket Supabase Storage per le foto (non ancora creato) | `flutter_map` (condivisa), nessuna dipendenza backend nuova |
| Rischio dati/privacy | Basso — privato, owner-scoped, nessun fuzzing necessario | Il più alto — prima tabella a lettura pubblica dello schema, rischio spam/truffe reale | Basso-Medio — dati pubblici per natura, ma scrittura aperta agli utenti richiede la stessa leva di segnalazione |
| Costo ricorrente | Nessuno oltre lo storage Supabase normale | Storage foto (bucket nuovo, non creato in questo lavoro) | Nessuno oltre ai tile OSM (condiviso con le altre due) |
| Rischio scope creep | Contenuto tramite la funzione pura `evaluate_badges` (nessuna tabella nuova per goal/badge) | — | — |

**Cosa è stato effettivamente completato in questa sessione**: tutte e tre, a livello di dominio/backend/data-layer (vedi `docs/maps/README.md` per lo stato). Le differenze sopra restano utili per capire dove concentrare l'attenzione in fase di revisione/hardening, non per decidere l'ordine di sviluppo (già fatto).

**Nota costo condiviso**: il tile server pubblico OpenStreetMap richiede attribuzione visibile (già presente in `maps_demo_page.dart` via `RichAttributionWidget`) e scoraggia traffico alto senza User-Agent dedicato o un tile provider a pagamento — non un problema in fase demo/MVP, da rivalutare se il traffico reale cresce.
