# Compliance Docs

Documentazione sulla conformità normativa di Quokka (AI Act, protezione dati) e sui meccanismi tecnici che la supportano.

**Nome del prodotto.** Dal 2026-10-27 l'app si chiama **Quokka** (decisione del proprietario). Il nome è provvisorio: la ricerca di anteriorità del marchio è in corso (sessione «Consulente marchi virtuale», `docs/marchio/`), quindi per ora compare solo dentro l'app (tester) e in questi documenti, mai in materiali pubblici o di store. Gli identificativi tecnici non cambiano (`com.vetapp.*`, User-Agent). Se il nome cambia di nuovo la sostituzione è meccanica: nei documenti il nome compare sempre come parola, in tutte le lingue.

## Documenti
- `01_ai_disclosure.md` — come e dove l'app segnala contenuti generati da IA.
- `02_pii_anonymization.md` — confine e funzionamento dell'anonimizzazione dei dati sensibili.
- `03_consenso_cartella_clinica.md` — testo e revisione del consenso per l'accesso della chat alla cartella clinica del pet.
- `04_termini_e_consensi.md` — quadro normativo su Termini di Servizio, consensi opt-in (GDPR art. 6/7) e permessi OS; architettura dei consensi a livello di account.
- `05_permessi_dispositivo_os.md` — catalogo permessi OS per l'app nativa Android (fotocamera, microfono, posizione, notifiche): cosa dichiarare ora, testo di richiesta, e il flusso "aggiorna per continuare" quando un permesso non è già dichiarato.
- `06_radar_mappe_sponsorizzazioni.md` — parere operativo su radar servizi OSM: licenza ODbL, policy Overpass/tile, pubblicità veterinaria, trasparenza commerciale, privacy posizione; sponsorizzazioni rimandate.
- `07_contributi_utenti.md` — parere su contributi degli utenti nel radar (perimetro ridotto: segnalazioni e stelle sulle aree cani): obblighi DSA per piccole imprese, rischi residui, regole d'uso v2, licenze dei dataset comunali, bozze privacy.
- `08_punti_aperti_prima_del_lancio.md` — registro unico dei punti da decidere prima del lancio pubblico: cosa, perché, chi decide, quando.
- `09_informativa_privacy_bozza.md` — bozza di informativa privacy (artt. 13–14 GDPR) per il primo tester invitato; da far rivedere da un legale, non pubblicare così com'è.
- `<paese>/` (`at`, `au`, `be`, `ch`, `ch-fr`, `de`, `es`, `fr`, `uk`, `us`) — bozze legali per paese, nella lingua del paese: ricerca normativa (01), informativa privacy (02), termini (03), consensi (04), avviso sull'IA e sul veterinario (05), numeri utili (06), differenze rispetto all'Italia (07), domande per il proprietario (08). Nel Mercatino gli animali sono vietati in tutti i paesi (decisione del proprietario, 2026-10-26): non c'è più una regola per paese.
- `legislative-watch/` — meccanismo di monitoraggio degli aggiornamenti legislativi (job schedulato + report per revisione umana).
