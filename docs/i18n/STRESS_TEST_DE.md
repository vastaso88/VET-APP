# Stress test tedesco (DE)

Il tedesco è la lingua con i testi più lunghi (fino a 2,5× l'italiano sulle etichette brevi): è il banco di prova del layout.

## Come è stato provato
- Harness `AREA 2` della sessione "Multilingua" (80 pagine/stati × 2 viewport 360×640 e 320×568 × 2 scale testo 1,0 e 1,3 × pass normale e "tall" 3200 px) con locale `de`: **640 esecuzioni, 0 non montate, 0 eccezioni** diverse da layout. Dati finti/in-memory, `SUPABASE_URL` vuoto, nessuna rete.
- La scala 1,3 è uno stress: `VetApp.builder` sostituisce il `textScaler` di sistema con larghezza/339 (clamp 0,85–1,35), quindi l'app oggi ignora la dimensione testo di sistema.
- Font reali non disponibili offline: Roboto al posto di Figtree, Georgia Bold al posto di Fraunces (misure approssimate; i casi sotto i 5 px vanno confermati su dispositivo). L'harness e i font NON sono nel repository (dipendono da asset locali e da Georgia, non ridistribuibile): sono in `side-session-notes/…/traduzione_de/stress_tests_de/` e si lanciano con `STRESS_LANGS=de flutter test test/stress/<file>` (vedi `docs` dell'area 2).
- Screenshot (480 PNG, `<pagina>_<WxH>[_full]_s<scala>.png`): `side-session-notes/…/traduzione_de/screens/de/`.
- Test committati: `test/language/german_formats_test.dart` (data `dd.MM.yyyy`, virgola decimale, unità metriche, plurali) e `multilingual_widgets_test.dart` (login/registrazione/impostazioni in `de` a 360 px, nessuna eccezione).

## Risultati (prima → dopo l'accorciamento delle traduzioni)
Overflow RenderFlex: **62 esecuzioni (17 punti di codice) → 40 (13 punti)**. A scala 1,0 rimangono solo 3 punti, tutti **indipendenti dalla lingua** (stessi px in IT/EN/ES):
- `home_dashboard_page.dart:492` marker del giorno: 0,6 px a 320.
- `pet_detail_page.dart:1736` stato vuoto scheda acquario: 4 px a 320×568.
- `pet_profile_form.dart:1097` contatore sesso acquario: 10 px a 320.

A scala 1,3 (solo stress) restano gli stessi difetti strutturali già noti in IT/EN/ES: `pet_profile_form.dart:389` (Dropdown specie senza `isExpanded`), `home_dashboard_primitives.dart:155` (chip categoria mercatino), `profile_page.dart:181` (riga Indietro/Impostazioni), `pets_scaffold.dart:57` (probabile falso positivo, font Ahem), `plan_intro_page.dart:112` (titolo card prova senza `Expanded`: 154 px → 8–19 px con la traduzione breve). Non corretti: il layout è dei file di erykwest e il difetto non è del tedesco.

## Traduzioni accorciate per evitare overflow (solo DE)
| chiave | prima | dopo | motivo |
|---|---|---|---|
| `firstRunTrialCardTitle` | Kostenlose Testphase — 10 Tage | 10 Tage gratis testen | overflow 60 px a 360×640 s1,0 (primo schermo del nuovo utente) |
| `walksDurationMinutes` / `walksDurationHoursMinutes` | `{n} Min.` / `{h} Std. {m} Min.` | `{n} min` / `{h}h {m}min` | statistiche del dettaglio passeggiata: 27 px |
| `remindersCreateButton` | Anlegen | Neu | intestazione elenco promemoria: 7 px a 320 s1,3 |
| `firstRunNotificationsBody` | testo lungo | testo più breve | overflow verticale 36–62 px a s1,3 |
| `remindersKindOptionRecurring` / `remindersKindRecurring` | Wiederkehrend | Wiederholt | chip troncato a 320 s1,0 |
| `profileNoActiveSession`, `settingsNoActiveSession` | Keine aktive Sitzung | Keine Sitzung | troncato a tutte le dimensioni |
| `profilePhoneNotSet`, `profileCityNotSet` | Nicht angegeben | Keine Angabe | troncato a 320 |
| `settingsLayoutWeeksTitle` / `…Subtitle` | testi lunghi | Wochen auf der Startseite / Anzahl der Wochen im Startseiten-Kalender. | troncati a 320 |

## Troncamenti noti rimasti (uguali in IT/EN/ES, scala 1,0)
Riga meta degli elenchi (`home_dashboard_primitives.dart:310`), meta dei promemoria in `pet_detail_page.dart:1675`, titolo mercatino in AppBar (`marketplace_page.dart:118`), nota "Solo il nome…" (`report_missing_place_page.dart:155`), "Con noi dal…" (`pet_memories_page.dart:144`). Soluzione di layout (`maxLines: 2`), non di traduzione.

## Varianti paese
- Il picker offre 🇩🇪 `de` (Deutschland), 🇦🇹 `de-AT` (Österreich) e 🇨🇭 `de-CH` (Schweiz): stessa traduzione `app_de.arb`, data `dd.MM.yyyy` per tutte; il paese predefinito è quello del telefono (`suggestLanguageVariant`: de-AT/de-CH se il dispositivo è AT/CH, altrimenti DE). Unità metriche; separatore decimale da intl: virgola per DE/AT, punto per CH (uso svizzero).
- CH con "ss" al posto di "ß": NON fatto. Richiederebbe un secondo catalogo `app_de_CH.arb` (check_i18n, test e auto_translate assumono `app_xx.arb`); le parole con ß sono poche e lette senza problemi in Svizzera.

## Altro
- Test Dart `language_choice_test.dart` ("the Settings section exists only with two translations") fallisce **anche senza `app_de.arb`**: preesistente su MULTILANG, non causato dal tedesco.
- Registro: Sie-Form (come richiesto dall'Orchestratore). Cambiarlo in "du" richiede una nuova passata sui ~270 testi con "Sie/Ihr".
