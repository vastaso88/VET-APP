# Chiavi ARB nuove o cambiate (notizie / eventi / Mercatino)

EN/ES già in `app_en.arb` / `app_es.arb`. Per DE/FR (rami `ml/traduzione-de|fr`): aggiungere queste chiavi mantenendo il segnaposto `{currency}`, poi `check_i18n.py`, `flutter gen-l10n`, `auto_translate.py acknowledge`.

| Chiave | Italiano | Inglese |
| --- | --- | --- |
| `petNewsEmptyLocal` | Per ora non ci sono notizie nella tua lingua e per il tuo paese. Non mostriamo notizie di altri paesi. | There is no news in your language and country right now. We don't show news from other countries. |
| `eventsCountryOnlyNote` | Mostriamo solo gli eventi del tuo paese, quello della lingua scelta nell'app. | We only show events from your country, the one of the language you picked in the app. |
| `marketplaceNeedsLocation` | Il Mercatino mostra solo gli annunci vicino a te. Imposta la tua posizione in Impostazioni → Località per vederli. | The marketplace only shows ads near you. Set your location in Settings → Location to see them. |
| `marketplaceNoLiveAnimalsNote` | Nel tuo paese il Mercatino non ammette annunci di animali vivi: solo prodotti e servizi per animali. | In your country the marketplace does not allow ads for live animals: only products and services for animals. |
| `marketplaceNoLiveAnimalsConfirm` | Confermo che questo annuncio non offre un animale vivo (vendita, regalo o cessione) | I confirm this ad does not offer a live animal (sale, gift or rehoming) |
| `marketplaceNoLiveAnimalsRequired` | Conferma che l'annuncio non offre un animale vivo | Confirm that the ad does not offer a live animal |
| `marketplaceFieldPrice` (cambiata, ora con `{currency}`) | Prezzo ({currency}) | Price ({currency}) |
| `activitiesEventsSubtitle` (cambiata) | Fiere, esposizioni e iniziative per animali nel tuo paese. | Fairs, shows and pet initiatives in your country. |

Rimosse: `marketplaceDistanceAnywhere`, `marketplaceDistanceNeedsLocation` (sostituita da `marketplaceNeedsLocation`). `homeNewsUnavailable` non è più usata (Home usa `petNewsEmptyLocal`): può essere tolta in un secondo momento da tutti i cataloghi.
