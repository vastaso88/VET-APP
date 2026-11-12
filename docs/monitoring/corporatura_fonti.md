# Corporatura: fonti e regole (2026-10-21)

La corporatura (body condition) è un giudizio visivo e tattile, non un calcolo sul peso. Nell'app esiste solo per le specie con un riferimento pubblicato, e si sceglie sempre dal popup "Valuta la corporatura" (mai da un menu libero). Una sola regola, in due punti che devono restare uguali:

- app: `bodyConditionGuideForSpecies` in `apps/mobile_app/lib/features/monitoring/domain/body_condition_guide.dart`
- backend (chat): `species_has_body_condition` in `packages/core/domain/pet_profile/body_condition.py`

## Specie con guida

| Specie | Fonte | Scala originale → nostri 5 livelli |
|---|---|---|
| Cane | WSAVA Global Nutrition Committee, Body Condition Score (scala a 9 punti, da Laflamme 1997) | 1–2 / 3 / 4–5 / 6–7 / 8–9 |
| Gatto | WSAVA GNC (Laflamme 1997; validazione Bjornvad et al., AJVR 2011) | 1–2 / 3–4 / 5 / 6–7 / 8–9 |
| Coniglio (razza di "Piccoli mammiferi") | PFMA Rabbit Size-O-Meter, 5 livelli | 1 / 2 / 3 / 4 / 5 |

La conversione 9→5 è una semplificazione di VetApp (WSAVA non ha una versione a 5 punti). Per il coniglio la guida mostra un avviso: l'affidabilità tra valutatori è scarsa (Halck et al., Vet Rec 2025, alpha di Krippendorff 0,58) e la scala non è validata su misure oggettive.

Nessuna guida (quindi nessuna corporatura): uccelli, rettili e anfibi, pesci, altri piccoli mammiferi (criceto, furetto…), "Altro". Non c'è una scala validata e affidabile per un'app generale. Candidate se servono in futuro: cavia (PFMA Guinea Pig Size-O-Meter, non validata in letteratura revisionata), cavallo (Henneke 1983).

## Copyright

I grafici e i testi WSAVA sono protetti (la SOP del GNC ammette l'uso solo integrale, senza modifiche, con logo). Quindi: nessuna immagine copiata; le illustrazioni sono disegnate in Flutter (`body_condition_illustration.dart`); i testi dei livelli sono scritti con parole nostre (non traduzioni riga per riga) e la fonte è dichiarata come "criteri riassunti, non materiale ufficiale WSAVA". Se serve un'attribuzione ufficiale o il riuso fedele, va chiesta l'autorizzazione al WSAVA GNC (modulo indicato su wsava.org). Stesso discorso per PFMA.

## Perché non c'è un calcolo automatico

- Il BCS valuta il grasso rispetto alla struttura con osservazione e palpazione (WSAVA).
- Smith et al. 2018 (J Anim Physiol Anim Nutr 102:1088, doi 10.1111/jpn.12919): i range di peso per razza non predicono un BCS ideale.
- La regola "~10% di peso per punto sopra 5" non è confermata da una fonte primaria (non presente in German 2006): non usata.
- Gli standard di razza FCI non hanno copertura uniforme del peso e riguardano solo i cani di razza.

## Bande di crescita (cuccioli e gattini)

Salt et al. 2017 (PLoS ONE 12(9):e0182064, CC BY 4.0) non pubblica i valori delle curve, solo figure. Le bande nell'app sono quindi **centili empirici calcolati da noi** sui dati grezzi rilasciati dagli autori (Liverpool DataCat 377, CC BY 4.0), non le curve ufficiali WALTHAM; sotto il grafico lo dichiariamo ("derivato da") e avvisiamo che è un riferimento e non una diagnosi.

- Cani: `scripts/growth/build_puppy_growth_bands.py` → `apps/mobile_app/assets/growth/puppy_growth_bands.json`. Classi di peso adulto I–V dell'articolo (<6,5 / 6,5–<9 / 9–<15 / 15–<30 / 30–<40 kg), maschi e femmine, 12–104 settimane, centili 3-10-25-50-75-90-97. Classe VI (≥40 kg) non modellata. Metodo e limiti (cani "ideali" ricostruiti dalla condizione registrata, outlier, finestre) nel campo `method` del JSON e nella docstring dello script.
- Gattini: `scripts/growth/build_kitten_growth_bands.py` → `kitten_growth_bands.json`, da Salt et al. 2022 (dataset DataCat 1456, CC BY 3.0), dataset "Modelling" (sani, condizione ideale), gattini domestici a pelo corto non sterilizzati (USA), 8–78 settimane.
- Mostrate solo sotto i 24 mesi (cani con classe nota) e i 18 mesi (gatti meticci o europei). La classe di un cane non è nel profilo: la sceglie il proprietario ("Peso adulto atteso"), salvata solo sul dispositivo; "Toy" implica la classe I. Se non la sceglie, nessuna banda.
- I dati grezzi non sono nel repository (cartella `.local/`, ignorata): per rigenerare, scaricare gli zip/CSV e lanciare gli script con i percorsi come argomenti.
