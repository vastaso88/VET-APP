# Notizie, eventi e Mercatino per territorio

Data: 2026-10-14. Sessione "Notizie, eventi e Mercatino per territorio" (ramo `ml/notizie-eventi-mercatino`).

## Regola di fondo

Il **territorio** dell'utente è il paese della variante di lingua scelta nell'app (🇮🇹 IT, 🇬🇧 GB, 🇺🇸 US, 🇦🇺 AU, 🇩🇪 DE, 🇫🇷 FR, 🇪🇸 ES). Tutto ciò che dipende dal paese sta in **una tabella**:
`apps/mobile_app/lib/features/territory/domain/territory.dart` (app) e `packages/core/domain/territory/rules.py` (backend). I test dei due lati fissano gli stessi valori.

| Paese | Valuta |
| --- | --- |
| IT, DE, AT, FR, BE, ES | € |
| GB | £ |
| US | $ |
| AU | A$ |
| CH | CHF |

**Animali (decisione del proprietario, 2026-10-26): vietati in tutti i paesi, Italia compresa.** Il Mercatino vende solo oggetti per animali. Il backend (`CreateListingService`/`UpdateListingService`) rifiuta titoli e descrizioni che vendono, cedono o scambiano animali (`packages/core/domain/marketplace/animal_policy.py`, cinque lingue, parole intere); l'app applica la stessa regola per avvisare prima (`animal_policy.dart`, generato). Gli annunci già presenti si nascondono con `scripts/setup/marketplace_no_animals.sql` (stato `removed_policy`, nessuna cancellazione). "Vende animali" è un motivo di segnalazione.

**Distanza, non paese**: gli annunci si trovano per raggio (1–300 km, predefinito 50). Vicino a un confine compaiono anche gli annunci dell'altro paese, con la bandiera del venditore e il prezzo nella sua valuta (nessuna conversione: non c'è un tasso affidabile senza servizi a pagamento).

Un paese sconosciuto ottiene le regole dell'Italia (paese sorgente), mai quelle di un altro.

## 1. Notizie

- Fonte invariata: Google News RSS (ricerca) tramite rss2json.com. Cambiano **edizione e parole**: `hl`/`gl`/`ceid` per paese e lingua (`pet_news_edition.dart`): it → `it/IT`; en → `en-GB/GB`, `en-US/US`, `en-AU/AU`; es → `es/ES`; de → `de/DE` (`de-AT`, `de-CH`); fr → `fr/FR` (`fr-BE`, `fr-CH`).
- Le **ricerche sono scritte nella lingua** dell'edizione (cane/dog/perro/Hund/chien… con parole d'ancoraggio "veterinario/vet/…" ed esclusioni di ricette, caccia, oroscopi, esperimenti) e un secondo filtro sui titoli scarta ricette e caccia nella lingua giusta.
- **Filtro lingua**: un titolo scritto chiaramente in un'altra lingua (altre parole funzione prevalgono, almeno due) viene scartato. Euristica volutamente prudente: titoli brevi o ambigui passano.
- **Cache per edizione**: cambiando lingua/paese non si vedono mai i titoli del paese precedente.
- **Nessun ripiego su altri paesi**: se l'edizione non dà nulla, l'elenco è vuoto e Home/Notizie mostrano `petNewsEmptyLocal` ("nessuna notizia nella tua lingua e per il tuo paese; non mostriamo notizie di altri paesi").
- **Limiti noti**: l'edizione Google è un criterio di ranking, non un confine: una testata estera molto citata può comparire. Filtrare per regione/città non è stato fatto (la ricerca per città dà risultati rumorosi); si può aggiungere un termine di area alla query "Generale" se serve.

### Fonti per paese e termini d'uso

| Paese | Fonte attiva | Note su licenza / ToS e limiti |
| --- | --- | --- |
| tutti | Google News RSS `news.google.com/rss/search?q=…&hl=…&gl=…&ceid=…` | I feed Google News sono pensati per **uso personale/non commerciale**; chi li ripubblica deve attribuirli a Google News, nominare la testata di ogni articolo e linkare l'articolo. L'app mostra titolo, testata e link all'articolo originale (nessun testo copiato). **Non ho letto i termini correnti di Google: va fatto prima del lancio commerciale (decisione del proprietario).** Nessuno scraping: una richiesta per categoria, cache 20 minuti, richieste a gruppi di 3 con pausa. |
| tutti | rss2json.com (proxy gratuito, senza chiave) | Piano gratuito con limite di richieste condiviso (già causa di errori 429/500, gestiti con retry e cache). **Condizioni commerciali e limiti giornalieri non verificati.** Alternativa: un piccolo endpoint nel nostro backend che legge il feed (da valutare: il browser non può chiamare Google direttamente per CORS). |

Feed curati per paese (candidati, **non attivi, ToS non verificati**): testate/enti con RSS pubblico dedicati ai pet (es. RSPCA e Dogs Trust per GB, AVMA/ASPCA per US, RSPCA Australia per AU, Tierschutzbund per DE, 30 Millions d'Amis per FR, Fundación Affinity per ES). Da attivare solo dopo aver letto per ciascuna le condizioni di riuso e ottenuto, dove serve, un permesso scritto.

## 2. Eventi

- Tabella `events` con colonna **`country`** (ISO alpha-2, default `IT`): `scripts/setup/marketplace_country.sql` (**da eseguire una volta su Supabase prima di pubblicare**).
- L'app chiede e rifiuta: `EventsRepository.loadEvents` filtra `country = paese dell'utente` e scarta in locale eventuali righe di altri paesi. Nessun ripiego sull'Italia.
- Regioni per paese in `packages/infrastructure/events/event_regions.py` (IT regioni, GB nazioni, US stati, AU stati/territori, DE Länder, FR regioni, ES comunità): `region` di un evento è validata contro la tabella del suo paese. Il filtro "Regione" dell'app mostra già solo le regioni degli eventi caricati. Il codice `province_code` è la sigla di 2 lettere in Italia, di 1-3 caratteri altrove (NSW, BY, 75, 2A, M).
- Testi: titoli e descrizioni degli eventi sono scritti **nella lingua del paese** dal curatore (non si traducono); le etichette dell'app (tipi, livelli, stati) sono già in ARB. Chiavi nuove: `eventsCountryOnlyNote`; `activitiesEventsSubtitle` non dice più "in tutta Italia".
- **Seed finti** per ciascun paese in `scripts/events/examples/<PAESE>.json` (2 eventi ciascuno, slug `example-…`, sito `www.example.org`, descrizione che dice che l'evento non esiste). `import_curated.py` rifiuta quella cartella senza `--allow-examples`. Gli eventi veri vanno in `data/events/curated/<PAESE>.json`.

## 3. Mercatino

- **Raggio obbligatorio**: tolto "Ovunque". Opzioni 2/5/10/25/**50** km oppure 1/3/5/15/**30** mi (unità scelte nelle Impostazioni, di default quelle del paese). Predefinito 25 km / 15 mi. Senza posizione non si mostra nessun annuncio e si chiede di impostarla.
- **Backend**: nuova rotta `GET /marketplace/listings?latitude&longitude&radius_km&country` (autenticata). `radius_km` e `country` sono obbligatori (422 se mancano); raggio ≤ 0, NaN o > 50 km → 400; paese sconosciuto → 400. Restituisce solo annunci attivi di quel paese entro il raggio, con la distanza.
- **App**: usa la rotta quando ha indirizzo API e sessione; altrimenti (anteprime, test) legge la tabella con filtro `country` e riquadro attorno al raggio; in ogni caso applica gli stessi filtri (`applyListingFilter`): paese, raggio ≤ 50 km, niente senza posizione. Se la rotta risponde 400/422 non si ripiega sulla lettura diretta.
- **Paese degli annunci**: colonna `marketplace_listings.country` (default `IT`), scritta alla pubblicazione col paese del venditore. Nessun annuncio di altri paesi, anche vicini al confine.
- **Valuta**: simbolo per paese (€, £, $, A$, CHF) in lista, dettaglio e mappa; il campo prezzo diventa "Prezzo ({valuta})". Non esisteva ancora l'helper della sessione "Formati e store" (ramo `ml/formati-e-store` assente): ho usato la tabella del territorio; se quella sessione introduce un helper valuta, conviene farlo leggere da `Territory.currencySymbol` per non avere due fonti. Restano `€` fissi in `billing_models.dart` (fuori da questo lavoro).
- **Animali**: vietati ovunque. La pagina "Nuovo annuncio" mostra la regola (nessuna casella di conferma); il backend rifiuta il testo che offre un animale con il messaggio "Sul Mercatino si vendono solo oggetti per animali, non animali."
- **Decisione del proprietario**: la policy `marketplace_listings_select_all` permette ancora la lettura diretta dell'intera tabella con la anon key; finché non viene ristretta (testo in fondo a `marketplace_country.sql`) raggio e paese sono applicati dalla rotta e dall'app, non dal database.

## Chiavi di traduzione

Tutte le chiavi sono presenti nelle 5 lingue (`app_it/en/es/de/fr.arb`); i controlli sono `check_i18n.py`, `glossary.py check`, `auto_translate.py check`.

## Ordine di rilascio

1. Eseguire `scripts/setup/marketplace_country.sql` su Supabase.
2. Pubblicare il backend (rotta `/marketplace/listings`, `country` su creazione).
3. Pubblicare l'app. Con il backend non ancora aggiornato l'app ripiega sulla lettura diretta (stessi filtri lato app).
