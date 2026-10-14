# Prova di layout in francese

Locale `fr`, viewport 320×568 e 360×640, scala del testo 1,0 e 1,3, 80 pagine/stati
(auth, shell, impostazioni con ogni sezione aperta, animali, galleria, ricordi, chat,
promemoria, referti, luoghi vicini, mercatino, passeggiata, abbonamento, primo avvio,
dialoghi), ciascuno anche in versione "alta" per costruire il contenuto sotto la piega:
**640 esecuzioni, 0 non montate, 0 eccezioni**. Font: Roboto al posto di Figtree e Georgia
al posto di Fraunces (gli originali non sono disponibili offline), quindi i pixel sono
indicativi. Il banco di prova è quello della coordinatrice (`stress_harness.dart`), non
committato perché dipende da font locali; si lancia con `SUPABASE_URL` vuoto.

## Esito dopo gli accorciamenti
- 18 esecuzioni su 640 con RenderFlex overflow, **tutte nello stesso punto di codice già
  segnalato per IT/EN/ES** (nessun overflow nuovo dovuto al francese):

| Pagina | Punto di codice | Pixel max | Dove |
|---|---|---|---|
| home | `home_dashboard_page.dart:492` (marcatori del giorno) | 3 | 320 e 360×1,3 |
| pet_detail_aquarium | `pet_detail_page.dart:1736` (stato vuoto, verticale) | 52 | 360×1,3, 320×1,0 |
| pet_create / pet_edit / pet_edit_aquarium | `pet_profile_form.dart:389` (menu specie, senza `isExpanded`) | 7,4 | 320×1,3 |
| pet_create | `pets_scaffold.dart:57` (intestazione; probabile falso positivo, font Ahem) | 7,2 | 320×1,3 |
| pet_edit | `pet_profile_form.dart:513` (menu taglia) | 4,7 | 320×1,3 |
| pet_edit_aquarium | `pet_profile_form.dart:1097` (contatore sesso) | 10 | 320 |
| profile | `profile_page.dart:181` (Indietro + Impostazioni) | 9,7 | 320×1,3 |

  Sono difetti di layout indipendenti dalla lingua (Row senza `Expanded`/`Flexible`):
  il francese non li peggiora, in alcuni casi sfora meno di IT/ES. Correggerli nel codice
  (`isExpanded: true` sui menu, `Flexible` sulle righe) risolve tutte le lingue.
- Testi troncati con ellissi: restano quelli già noti e uguali nelle altre lingue
  (sottotitolo Layout, meta dei promemoria, titolo del Mercatino, anteprime dati demo).
  Specifici del francese e accettati: "Événement" (chip promemoria, solo 320×1,3),
  "Nouveau mot de passe" nella pagina nuova password (320×1,3), "Longueur" (320×1,3).

## Testi accorciati perché sforavano
Prima dell'accorciamento il francese produceva 4 punti di overflow in più rispetto a
IT/EN/ES. Modifiche in `app_fr.arb`:

| Chiave | Prima | Dopo | Effetto |
|---|---|---|---|
| `marketplaceCategoryKennelsCarriers` | Paniers, couchages et caisses de transport | Paniers et transport | chip categoria del dettaglio annuncio: 99 px di overflow a 360×1,3 → 0 |
| `firstRunTrialCardTitle` | Essai gratuit · 10 jours | 10 jours gratuits | titolo card prova (Row senza `Expanded`): 32–40 px → 0 |
| `petsFormSpeciesHint` | Sélectionnez une espèce | Choisir une espèce | menu specie: 26 px → 7,4 px (resta il difetto strutturale) |
| `authConfirmPasswordLabel` | Confirmer le mot de passe | Confirmation | etichetta troncata in registrazione e nuova password; il segnaposto "Saisissez-le à nouveau" chiarisce il campo |

## Altre note di layout
- Tipografia: spazio non separabile (U+00A0) prima di `? ! : ; %` e nelle virgolette « »,
  quindi la riga non va a capo tra la parola e il segno.
- Plurali: in francese 0 e 1 sono singolari e l'ICU `=1{…}` viene scelto anche per 0.
  Per questo i rami `=1` usano `{count}` e non il numero "1" scritto (altrimenti "0 profil"
  verrebbe mostrato come "1 profil").
- Date numeriche `dd/MM/yyyy`, virgola decimale (`NumberFormat` con locale `fr`), unità
  metriche (`defaultUnitsForLocale`: FR/BE/CH → metrico).
