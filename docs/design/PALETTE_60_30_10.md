# Palette 60/30/10

Proposta per il riordino dei colori dell'app (2026-10-27). Tutti i colori vivono in
`apps/mobile_app/lib/design_system/tokens/app_colors.dart`; un test
(`test/design_system/colors_test.dart`) fallisce se una pagina scrive un colore da sé.
I contrasti sono controllati da `scripts/design/contrast_check.py` (WCAG AA, anche in `pytest`).

## La regola

| Quota | Ruolo | Dove | Colore |
|---|---|---|---|
| **60%** | Neutro | sfondo, schede, bordi, testo | carta calda: `background` `#F6F1EA`, `surface` `#FCFAF7`, bianco `#FFFFFF`, testi `#213134` / `#52645F` / `#5E6E6B` |
| **30%** | Secondario | struttura: pannelli morbidi, chip non selezionati, indicatore della barra, icone decorative, titoli di sezione | salvia: `secondary` `#6E9482`, `secondarySoft` `#E4EDE7`, `secondaryMid` `#CADBD0`, `secondaryStrong` `#35604F` |
| **10%** | Accento | solo dove si agisce o si guarda: pulsanti principali, tab/chip selezionati, link, focus, passo corrente, grafici | verde-petrolio: `primary` `#2E686A`, `primaryStrong` `#214E50`, `primarySoft` `#DCEBEA` |

Fuori dalla regola, perché portano significato: stato (verde/ambra/rosso/azzurro con varianti
`Strong` per il testo e `Soft` per gli sfondi), colori delle categorie del radar
(`AppCategoryColors`) e colore d'identità dell'animale (`AppIdentityColors`).
Su foto, mappe e video: famiglia `onMedia` / `scrim` (niente più bianco e nero scritti a mano).

## Com'era prima (inventario)

Usi nei file `lib/` (conteggio dei riferimenti):

| Token | Usi | Nota |
|---|---|---|
| `primary` (verde-petrolio) | 163 | icone decorative, bordi, titoli, pulsanti, link: fa da secondario **e** da accento, quindi non era il 10% |
| `accentSoft` (pesca) | 48 | pannelli e chip |
| `accent` (corallo) | 22 | un secondo accento in concorrenza col verde |
| `secondary` (salvia) | 2 | quasi inutilizzato |
| neutri (`background`, `surface*`, `border*`, `text*`, `mutedText`) | circa 510 | ok |
| stato (`danger`, `info`, `warning`, `success`) | 126 | `danger` e `mutedText` sotto AA come testo |

Colori scritti nelle pagine: **71 `Color(0x…)` in 19 file** e circa 100 `Colors.white/black/red/…`
(tre sfumature di sfondo diverse per home, animali e promemoria; verdi scuri `#163A35` per ombre e
pulsanti tondi; nove colori sparsi nei marker della mappa). Ora sono **0** fuori dai token.

## Cosa cambia

* Gli attributi decorativi (icone, intestazioni, sfondi tenui) passano dal verde-petrolio alla
  **salvia**: restano al petrolio solo i controlli (53 icone spostate). Il petrolio resta quello di
  prima per continuità con icona e build già distribuite.
* Il corallo non è più un accento: le sue 22 occorrenze diventano salvia (decorazione) o petrolio
  (prezzo/badge dei piani).
* I pannelli pesca (`accentSoft`) diventano salvia chiara (`secondarySoft`).
* Un solo sfondo sfumato per tutta l'app (`backgroundGradient`: tre passi), al posto di tre diversi.
* Contrasti: `mutedText` `#82908D` → `#5E6E6B` (era 3,0:1, ora 4,8:1), `danger` `#D66B61` → `#B73E34`
  (testo e pulsante ≥ 4,5:1), `success`/`warning`/`info` scuriti per le icone (≥ 3:1) con varianti
  `Strong` per il testo. Pulsante principale: `onPrimary` su `primary` 5,9:1.
* Radar: `school` (verde-acqua, troppo vicino all'accento) diventa oliva, `dogPark` un verde più chiaro
  e `association` un arancio netto (era troppo vicino al rosso del veterinario). Un test controlla la
  distanza tra categorie e dall'accento.

## Alternativa: «Salvia e Terracotta»

Stessi neutri e stesso secondario salvia; l'accento 10% è **terracotta**. Rosso-arancio e verde sono
complementari, quindi il contrasto cromatico è più forte; costa la continuità con l'icona attuale.

| Token | Proposta (petrolio) | Alternativa (terracotta) |
|---|---|---|
| `primary` | `#2E686A` | `#AA4730` |
| `primaryStrong` | `#214E50` | `#8A3623` |
| `primarySoft` | `#DCEBEA` | `#F9E8E2` |
| `onPrimary` | `#F9F6F0` | `#FFFFFF` |

Entrambe superano AA su tutte le coppie controllate (`python scripts/design/contrast_check.py`).

## Schermate prima/dopo

`docs/design/screens/index.html` (home, animali, dettaglio animale, chat, attività, Mercatino,
impostazioni, nuovo animale: 375 px, dati di prova, tema chiaro) e `docs/design/screens/palette.html`
(proposta e alternativa affiancate, con i campioni dei token).

Dopo lo spostamento: `primary` 163 → 112 usi (restano controlli, selezione, link, grafici),
`secondaryStrong` 0 → 75.

## Tema scuro

Oggi l'app **non ha un tema scuro**: esiste solo `AppTheme.light()` e i token sono costanti `const`
usate in centinaia di punti, quindi non cambiano a runtime. Con i colori tutti in un solo file, un tema
scuro diventa un lavoro a sé (token resi dipendenti dal tema); non l'ho incluso in questa proposta.

## Come cambiare un colore in futuro

Un punto solo: `app_colors.dart`. Se un colore nuovo serve, va aggiunto lì col suo ruolo
(60, 30, 10, stato, media, categoria) e poi usato per nome.
