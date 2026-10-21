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

## Curve di crescita dei cuccioli

Salt et al. 2017, PLoS ONE 12(9):e0182064: licenza CC BY 4.0, ma i valori numerici dei centili (classi di taglia adulta I <6,5 kg … V 30–<40 kg, maschi/femmine) non sono pubblicati in tabella: solo figure. Il repository Liverpool (DOI 10.17638/datacat.liverpool.ac.uk/377, CC BY 4.0) ha solo i dati grezzi (146 MB). Le bande di riferimento non sono quindi mostrate; la curva sotto i 12 mesi resta senza riferimenti. Per averle: chiedere centili/parametri agli autori (contatto nel DataCat) oppure ricalcolarli dai dati grezzi dichiarandoli "derivati da Salt et al.". Gattini: Salt et al. 2022 (PLoS ONE, CC BY 4.0), stesso limite.
