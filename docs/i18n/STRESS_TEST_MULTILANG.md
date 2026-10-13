# Stress test delle lingue di MULTILANG (it, en, es)

Data: 2026-10-14. Codice provato: `origin/MULTILANG` 176fc3f, in copie scrivibili estratte da git
(nessun commit, nessuna modifica al repo). Tutto in locale: `SUPABASE_URL` vuoto, dati e LLM finti, niente Groq.
Flutter locale 3.44.1 (la CI usa 3.47): misure di layout approssimate, i casi a pochi pixel vanno confermati su dispositivo.

Materiale (fuori dal repo, in `side-session-notes/.../multilingua_coordinatrice/stress/`):
rapporti completi `st_area1..4.md`; script e test (`st_area1_scripts`, `st_area2_tests`, `st_area3_tests`,
`backend_stress.py` + output); **1.440 screenshot** in `screens/{it,en,es}/` (480 per lingua, es. `home_360x640_s1.0.png`,
`_full` = pagina intera; mappe grigie e bandiere come riquadri perché offline); `../repro_multilang.py`.

## Esito in breve

| Area | it | en | es | Giudizio |
|---|---|---|---|---|
| 1 Base: pytest / ruff / analyze / flutter test | ok | ok | ok | 957 pytest ok, 709 Flutter ok; **1 test Flutter rosso** (D1) |
| 1 ARB: 1.355 chiavi, placeholder, plurali ICU, vuote, apostrofi | ok | ok | ok | nessun difetto; ritocchi bassi |
| 1 Android `strings.xml` | ok | ok | ok | stesse 18 chiavi e segnaposto |
| 2 Schermate (80 pagine/stati × 2 viewport × 2 scale) | 1 alto | problemi medi | problemi medi | 41 overflow reali, 108 etichette tagliate |
| 3 Cambio lingua a runtime, stato, persistenza | ok | ok | ok | regge; 2 difetti sulla scelta offline e sulle varianti |
| 3 Paese (en-GB/US/AU): data, valuta, indirizzo, paese | – | **problemi** | problemi | valuta € e data dd/MM fisse; "Italy" precompilato |
| 3 Notifiche e widget Android | ok | ok | ok | testi dalla lingua dell'app; canali restano nella prima lingua |
| 4 Backend: red flag (66 frasi/lingua) | 25/66 | 21/66 | 25/66 | **copertura insufficiente** |
| 4 Backend: consenso, specie, dosaggi, intent | problemi | problemi | problemi | vedi sotto |
| 4 API `response_locale` con varianti | – | **422** | **422** | 9/9 varianti rifiutate |

Test nuovi scritti: 103 su cambio lingua/paese (89 ok, 14 falliscono volutamente: ognuno riproduce un difetto),
e la batteria di 1.920 esecuzioni schermate. Non verificabile qui: dispositivo/emulatore Android, consegna reale delle
notifiche, Supabase reale, picker di sistema, LLM reale, app web nel browser (punto 6 facoltativo: non fatto).

## Difetti, per gravità

### BLOCCANTE

**B1 — specie letta come pezzo di parola (già nel messaggio a erykwest, punto 1).** Esteso: oltre a perdere l'allarme tossici
(profilo Cane + parola-trappola: allarme perso in 7/8 frasi it, 1/8 en, 3/8 es), scarta anche risposte LLM corrette sostituendole
con "non ha superato i nostri controlli di sicurezza" (6/6 casi: "he takes medication daily, is it a concern?", "¿tiene catarro, es grave?").
Correzione: parola intera in `_effective_species`, `_describes_independent_multi_pet_complaint` e `_mentions_wrong_species`.

### ALTO

- **A1 Copertura red flag (backend).** it 25/66, en 21/66, es 25/66 (triage o chiarimento). Categorie a 0/4 in TUTTE le lingue:
  veleno per topi/avvelenato, antigelo, lilium (gatti), torsione/gonfiore, gengive pallide/blu. EN: sangue nel vomito 0/4;
  EN e ES: urina bloccata 0/4. Correzione: ampliare le liste e normalizzare accenti e apostrofi.
- **A2 Escalation.** 13 dei 24 marker di emergenza immediata (incosciente, gengive blu…) sono inerti da soli (scattano 1/7 it, 2/7 en, 2/7 es).
  "non respira" (it) dà solo un chiarimento, "no respira"/"not breathing" danno triage: incoerente.
- **A3 Negazioni nelle risposte ai chiarimenti** (`classify_severity`): risposte corrette 8/20 it, 11/20 en, 10/19 es; rassicura quando doveva
  escalare in 12/15, 9/15, 9/14 ("he has not recovered", "no se ha recuperado").
- **A4 Consenso**: "of course not", "por supuesto que no", "certo che no", "yes but don't look at it", "sí y no" → SÌ. Solo con `ENABLE_INTERVIEW_LOOP=true` (oggi false).
- **A5 Apostrofo tipografico ’** (iOS): "he can’t breathe" non scatta (tutte e 4 le keyword EN con apostrofo).
- **A6 Falsi allarmi**: "I'm raising a new puppy" (raisins), "he chewed the drapes", "my chocolate lab", il nome "Oki", "si pasas por aquí",
  "mi vecino tiene un ajolote"; con chiarimento: "accidenti", "had an accident in the house", "terreno accidentado".
- **A7 Protezione dosaggi**: intercettate 5/15 it, 5/15 en, 4/15 es ("how much metacam should I give", "cuantos mg de metacam le doy", "quante gocce…" passano).
- **A8 "hi" come sottostringa**: in EN 10/20 frasi cliniche brevi diventano small talk ("my dog is shivering", "he is so thin"); in ES "mi perro come hierba".
  "buenas" e "vale" non riconosciuti come saluti.
- **A9 `response_locale` → 422** per en-GB, en-US, en-AU, es-MX, es-ES, EN, ES, en_GB, Es-mx (9/9). Valgono solo it, en, es, null.
- **A10 "Residenza abituale" precompila "Italy"/"Italia"** (`settings_page.dart:1236`, `settingsHomeCountryDefault`): il geocoder riceve il paese sbagliato (nostro: paese dedotto dal dispositivo, deciso dall'Orchestratore).
- **A11 Schermata "Prova gratuita · 10 giorni"** (`plan_intro_page.dart:112`): riga icona+titolo senza `Expanded`; in it sfora già a 360×640 scala 1.0 (2,9 px), 80 px a 1.3; anche en/es a 320. Correzione: `Expanded`.

### MEDIO

- **M1** Test Flutter rosso su MULTILANG: `test/language/language_choice_test.dart:83,88` cerca `find.text('LINGUA')` ma il titolo è `🇮🇹 LINGUA · ITALIANO` (`multilingual_widgets_test.dart:37` già aggiornato). La CI Flutter sarebbe rossa. Correzione: cambiare l'attesa.
- **M2** Scelta lingua fatta offline persa al riavvio (`language_store.dart:107-131`): serve flag "scrittura account in sospeso" (= punto 10 già inviato).
- **M3** Dal selettore compatto un telefono it/es che sceglie "English" ottiene en-GB → miglia e libbre; il selettore dimentica la variante (en-AU → Español → English torna en-GB).
- **M4** Valuta fissa € in tutte le varianti (`billing_models.dart:64`, `marketplace_labels.dart:93`); date sempre dd/MM/yyyy anche nei campi digitati (`billing_page.dart:271`; `settingsNumericDatePattern`): per en-US serve MM/dd/yyyy.
- **M5** Notizie interrogate in italiano (`hl=it&gl=IT`, `pet_news_repository.dart:170`): in en/es i titoli sono italiani. Razze e pesci mostrati con nomi italiani in en/es. Eventi/regioni solo Italia. (Tema "Notizie, eventi, Mercatino per territorio".)
- **M6** Consenso: "yeah", "sure", "claro", "vale", "volentieri" registrati come RIFIUTO; "no problem", "no hay problema", "no me importa" letti come no; emoji 👍/👎 → nessuna risposta. Esatti: 20/38 it, 18/40 en, 17/40 es.
- **M7** Con de/fr il LLM risponde in tedesco/francese ma testi fissi, titoli automatici e riepilogo vet restano in italiano (data ISO, specie "Cane"). Il reindirizzo multi-animale esiste solo in italiano ("entrambi"). Sinonimi di specie non riconosciuti (puppy, kitten, perrito, cachorro, cobaya).
- **M8** Sovra-allarme con allarme negato: "he didn't eat any chocolate" → triage; 4/11 it, 7/11 en, 7/11 es.
- **M9** `POST /account/consents` non registra la lingua; versione condivisa tra le lingue (punto 7 già inviato).
- **M10** Overflow/troncamenti: dropdown specie nel form animale (`pet_profile_form.dart:389,513`, en/es 10-24 px a 1.3/320: `isExpanded: true`); `profile_page.dart:181` (solo it); chip categoria mercatino es a 320 (`home_dashboard_primitives.dart:155`); riga promemoria nel tab animale e titolo AppBar del Mercatino troncati a tutte le dimensioni; sottotitolo Layout/Località in Impostazioni tagliato già a 360×1.0; `pet_memories`, "segnala luogo", righe meta degli elenchi. Elenco completo (18 difetti con riproduzione) in `st_area2.md`.

### BASSO (sintesi)

`ruff format` su 3 file (`admin.py`, `weight.py`, `supabase_auth_provider.py:83`); mypy rosso solo senza extra `privacy` (presidio); scripts i18n usano `Path.resolve()` (crash con percorsi lunghi/subst su Windows: preferire `absolute()`);
ellissi `...` vs `…` (17 chiavi) e virgolette ES miste; 6 testi ES oltre 1,6× (`authLoginTitle` 2,45×, `eventsTypeShelterOpenDay` 2,44×);
canali di notifica Android restano nella lingua della prima notifica, widget/notifica passeggiata non si rinfrescano al cambio lingua, elenco Kotlin `{it,en,es}` da estendere per de/fr;
`/legal/consents` ignora Accept-Language; avvio ritarda fino a ~5 s con rete lenta (`bootstrap.dart:61`, misurato 4-7 s);
5 chiavi `common*` non usate; `general_limit[it]` è in inglese; titoli automatici delle chat solo italiani; marker "I cannot read" troppo generico.
Sospetti da confermare su dispositivo: overflow di 107 px sui dropdown del form animale in en-GB; messaggi d'errore tradotti conservati nello stato (`settings_page.dart:196,1271`).

### Osservazione importante

`VetApp.builder` (`lib/app/app.dart`) sostituisce il `textScaler` di sistema con `larghezza/339`: l'app ignora la dimensione del testo di sistema (letto dal codice, non provato su dispositivo). La scala 1,3 è quindi uno stress ipotetico, ma i difetti a 1,0 (A11) sono reali.

### Cosa regge (verificato)

ARB completi e coerenti (1.355 chiavi × 3 lingue, 189 metadata, plurali `=1/other`); cambio it→en→es→it senza perdere stato su login, registrazione, form animale, promemoria, bozza chat, Impostazioni, billing, tab del dettaglio animale; persistenza e precedenza sessione > account > dispositivo > telefono > it; telefoni ja/pt/de/fr/zh/ar → it; en-IE/en-NZ → GB/AU; unità predefinite per paese; testi delle notifiche dalla lingua dell'app e ripianificate al cambio lingua; nessun italiano hard-coded nei sorgenti Kotlin né nel codice UI di produzione; `/account/preferences` senza IDOR (401 senza token, 422 su 11 valori invalidi); `_MESSAGES` (56 chiavi) con fallback italiano corretto; cataloghi consenso EN/ES fedeli.

## Aggiunte al messaggio per erykwest (continuano la numerazione 1-11)

12. **Test rosso**: `test/language/language_choice_test.dart:83,88` cerca `LINGUA`, ora il titolo è `🇮🇹 LINGUA · ITALIANO`. Aggiornare l'attesa (la CI Flutter è rossa).
13. **Red flag mancanti in tutte le lingue**: veleno per topi, antigelo, lilium, torsione/gonfiore, gengive pallide/blu; EN: sangue nel vomito; EN/ES: urina bloccata. Aggiungere almeno 5 formulazioni per lingua con test. Esito misurato: it 25/66, en 21/66, es 25/66.
14. **Escalation da soli**: 13 dei 24 marker (incosciente, "unconscious", gengive blu) non fanno scattare nulla se non c'è già un altro flag: aggiungerli a `URGENT_RED_FLAG_KEYWORDS`.
15. **Normalizzazione del testo** prima dei match: accenti ("sangre en el vómito"), apostrofo ’ → ' ("can’t breathe"), maiuscole.
16. **Falsi allarmi**: "my chocolate lab", il nome "Oki", "terreno accidentado", "ajolote" → match per parola intera e liste di eccezioni (oltre ai punti 2-3).
17. **Dosaggi**: l'intercettazione è 4-5 su 15 per lingua. Casi da coprire: "how much metacam should I give", "what dosage of…", "cuantos mg de metacam le doy", "quante gocce di metacam devo dare".
18. **Consenso**: oltre al punto 6, riconoscere "yeah/sure/claro/vale/volentieri" come sì ed evitare che "no problem/no hay problema/no me importa" siano letti come no; 👍/👎. Ricordare che oggi il flusso è attivo solo con `ENABLE_INTERVIEW_LOOP=true`.
19. **Specie da parola intera anche in** `_describes_independent_multi_pet_complaint` e `_mentions_wrong_species` (le risposte LLM corrette vengono scartate); sinonimi (puppy, kitten, perrito, cachorro, cobaya); reindirizzo multi-animale anche in en/es.
20. **Saluti**: "buenas", "vale" non riconosciuti; "hi" come sottostringa (punto 4).
21. **Layout**: `plan_intro_page.dart:112` riga icona+titolo senza `Expanded` (sfora già in italiano a 360×640); `pet_profile_form.dart:389,513` dropdown con `isExpanded: true`; `profile_page.dart:181`. Dettagli e riproduzione: `st_area2.md`.
22. **Formati per paese** (li gestiamo noi, a valle): valuta € fissa, data dd/MM/yyyy fissa, paese "Italy" precompilato. Segnalarlo per non duplicare il lavoro.
23. **Lingue non italiane in chat**: titoli automatici, riepilogo vet (data ISO, specie "Cane") e testi fissi restano in italiano con de/fr; la lista `{it,en,es}` va estesa anche in `AppLanguageContext.kt` e `auto_translate.py` (punto 9).

Come riprodurre: backend `backend_stress.py` e `repro_multilang.py` (PYTHONPATH sulla radice del repo, `SUPABASE_URL` vuoto);
Flutter `flutter test test/stress/<file>.dart --dart-define=SUPABASE_URL=` (file in `st_area2_tests`, `st_area3_tests`; i test schermate usano font locali:
non committare font né modifiche a `pubspec`, vedi `tools/prepare_fonts.sh`).
