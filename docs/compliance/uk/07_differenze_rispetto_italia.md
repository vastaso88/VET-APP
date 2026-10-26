> **BOZZA — non è consulenza legale; da rivedere da un solicitor del Regno Unito prima della pubblicazione**

# Differenze UK rispetto all'Italia

Data: 2026-10-13. Le voci «conoscenza generale» sono da verificare; quelle con ✅ sono confermate nei doc 01/06.

## Legale

| Tema | Italia / UE | Regno Unito | Effetto su VetApp |
|---|---|---|---|
| Legge sui dati | GDPR + Codice privacy; Garante | UK GDPR + DPA 2018 + DUAA 2025; ICO | Informativa e consensi UK propri (doc 02, 04); reclamo all'ICO invece che al Garante |
| Rappresentante | — | Art. 27 UK GDPR per titolare estero | Probabile nomina di un rappresentante UK ⚖️ |
| Quota annuale | — | Data protection fee ICO (£52/£78/£3.763 secondo fonti secondarie) | Verificare obbligo per titolare estero ⚖️ |
| Cookie / marketing | ePrivacy / Codice Privacy | PECR (come riformato dal DUAA); sanzioni fino a £17,5 mln o 4% | Consenso per marketing; eccezioni per analisi (da leggere) |
| Età digitale | 14 anni in Italia per il consenso | 13 anni (DPA 2018 s. 9) | App 18+; Children's Code: valutazione scritta |
| Piattaforme online | DSA (UE) | Online Safety Act 2023 / Ofcom | Valutazione del rischio per Mercatino/segnalazioni |
| Consumatori | Codice del consumo | Consumer Rights Act 2015, CCR 2013, DMCC Act 2024 | Recesso 14 giorni (contenuto digitale: consenso espresso); regime abbonamenti previsto da gennaio 2027 🟡 |
| Pubblicità | Autodisciplina IAP / AGCOM | ASA / CAP Code | Niente claim «diagnosi»; guida CAP sull'IA (2026) 🟡 |
| Veterinari | FNOVI, albi regionali | RCVS (Regno Unito), VSA 1966 | Nessuna diagnosi/prescrizione; ✅ s. 19 e 27 |
| Telemedicina veterinaria | normativa italiana (ricetta elettronica veterinaria) | Guida RCVS «under care», POM-V | L'app non prescrive; ❓ telemedicina non trattata nella guida letta |
| IA | AI Act (UE) art. 50 | Nessuna legge generale sull'IA 🟡 | Etichetta IA mantenuta per coerenza |
| Mercato vet | — | Indagine CMA (rapporto 24/03/2026) 🟡 | Attenzione a testi su costi/ricette |
| Autorità consumi | AGCM | CMA; Trading Standards | — |
| Giurisdizioni | Una | 4 sistemi (Inghilterra, Galles, Scozia, Irlanda del Nord) | Clausola di legge applicabile con l'eccezione per Scozia e Irlanda del Nord |

## Formati e linguaggio

| Voce | Italia | Regno Unito | Note |
|---|---|---|---|
| Lingua | it | **en-GB** (inglese britannico) | «colour», «favourite», «neutered», «vaccination», «microchip». Decisione: inglese unico con bandiere, ortografia britannica dove serve |
| Data | `gg/mm/aaaa` (es. 05/03/2026) | **`dd/mm/yyyy`** (05/03/2026) | Stesso ordine dell'Italia. Mese esteso: «5 March 2026». Il formato salvato verso il backend non cambia |
| Ora | 24 ore | 24 ore o 12 ore con am/pm (uso comune 12 ore a voce, 24 h nei trasporti) | Predefinito 24 ore; è una scelta del proprietario |
| Primo giorno della settimana | lunedì | lunedì | Uguale |
| Valuta | € (1.234,56 €) | **£** (£1,234.56) | Simbolo prima del numero; separatore migliaia «,»; decimale «.» |
| Prezzi | IVA inclusa | IVA (VAT) inclusa per i consumatori (da verificare) | Mostrare «incl. VAT» dove serve |
| Distanza | km | **miglia (miles)** per strade e passeggiate; km accettato | Raggio del Mercatino: offrire miglia come predefinito per UK |
| Peso | kg | **kg** per i veterinari; uso comune di lb/stone (per persone e a volte cani) | Predefinito kg; l'opzione lb è una scelta del proprietario |
| Temperatura | °C | °C | Uguale |
| Telefono | `+39 3xx xxx xxxx` / `0x xxxx` | `+44 7xxx xxxxxx` (cellulare), `0xxxx xxxxxx` (fisso); prefisso nazionale 0, prefisso internazionale +44 | Esempio fittizio: `07700 900123` (intervallo riservato a finzione Ofcom — da verificare) |
| Indirizzo | via, civico, CAP, città | numero civico + via, città, **postcode** (es. «SW1A 1AA») | Il postcode ha formato variabile; il campo CAP deve diventare «Postcode» |
| Città | provincia | contea (county) opzionale | Non obbligatoria |
| Numero d'emergenza persone | 112 | 999 (e 112 funziona) | Non confondere con animali: doc 06 |
| Veterinario | «veterinario» | «vet» / «veterinary surgeon» | Usare «vet» nel testo |
| Microchip | obbligatorio per i cani | obbligatorio per i cani; per i gatti in Inghilterra obbligatorio dal 10/06/2024 (da verificare) | Contenuti informativi; non è un obbligo dell'app |
| Passaporto animali | Passaporto europeo | Il UK ha un regime diverso dopo la Brexit (da verificare) | Contenuti sui viaggi vanno verificati |
| Autorità animali | ASL, Comune | Local authority, RSPCA, polizia | Doc 06 |
| Riconoscimento delle razze | ENCI | The Kennel Club | Dati razze: non toccati |
| Vaccini | calendario italiano | Schemi dei veterinari UK (es. «booster», «kennel cough») | Contenuti informativi |
| Termini d'uso | «Termini di Servizio» | «Terms of Service» | Uguale concetto |

## Cosa cambiare nell'app (indicativo, per la sessione Formati e store)

1. Valuta per paese: £ nei piani (`billing_models.dart`: oggi `symbol: '€'` fisso) e nel Mercatino.
2. Distanze: miglia/km in base al paese.
3. Campo indirizzo: «Postcode».
4. Numeri utili per paese (doc 06).
5. Consensi per `en-GB` (doc 04).
6. Etichette IA e disclaimer (doc 05).
