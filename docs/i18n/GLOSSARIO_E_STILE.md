# Glossario e guida di stile per lingua

Due cose da tenere uguali in ogni lingua: **le parole** (glossario) e **il modo di parlare** (guida di stile). Valgono per chi traduce a mano,
per le bozze automatiche DeepL (`scripts/i18n/auto_translate.py`) e per chi rilegge una bozza.

## 1. Glossario

La sorgente è `docs/i18n/glossary.json`; la tabella qui sotto è **generata** (`python scripts/i18n/glossary.py render`) e un test fallisce se
non è aggiornata. Per cambiare un termine si modifica il JSON, si rigenera la tabella e si aggiornano le chiavi indicate nel JSON (`keys`).

Cosa fa il glossario:

- **bloccante** (`python scripts/i18n/glossary.py check`, in CI e in `pytest`): le etichette delle funzioni (Monitoraggio, Storico, Corporatura,
  Vicino a me, Promemoria, Eventi, Segnala un evento, Mercatino…) devono essere *esattamente* il termine del glossario in ogni `app_xx.arb`.
- **non bloccante** (`check --soft`, e nell'elenco delle bozze da rivedere): nei testi lunghi, se l'italiano usa "cartella clinica", "referto",
  "veterinario"… e la traduzione non usa né il termine né un'alias ammesso, la riga viene segnalata al revisore.
- **DeepL**: `glossary.py deepl-sync` crea un glossario IT→lingua per ogni lingua e ne passa l'id alle bozze (vedi `AUTOMATIC_TRANSLATION.md`).
  Anche senza glossario DeepL i controlli sopra restano attivi.

<!-- glossary:start -->
| Italiano | English | Español | Deutsch | Français | Note |
|---|---|---|---|---|---|
| Monitoraggio | Monitoring | Seguimiento | Monitoring | Suivi | Pagina di peso, corporatura, curva di crescita e attività del cane. In tedesco resta 'Monitoring' per non confonderlo con 'Verlauf' (= Storico). |
| Storico | History | Historial | Verlauf | Historique | Calendario di tutto ciò che è successo all'animale nella cartella clinica. |
| Corporatura | Body condition | Condición corporal | Körperbau | Corpulence | Scala a 9 punti (BCS). Le guide sono testi nostri parafrasati: nelle altre lingue si traduce il nostro testo italiano, mai il testo originale delle fonti. |
| Vicino a me | Near me | Cerca de mí | In meiner Nähe | Près de chez moi | Servizi per animali, eventi e attività nei dintorni. |
| Promemoria | Reminders | Recordatorios | Erinnerungen | Rappels | Scadenze di vaccini, terapie, visite e cure. La domanda 'Fatto?' è remindersDoneTitle. |
| Fatto? | Done? | ¿Hecho? | Erledigt? | Fait ? | Il francese usa lo spazio insecabile prima del punto interrogativo. |
| Passeggiate | Walks | Paseos | Spaziergänge | Promenades |  |
| Segnala un evento | Suggest an event | Sugerir un evento | Veranstaltung melden | Signaler un événement |  |
| Eventi | Events | Eventos | Veranstaltungen | Événements | Nei filtri dei promemoria (remindersFilterEvents) il tedesco usa 'Termine': sono appuntamenti, non manifestazioni. |
| Mercatino dell'usato | Second-hand marketplace | Mercadillo de segunda mano | Gebrauchtmarkt | Marché de l'occasion | Vincoli legali per paese (es. vendita di animali tra privati): vedi docs/compliance/<lingua>/. |
| Notizie | News | Noticias | News | Actualités |  |
| cartella clinica | medical record | historial clínico | Krankenakte | dossier médical | Concetto legale: è l'oggetto del consenso. Stesso termine nell'app, nei testi del backend e nei consensi. |
| referto | report | informe | Befund | compte rendu |  |
| veterinario | veterinarian | veterinario | Tierarzt | vétérinaire | Tedesco: forma inclusiva 'Tierärztin bzw. Tierarzt' dove il testo è lungo; 'Tierarzt' nelle etichette brevi. en-US 'veterinarian', en-GB/en-AU 'vet' (schede store). |
| vaccino | vaccine | vacuna | Impfung | vaccin |  |
| microchip | microchip | microchip | Mikrochip | puce électronique |  |
| sterilizzato | neutered | esterilizado | kastriert | stérilisé |  |
| Assistente | Assistant | Asistente | Assistent | Assistant | È un'IA e deve essere sempre dichiarato (docs/compliance/01_ai_disclosure.md): mai 'veterinario virtuale' né nomi che lo facciano sembrare una persona. |
<!-- glossary:end -->

Regole per aggiungere un termine: un termine nuovo entra nel glossario quando (a) è il nome di una funzione o di una schermata, (b) ha
un significato legale o clinico (consenso, cartella clinica, referto, triage…), oppure (c) è già stato tradotto in due modi diversi.
Per le funzioni indicare in `keys` le chiavi ARB che sono l'etichetta intera; per i concetti medici bastano gli `aliases`.

## 2. Guida di stile per lingua

| | Italiano | English | Español | Deutsch | Français |
|---|---|---|---|---|---|
| **Catalogo** | `app_it.arb` (sorgente) | `app_en.arb` (UK, US, AU) | `app_es.arb` | `app_de.arb` (DE, AT, CH) | `app_fr.arb` (FR, BE, CH) |
| **Registro** | "tu" | "you", neutro e diretto | "tú" | "Sie" (maiuscolo), mai "du" | "vous", mai "tu" |
| **Genere** | maschile generico per l'animale | "they/their" per la persona | neutro dove possibile ("tu animal") | forma inclusiva nei testi lunghi ("Tierärztin bzw. Tierarzt"), 'Tierarzt' nelle etichette brevi | "le vétérinaire" nelle etichette, accordo con l'animale quando il genere è noto |
| **Tono** | caldo, semplice, mai allarmistico | stesso | stesso, spagnolo internazionale (non solo Spagna) | cortese e chiaro, frasi brevi | cortese, sobrio |
| **Punteggiatura** | — | virgolette dritte | `¿ ?` e `¡ !` | „Anführungszeichen“ nei testi lunghi | spazio insecabile (U+00A0) prima di `? ! : ; »` e dopo `«` |
| **Apostrofo** | `'` normale (ICU) | `'` normale | — | — | `'` normale |
| **Cartella clinica** | cartella clinica | medical record(s) | historial clínico | Krankenakte | dossier médical |
| **Assistente** | "Assistente" (è un'IA, sempre dichiarato) | Assistant | Asistente | Assistent | Assistant |
| **Esempio di telefono** | +39 333 1234567 | secondo il paese scelto | +34 612 345 678 | +49 151 12345678 | +33 6 12 34 56 78 |

Regole comuni a tutte le lingue:

1. **Si traduce il significato, non le parole.** Etichette di UI brevi e naturali; la lunghezza deve restare vicina all'italiano (il tedesco si
   allunga: usare composti compatti, e il test di layout lo verifica, vedi §3).
2. **Mai tradurre**: valori salvati o inviati al backend (specie `Cane`, date salvate), nomi propri (Quokka, OpenStreetMap), nomi dei referti e
   parole scritte dall'utente, elenchi di dati (razze, specie, fonti delle notizie), testi del modello di chat (il backend risponde nella lingua
   richiesta). Elenco completo: `README.md` → "Cosa NON tradurre".
3. **Placeholder, plurali ICU e `\n` identici** all'italiano; le parole chiave `plural`/`other` restano in inglese. Il francese usa `=0`/`=1`/`other`
   dove lo zero conta.
4. **Testi clinici e di sicurezza** (triage, dosaggi, "quando andare dal veterinario", consensi): fedeltà totale al senso, nessuna aggiunta,
   nessuna promessa in più, negazioni intatte. Revisione umana obbligatoria prima del rilascio.
5. **Testi di fonti esterne** (guide della corporatura, curve di crescita): si traduce il nostro testo italiano, che è una parafrasi; non si copia
   né si traduce la formulazione originale delle fonti (WSAVA e simili).
6. **Il sorgente italiano non si "aggiusta" in una traduzione**: se il testo italiano è ambiguo o sbagliato si corregge `app_it.arb` e si riesegue
   il flusso (`NUOVE_FUNZIONI.md`).

### Unità, valute, date

Non si scrivono nelle traduzioni: le decide la **variante** scelta dall'utente (🇬🇧 🇺🇸 🇦🇺 🇩🇪 🇦🇹 🇨🇭 🇫🇷 🇧🇪 🇨🇭 🇪🇸 🇮🇹) in `lib/l10n/regional_defaults.dart`
e `date_formats.dart` (valuta e lato del simbolo, separatori, ordine delle date, metrico/UK/USA, prefisso del telefono, CAP). Nelle ARB si usano i
placeholder e le funzioni di formattazione, mai un simbolo di valuta o un formato di data scritto a mano (c'è un test che fallisce).

### Backend

I testi fissi del backend (`packages/core/domain/localization.py`, `localization_fr.py`, connettori, domande di colloquio, domande di triage,
messaggi di benvenuto della chat) seguono la stessa tabella: tedesco in "Sie", francese in "vous", spagnolo in "tú". I testi legali dei consensi
(`consent/account_consent_text.py`) e il testo del consenso alla cartella clinica (`medical_record/consent_text.py`) hanno un proprio processo:
vedi `TESTI_STORE_E_LEGALI.md`.

## 3. Controlli di layout

`apps/mobile_app/test/language/language_qa_test.dart` apre le schermate principali in ogni lingua a 320×568 con i font reali. La sezione "tedesco con
testo ingrandito" dello stesso file ripete la prova in tedesco (la lingua più lunga) con scala del testo di sistema 1,5× e 2×: un overflow nuovo
fa fallire la CI. Gli overflow già noti sono elencati con il motivo in `_knownOverflows`; quando si corregge il layout si toglie la voce.
