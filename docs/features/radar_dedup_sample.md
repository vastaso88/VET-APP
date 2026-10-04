# Radar: taratura della deduplica

Sintesi aggregata della taratura delle regole in `packages/core/domain/radar_places/dedup.py`. Il campione con le coppie reali (nomi e telefoni di attività, alcune intestate a persone) **non sta nel repository**: `scripts/radar/dedup_sample.py` lo genera nella cartella locale `.local/radar/`, che git ignora.

## Dati usati

Milano, 10 km dal centro, 2026-10-04. OpenStreetMap: 225 luoghi (aree cani escluse). Overture `2026-09-23.1`: 382 luoghi dopo soglia di confidenza 0,7, esclusione dei chiusi e doppioni interni.

## Esito complessivo

| Regola | Coppie unite |
| --- | --- |
| Stesso telefono (entro 300 m) | 34 |
| Stesso sito web (entro 120 m) | 7 |
| Stessa categoria entro 30 m, nomi non in conflitto | 71 |
| Stessa categoria entro 120 m e nome compatibile | 6 |
| Candidati entro 120 m lasciati separati | 15 |

Le coppie candidate esaminate una per una sono state 44: tutte quelle lasciate separate entro 120 m e, per ogni regola, le unioni tra i luoghi più lontani tra loro (i casi più a rischio).

## Regole, dopo la taratura

1. **Stesso telefono** (normalizzato, senza prefisso) entro 300 m: stesso luogo. Il limite di distanza serve per i centralini condivisi.
2. **Stesso sito web** entro 120 m: stesso luogo. Il limite serve per le catene, che usano un sito unico per tutti i negozi. Profili social ed elenchi non contano.
3. **Stessa categoria entro 30 m**: stesso luogo, tranne quando entrambi hanno un nome proprio e i nomi sono diversi (due negozi affiancati, due studi nello stesso stabile).
4. **Stessa categoria entro 120 m e nome compatibile**: stesso luogo. Compatibile vuol dire una parola distintiva in comune, tolte le parole generiche (ambulatorio, clinica, veterinario, dott., srl, toelettatura...), oppure lo stesso nome scritto attaccato o staccato.
5. **Aree cani** entro 60 m: stessa area, perché le fonti le posizionano al centro di perimetri leggermente diversi.
6. In ogni altro caso: **due schede**.

Quando due voci coincidono resta una sola scheda, con i dati di una sola fonte (la più completa: telefono, orari, sito, indirizzo, dettagli; a parità OpenStreetMap) e l'indicazione che l'altra fonte la conferma. Telefono e orari non vengono mai presi da fonti diverse.

## Cosa ha cambiato il campione

- La regola 3 univa anche due attività con nomi diversi nello stesso punto: due negozi di catene concorrenti a pochi metri l'uno dall'altro risultavano una scheda sola. Ora restano separati.
- Quattro coppie avevano lo stesso nome scritto una volta attaccato e una volta staccato, e non risultavano compatibili. Ora sì.

## Tipi di caso osservati

| Caso | Quante coppie | Come sono trattate |
| --- | --- | --- |
| Stesso telefono, nomi diversi, 250-300 m di distanza | 2 | Unite. Una delle due fonti ha la posizione imprecisa; in un caso potrebbe trattarsi di un professionista che lavora in due sedi. |
| Stesso sito e stesso punto, ma telefoni diversi (fisso e cellulare) | 1 | Unite. Resta la scheda della fonte più completa, con un solo telefono. |
| Nome generico in una fonte ("Ambulatorio Veterinario", o nessun nome) e nome proprio nell'altra, entro 30 m | 3 | Unite, con riserva. |
| Due insegne di catene diverse entro 15 m | 3 | Separate. Può essere un cambio di insegna: in quel caso una delle due schede è vecchia. |
| Due nomi diversi di strutture sanitarie entro 20 m | 2 | Separate. Può essere lo stesso studio visto con il nome del medico e con quello della via, o due studi nello stesso stabile. |
| Nome generico a 50-70 m da un nome proprio | 2 | Separate. |
| Stessa insegna di catena a circa 200 m | 1 | Separate: due negozi, o uno solo con posizione imprecisa. |
| Stesso cognome nel nome a circa 250 m | 1 | Separate: probabile stessa struttura, ma oltre la soglia. |

Nessuno dei casi esaminati è un errore certo: sono unioni plausibili o separazioni prudenti. Nel dubbio la regola è due schede.

## Domande aperte per il proprietario

- Conviene alzare da 120 a 250 m la distanza per i nomi con un cognome in comune? Guadagno: una coppia in più unita nel campione. Costo: la stessa modifica unirebbe due negozi della stessa catena vicini tra loro.
- Due insegne diverse nello stesso punto: quando è un cambio di insegna, la scheda vecchia va tolta a mano con una riga in `radar_place_overrides`, oppure con "Segnala un problema" nell'app.

## Rigenerare il campione

```bash
uv run python scripts/radar/dedup_sample.py --help
```

Lo script legge due estratti locali (OpenStreetMap e Overture per la stessa zona) e scrive le coppie in `.local/radar/radar_dedup_sample.md`. Il file contiene nomi e recapiti reali: resta sul computer di chi lo genera.
