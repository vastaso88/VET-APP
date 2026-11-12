> **BOZZA — non è consulenza legale; da rivedere da un avvocato abilitato negli USA prima della pubblicazione**

# Differenze USA rispetto all'Italia

Confronto tra la versione italiana (docs/compliance/01–09) e la versione USA (01–06 in questa cartella). Dove non ho una fonte, la cella è marcata [N] (nozione generale, non verificata). Rimandi: `01` = 01_ricerca_normativa.md.

## 1. Quadro legale

| Tema | Italia / UE | USA | Impatto sui testi |
|---|---|---|---|
| Legge di base sulla privacy | GDPR (unica per tutta l'UE) + Codice privacy | Nessuna legge federale generale; ~20 leggi statali "comprehensive" + CalOPPA + COPPA + FTC Act (01, sez. 1) | La policy USA ha una sezione "diritti per stato" (02, sez. 9) invece di un unico elenco artt. 15–21. |
| Base giuridica | Contratto / consenso / interesse legittimo (art. 6) | Concetto assente: si descrivono finalità e si dà **opt-out** (consenso per i dati sensibili in molti stati) | 02 non cita "basi giuridiche". |
| Soglie | Nessuna soglia (si applica a tutti) | Soglie per stato; startup piccola spesso esclusa (ma non in TX/CT dal 2026-07) | Si applicano i diritti a tutti per prudenza. |
| Autorità | Garante privacy | Attorney General di ogni stato, CPPA (California), FTC | Il reclamo non va al Garante: 02 non lo cita. |
| Termine di risposta | 1 mese (art. 12) | 45 giorni (+45) in molti stati; 15 giorni lavorativi per opt-out in CA | 02, sez. 9. |
| Consenso marketing | Opt-in (GDPR/ePrivacy) | CAN-SPAM = opt-out; si tiene comunque l'opt-in | `marketing_email` invariato; serve indirizzo postale nelle email. |
| Minori | App riservata a maggiorenni | COPPA < 13 (con consenso genitoriale); 13–15 in CA opt-in alla vendita; si tiene **18+** | 02 sez. 2; 03 sez. 2. |
| Dati sensibili | Art. 9 (salute, ecc.) | Posizione precisa, salute (umana), biometria... variano per stato | La posizione GPS delle passeggiate è dato sensibile in molti stati. |
| Trasferimenti all'estero | Capo V GDPR | Nessun regime UE; il titolare italiano resta soggetto al GDPR [N] | Domanda al legale. |
| IA | AI Act, art. 50 | Section 5 FTC + leggi statali sui chatbot (CA, UT, ME, CO...) | 05 usa lo stesso badge `ai_generated`. |
| Rinnovi/abbonamenti | Diritto di recesso UE (14 gg), Codice del consumo | ROSCA + leggi statali (CA ARL dal 2025-07-01); "click-to-cancel" FTC annullato | 03, sez. 6. |
| Termini: clausole | Clausole vessatorie (artt. 33–34 Cod. consumo); foro del consumatore | Arbitrato e rinuncia a class action ammessi (FAA) con limiti; limitazioni di responsabilità variano per stato | 03, sez. 10–15: tutte *proposte*. |
| Veterinaria | Esercizio della professione veterinaria (L. nazionale) | 50 leggi statali, VCPR, telemedicina variabile (01, sez. 6) | 05: informazione e triage, mai diagnosi/prescrizione. |
| Store | Apple/Google | Apple/Google: stesse regole globali; nessuna aggiunta specifica USA oltre quelle in 01, sez. 8 | Cancellazione account, etichette di privacy, consenso IA di terzi. |

## 2. Formati e convenzioni per l'interfaccia in inglese americano

| Elemento | Italia | USA (en-US) | Note |
|---|---|---|---|
| Data | gg/mm/aaaa (es. 13/10/2026); formato salvato `05 mag 2021` **non cambia** | **mm/dd/yyyy** (es. 10/13/2026) | Cambia solo la visualizzazione; il formato salvato resta quello del backend (brief i18n). Nei testi legali: "MM/DD/YYYY". |
| Ora | 24 h | 12 h con AM/PM (es. 3:30 PM) [N] | Per promemoria e passeggiate. |
| Primo giorno della settimana | Lunedì | **Domenica** [N] | L'impostazione "week start" della Home potrebbe avere un default per paese. |
| Valuta | € (1.234,56 €) | **$** (U.S. dollars), 1,234.56 | Piani Plus/Pro: valori in $ segnaposto (03); tasse di vendita (sales tax) da definire. |
| Separatore decimale | virgola | punto | Anche nei pesi (es. 12.5 lb). |
| Distanza | chilometri | **miglia** (mi); piedi/yard per le brevi distanze | Raggio di ricerca nel Mercatino e nel radar: oggi in km → in miglia. Soglie del backend (es. 5 km) da convertire o da lasciare interne. |
| Peso | kg | **lb** (libbre) per animali e persone; oz per cibo | Il backend può continuare a salvare kg: conversione in visualizzazione. |
| Temperatura | °C | **°F** (cane/gatto sano ~99.5–102.5 °F [N]) | Triage che nomina una temperatura: usare °F. |
| Indirizzo | Via Roma 12, 00100 Roma RM | **12 Main St, Apt 4, City, ST 12345** (numero prima della via; sigla dello stato di 2 lettere; ZIP a 5 cifre) | Il filtro PII (`RuleBasedPiiAnonymizer`) riconosce "indirizzi con numero civico" italiani: va esteso con modelli USA (numero + via, ZIP). |
| Telefono | +39 333 123 4567 | **+1 (555) 123-4567**, 10 cifre | Il filtro PII per telefoni va esteso al formato USA. |
| Identificativo fiscale | Codice fiscale | Social Security Number (123-45-6789) [N] | Il filtro PII riconosce il codice fiscale; aggiungere SSN. L'app non dovrebbe mai chiederlo. |
| Paese precompilato | Italia | United States (dedotto dal dispositivo, modificabile; decisione 2026-10-13) | |
| Ortografia | — | Inglese americano: *color, neighbor, veterinarian, vaccinate, gray* | UK e AU hanno ortografie proprie. |
| Nome del veterinario | "dott./dott.ssa" | "Dr." / "DVM" | Non usare titoli professionali per l'assistente. |
| Termini sanitari | "libretto sanitario", "microchip", "antiparassitario" | "vaccination record" / "health record", "microchip", "flea & tick / heartworm prevention" [N] | Eventuali vaccini e profilassi hanno nomi e calendari diversi (rabbia obbligatoria per legge statale in molti stati [N]). |
| Farmaci | Principi attivi europei | Nomi commerciali USA; unità in mg/lb [N] | Il *dosage safety gate* deve evitare dosi; se serve un elenco di sostanze tossiche, includere **xylitol** (gomme/sciroppi), uva e uvetta, cioccolato, ibuprofene/acetaminofene, FANS umani [N]. |
| Numeri di emergenza | 112 | 911 (persone); centri veleni animali a pagamento (06) | |

## 3. Cosa resta uguale

- I tre consensi opt-in restano opt-in e disattivati di default (`marketing_email`, `analytics`), come i consensi per animale.
- Il principio "limitare la funzione, non bloccare l'app" al rifiuto di un consenso (docs/compliance/04).
- Il badge `ai_generated` e la distinzione tra risposte IA e risposte templata.
- La separazione tra contratto (Termini) e consensi.
- L'avvertenza che ogni testo legale è bozza fino a revisione di un legale locale.
