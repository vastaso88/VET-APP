# Revisione del ramo MULTILANG (erykwest)

Data: 2026-10-13. Oggetto: `origin/main...origin/MULTILANG` (84 file, ~29.000 righe).
Revisione fatta in sola lettura da 4 revisori indipendenti (backend, traduzioni EN,
traduzioni ES, coerenza con la nostra predisposizione + workflow CI). Nessuna modifica
è stata fatta sul ramo di erykwest. I rapporti completi (con file:riga, testi e
correzioni proposte) sono in `side-session-notes/.../multilingua_coordinatrice/`
(`rev_backend.md`, `rev_en.md`, `rev_es.md`, `rev_coerenza_ci.md`).

Come leggere: **verificato** = provato con test o lettura del codice; **sospetto** = da confermare.

## Esito in breve

- Test sulla copia di MULTILANG: 957 test Python passati, 1 fallito solo per un artefatto
  dell'estrazione (non del ramo); `check_i18n` OK; `ruff check` pulito; `flutter gen-l10n`
  su `app_es.arb` senza errori. `flutter analyze/test` non eseguiti (Flutter 3.44 qui, la CI usa 3.47).
- Traduzioni EN/ES: tutte e 1.355 le chiavi presenti, placeholder e plurali ICU a posto,
  nessun errore bloccante. Qualità buona; restano 2 punti alti e ~22 medi (vedi sotto).
- **1 problema bloccante nel backend** (regressione sull'italiano nella chat) e diversi alti
  su emergenze, CI e lingua.
- Sicurezza: `/account/preferences` è solo del proprietario (identità dal token, nessun
  `user_id` nel body, lingue validate); nessun segreto né dato personale nel diff; nessuna
  interpolazione non fidata nei workflow; i segreti non vengono mai stampati.

## BLOCCANTE (da segnalare a erykwest prima del merge in main)

**B1 — La chat italiana peggiora: parole comuni scambiate per specie.**
`packages/core/application/services/chat_orchestrator.py` (`SPECIES_WORD_TO_FAMILY` ~riga 398-444,
usata da `_effective_species` ~riga 1023 e dal controllo multi-animale): le nuove voci `pez`,
`loro`, `cat`… vengono cercate come *parte di parola* (`word in message`). Verificato
leggendo il codice: con profilo Cane, "Ha mangiato un **pez**zo di cioccolato" viene letto
come "pesce", la specie cambia e non scatta il triage che su main scatta; "**cat**tivo" → gatto,
"**loro**" → uccello. È un rischio sanitario reale (avvelenamento non riconosciuto).
Correzione: confronto per parola intera (regex con confini di parola) e togliere `loro`;
aggiungere test di non regressione italiani ("pezzo di cioccolato", "Accidenti", "cattivo", "loro").

## ALTO

Backend (sicurezza dell'animale):
- **A1** `"accident"` come sottostringa (`safety_gate.py:23`): scatta su "Accidenti…" italiano e su
  "had an accident in the house" → domande/triage fuori luogo. (verificato)
- **A2** Corrispondenza approssimata troppo larga: "I'm raising a puppy" → `raisins`,
  "drapes" → `grapes`, "pasas" in "si pasas por…" → falso allarme avvelenamento. (verificato)
- **A3** `"hi"` come sottostringa nei saluti (`chat_orchestrator.py` ~340, ~1995): "my dog is
  shivering", "something is wrong with him", "mi perro come hierba" diventano chiacchiere e
  saltano l'anamnesi. (verificato)
- **A4** `classify_severity` ignora le negazioni: "he has not recovered", "not breathing
  normally", "no respira normal" → risposta rassicurante. Difetto già presente in italiano,
  esteso a EN/ES. (verificato)
- **A5** `ConsentInterpreter`: "Of course not", "por supuesto que no", "Yes, but don't look at
  it" interpretati come **sì** → la cartella clinica andrebbe all'IA esterna senza vero consenso. (verificato)
- **A6 / C-consensi** I testi di consenso EN/ES sono serviti come testo legale con le stesse
  versioni v1/v2 dell'italiano, senza registrare in che lingua l'utente li ha visti e senza
  revisione legale (è stato tolto il vincolo "solo dopo approvazione legale"). Da coordinare con
  le sessioni legali: versione per lingua e lingua salvata nel `ConsentRecord`. (verificato)

App / lingua:
- **C1** Il backend accetta solo `it/en/es` in `response_locale` (`apps/api/schemas/chat.py:16`,
  `Literal`): aggiungendo de/fr la chat risponde errore 422; anche "en-GB" darebbe 422. (verificato)
- **C2** Scelta lingua fatta offline persa al riavvio: il salvataggio sull'account fallisce in
  silenzio e `bootstrap.dart:61` fa vincere l'account. (verificato)
- **C3** Avvio lento senza rete: `bootstrap.dart:61` attende `getUser()` (timeout 5 s) prima di
  `runApp`; basta leggere `currentUser.userMetadata` in locale. (verificato)

Workflow:
- **D1** `translation-drafts.yml:3-11` parte anche da `push` su main e MULTILANG e usa
  `DEEPL_API_KEY` come secret di repository (non di environment): il requisito "solo manuale"
  non è rispettato. Va resa `workflow_dispatch` e il secret spostato in un environment. (verificato)

Traduzioni:
- **T1** `marketplaceFieldPrice` = "Price in €" per UK/US/AU: decisione di prodotto (valuta per paese).
- **T2** "Uploading"/"Carga" al posto di "Loading"/"Cargando" in `sharedLoadingLabel`,
  `remindersLoadingLabel`, `medicalStateLoadingPill` (in ES anche "Carga" per upload: usare "Subida"). (verificato)

## MEDIO

Backend:
- Red flag EN/ES non alla pari dell'italiano: nessuna normalizzazione di accenti
  ("sangre en el vómito") né dell'apostrofo iOS ("can’t breathe"); in ES mancano "respira con
  dificultad", "colapsó/se desmayó", "atropellado", "no hace pis"; in EN "isn't/stopped breathing",
  "can't pee", "blood in his vomit", "hit by a car", "pale gums". I marker di escalation
  immediata funzionano solo se un altro flag è già scattato. (verificato)
- In TUTTE le lingue (italiano compreso, pre-esistente) mancano: veleno per topi/antigelo,
  torsione gastrica, investimento, gengive pallide, gigli (lilium). Gatto+cioccolato scatta in
  EN/ES ma non in IT. (verificato)
- `request_kind.py` e `EVIDENCE_KEYWORDS`: marker corti come sottostringa (`read`, `tos`, `pain`,
  `itch`, `tick`): "explain my dog's blood test" → sintomo; "kitchen" → domanda clinica. (verificato)
- Protezione dosaggi EN/ES stretta ("how much metacam should I give", "what dosage", "cuantos mg"). (verificato)
- `record_marker` "I cannot read" troppo generico. de/fr accettati in ingresso ma testi fissi in italiano.
- Test mancanti: solo "respiro" è coperto in EN/ES; nessun test su tossici, convulsioni,
  emorragia, urinario, collasso, escalation immediata, dosage-guard, riepilogo vet EN/ES.

App / CI:
- `pubspec.lock` cambia 5 pacchetti (intl 0.20.3, meta, vector_math, matcher, test_api) per il
  Flutter 3.47.6 della CI: con 3.44 `pub get` lo riscrive. Tocca il lock, noi non dovremmo bumpare.
- Prima installazione: la pagina lingua obbligatoria marca la scelta come "esplicita", quindi su
  un telefono nuovo la lingua dell'account non viene ripristinata; al logout la lingua non si azzera.
- Riformattazione a 80 colonne dei file auth e `language_store` → rumore nei merge futuri;
  dopo il merge `auto_translate check` e `check_i18n` bloccano in CI ogni modifica a `app_it.arb`,
  `strings.xml`, `_MESSAGES` (manifest di 10.005 righe): serve un processo chiaro.
- DeepL: `restore_xml` richiede stesso ordine dei segnaposto; un singolo errore (o un 429) abortisce
  l'intera bozza e si perdono le chiamate già pagate; quoting ICU `'{'` non gestito (oggi non usato).
- Environment `firebase-testing` solo "preferibile" nel runbook; azioni pinnate a tag e non a SHA;
  file privati su disco prima di azioni di terzi. Servono revisori obbligatori e CODEOWNERS.
- Firma persistente: gli APK già installati con chiave debug non si aggiornano; `build_number`
  libero → rischio collisione con le build di main (contatore unico: prossima 31).
- Nessuna guardia contro URL di produzione per API/Supabase nelle build di test (il runbook li ammette).
- Conflitti con main: solo `ci.yml` (main ha aggiunto gli input `workflow_dispatch`); risoluzione banale.

Traduzioni EN: "Records" con due sensi nel dettaglio animale; "Italy" precompilato in
`settingsHomeCountryDefault` (anche ES "Italia", `settings_page.dart:1236`); hint data fisso
"dd/mm/yyyy" (rischio US); "Stories" per "Curiosità" → "fun facts"; "Free gift" → "Free";
ortografia mista US/UK (behavior/color vs cancelled/medicines: scegliere uno standard);
"libretto sanitario" → "health record" (meglio "vaccination record"); `authHubTitle` "within paw's reach" sgrammaticato.

Traduzioni ES: "informe/informado" per "segnalazione" in 38 chiavi della community
(→ "aviso/denuncia"); `remindersRelativeToday` "Hoy" maiuscolo a metà frase (verificato);
"Ciclo"/"Tratamiento" incoerenti; `authRegisterTermsRequired` non coincide con la casella;
`petsEditMemorialMessage` cita "lista Mascotas" ma la scheda è "Animales"; `walksFavoriteEvictBody`
ambiguo ("quitar de favoritos"); `localEventsReportMissing` perde "Segnala!"; "responsables" vs
"propietarios"; `vuestro/vuestros` in app tutta in "tú"; "durante N veces".
Nota: il manifest registra l'ES come "esistente, non ritradotto" → non è output DeepL verificabile;
i testi legali vanno riletti da un madrelingua.

Contenuti solo italiani (non errori di traduzione ma decisioni di prodotto, vedi PIANO): eventi,
regioni/province, fonti dati, "throughout Italy", dati demo Milano.

## BASSO (elenco sintetico, dettagli nei rapporti)

`/account/preferences` non usato dall'app (che scrive su Supabase metadata) e read-modify-write
non atomico; stato di processo nel `BootstrapAuthProvider`; voce morta "sangre en" in
`triage_clarification.py`; `ruff format` da sistemare in `weight.py` e `supabase_auth_provider.py`;
manifest candidato conta le bozze come aggiornate e `acknowledge` non registra chi ha revisionato;
debug APK con retention 90 giorni; mancano test statici sugli YAML e test su 429/riordino
segnaposto; ~17 rifiniture EN e ~18 ES (maiuscole, punteggiatura, "Hacer foto", ecc.).

## Cosa NON è emerso

Nessun permesso Android CAMERA/READ_MEDIA_*; nessun `resConfigs`/filtro ABI; `check_i18n` è
più severo, non più permissivo; niente script injection nei workflow; nessuna push automatica
dalla pipeline di traduzione (produce solo un artifact, limite 100 coppie voce-lingua, verso
DeepL solo testi dell'interfaccia: niente dati utente né testi legali).

## Per aggiungere DE/FR sopra MULTILANG (lista da estendere a mano)

`AppLanguageContext.kt:14` (`setOf("it","en","es")`), `values-de`/`values-fr`,
`check_i18n.py:~338`, `tests/unit/test_native_localizations.py:15`, `auto_translate.LANGUAGES`,
**`auto_translate.py:~129`** (manda `ES` a DeepL per ogni lingua diversa da en: il tedesco verrebbe
tradotto in spagnolo), glossari nel workflow, `response_locale` e `localization.py`
(oggi `de` → "it"). Il selettore lingua e `supportedLocales` si adeguano da soli.

## Ordine di intervento consigliato

1. **Prima del merge in main (a carico di erykwest):** B1, A1–A5, D1, C1, T2.
2. Con le sessioni legali: A6 (versioni e lingua dei consensi).
3. Poi: C2/C3, red flag mancanti e test EN/ES, correzioni di traduzione medie, guardia contro
   URL di produzione, SHA delle azioni, CODEOWNERS.
