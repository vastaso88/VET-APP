> **BOZZA — non è consulenza legale; da rivedere da un avvocato locale prima della pubblicazione**

# Differenze Germania rispetto all'Italia

Data: 2026-10-14. Le voci «conoscenza generale» sono da verificare; quelle con ✅ sono confermate nei doc 01/06. Per Austria e Svizzera vedi `../at/07_*` e `../ch/07_*`.

## Legale

| Tema | Italia | Germania | Effetto su VetApp |
|---|---|---|---|
| Legge sui dati | GDPR + Codice privacy; Garante | GDPR + BDSG + TDDDG; 16+ autorità (una per Land) | Informativa tedesca propria (doc 02, 04); reclamo all'autorità del Land o al Garante (capofila) |
| Rappresentante UE | — | Non serve: titolare italiano è nell'UE | Nessun segnaposto di rappresentante |
| DPO | art. 37 GDPR | art. 37 GDPR + § 38 BDSG (soglia 20 persone, 🟡) | Dipende dal titolare italiano ⚖️ |
| Età digitale | 14 anni per il consenso | 16 anni (art. 8 GDPR, 🟡) | App 18+; capacità negoziale dei minori (§§ 104 ss. BGB) |
| Cookie / dispositivo | Codice privacy / Provvedimento Garante | **§ 25 TDDDG** (✅ via fonte secondaria), OH Digitale Dienste 1.2 (11/2024) | Consenso solo per strumenti non necessari; pulsanti pari rilievo |
| Impressum | art. 7 D.Lgs. 70/2003 (🟡) | **§ 5 DDG** ✅ (8 voci, e-mail, no casella postale) | Voce «Impressum» raggiungibile; dati del titolare italiano |
| Prezzi | Codice del consumo | **PAngV**: prezzo totale con IVA 🟡 | «inkl. MwSt.»; vedi doc 03 §4 |
| Recesso | 14 giorni | 14 giorni; perdita anticipata per servizi/contenuti digitali (§ 356 BGB ✅); **Widerrufsbutton dal 19/06/2026** (§ 356a BGB 🟡) | Funzione «Vertrag widerrufen» nella web app |
| Pulsanti | art. 49 Codice consumo (🟡) | **Button-Lösung** § 312j ✅, **Kündigungsbutton** § 312k ✅ | «zahlungspflichtig bestellen»; «Verträge hier kündigen» / «jetzt kündigen» |
| Prodotti digitali | D.Lgs. 173/2021 (🟡) | §§ 327 ff. BGB (🟡) | Aggiornamenti e conformità |
| AGB | Clausole vessatorie | §§ 305–310 BGB (Inhaltskontrolle forte) | Responsabilità: schema tedesco (doc 03 §11) |
| Conciliazione | ADR/ODR | § 36 VSBG: dichiarazione (🟡); piattaforma ODR UE chiusa 20/07/2025 (🟡) | Dichiarazione nei termini |
| IA | AI Act (UE) art. 50 | idem, autorità di vigilanza tedesca (Bundesnetzagentur? ❓) | Etichetta IA obbligatoria dal 02/08/2026 |
| Accessibilità | D.Lgs. 82/2022 | **BFSG** dal 28/06/2025 (esenzione microimprese per servizi, 🟡) | ⚖️ quale legge e se si è esonerati |
| Piattaforme | DSA + AGCOM | DSA + **DDG** (ex TMG) | Segnalazioni, motivazione rimozioni |
| Veterinari | FNOVI, albi regionali; ricetta elettronica veterinaria | Tierärztekammern dei Länder; **BTK 2020** ✅ | Nessuna diagnosi/prescrizione; ✅ TAMG § 30 |
| Telemedicina veterinaria | normativa italiana | BTK: al massimo diagnosi di sospetto, **niente Rx a distanza**; legata a una sede veterinaria ✅ | L'app non prescrive |
| Farmaci online | ricetta elettronica | TAMG § 30: **vietata la vendita a distanza dei Rx** ✅ | Nessun rimando a shop di farmaci Rx |
| Animali (vendita) | Legge e Regioni | **§ 11 TierSchG** per il commercio professionale ✅; eBay Kleinanzeigen richiede la § 11 per cani/gatti < 12 mesi (🟡) | Mercatino senza animali vivi |
| Giurisdizione | Una | 16 Länder per vigilanza e Tierärztekammern | Clausola di legge applicabile (doc 03 §15) |

## Formati e linguaggio

| Voce | Italia | Germania | Note |
|---|---|---|---|
| Lingua | it | **de-DE** (tedesco, **Sie-Form**) | Termini: «Tierarztpraxis», «Tierklinik»; evitare anglicismi superflui. Una sola traduzione tedesca di UI per DE/AT/CH; i testi **legali** hanno invece versione propria per regione |
| Data | `gg/mm/aaaa` | **`dd.MM.yyyy`** (14.10.2026) | Mese esteso: «14. Oktober 2026». Il formato salvato verso il backend non cambia |
| Ora | 24 ore | 24 ore (`14:30 Uhr`) | Uguale |
| Primo giorno della settimana | lunedì | lunedì | Uguale |
| Valuta | € (1.234,56 €) | **€** (1.234,56 €) | Stesso formato; IVA 19% / 7% (🟡 aliquote di base; da verificare, i servizi digitali ai consumatori seguono la regola del luogo del consumatore, OSS: ⚖️) |
| Prezzi | IVA inclusa | **Gesamtpreis inkl. USt.** (PAngV 🟡) | «inkl. MwSt.» |
| Distanza | km | **km** | Uguale |
| Peso | kg | **kg** | Uguale |
| Temperatura | °C | °C | Uguale |
| Telefono | `+39 3xx xxx xxxx` | `+49 1xx xxxxxxx` (cellulare), `030 12345678` (fisso); prefisso nazionale 0 | Esempio fittizio: `030 1234567` (non verificato che il numero sia riservato a finzione ❓) |
| Indirizzo | via, civico, CAP, città | **Straße + Hausnummer, PLZ (5 cifre), Ort** (`Musterstraße 1, 12345 Musterstadt`) | Campo «PLZ» invece di CAP; Bundesland opzionale |
| Numero d'emergenza persone | 112 | 112 (polizia 110) | Non confondere con animali: doc 06 |
| Veterinario | «veterinario» | «Tierarzt/Tierärztin», «Tierarztpraxis» | Usare forma neutra in UI se possibile |
| Microchip | obbligatorio per i cani | obbligo di marcatura per cani non uniforme nei Länder; registro volontario (TASSO, FINDEFIX) (🟡/❓) | Contenuti informativi; non è un obbligo dell'app |
| Passaporto animali | Passaporto europeo | Passaporto europeo (UE) | Uguale |
| Autorità animali | ASL, Comune | Veterinäramt (Landkreis/kreisfreie Stadt) | Doc 06 |
| Razze | ENCI | VDH / FCI | Dati razze: non toccati |
| Termini d'uso | «Termini di Servizio» | «Nutzungsbedingungen» (AGB) | Uguale concetto |
| Politica privacy | «Informativa» | «Datenschutzerklärung» | |
| Avviso IA | — | «KI-Hinweis» | |

## Cosa cambiare nell'app (indicativo, per la sessione Formati e store)

1. Voce «Impressum» nelle Impostazioni e nello store.
2. Campo indirizzo: «PLZ» (5 cifre) e «Straße + Hausnummer».
3. Numeri utili per paese (doc 06): niente numero «avvelenamenti animali» per la Germania.
4. Consensi per `de-DE` (doc 04); lingua mostrata salvata.
5. Etichette IA e disclaimer (doc 05).
6. Pulsanti di ordine, disdetta e recesso sulla web app (doc 03 §5).
7. Mercatino: tolto «animali vivi» nella UI della Germania.
