# Traduzioni incrementali assistite

L'italiano resta la sorgente. `source_manifest.json` registra l'impronta dei testi
e dei metadati dei placeholder Flutter, delle risposte in `_MESSAGES` nel backend
e delle stringhe Android, per le lingue `en`, `es`, `de`, `fr`. La CI segnala traduzioni
obsolete anche quando la chiave esiste già nelle altre lingue: un fix senza cambi di testo
non richiede traduzioni. La procedura completa per chi aggiunge una funzione è in
[NUOVE_FUNZIONI.md](NUOVE_FUNZIONI.md); termini e registro in
[GLOSSARIO_E_STILE.md](GLOSSARIO_E_STILE.md).

## Cosa fa il sistema (e cosa no)

| Pezzo | Dove | Esito |
|---|---|---|
| Chiavi mancanti, segnaposto diversi, testi italiani nel codice | `scripts/i18n/check_i18n.py` (CI job `flutter`, `make i18n-check`, `pytest`) | **blocca** |
| Traduzione obsoleta rispetto al sorgente (UI, backend `_MESSAGES`, Android) | `scripts/i18n/auto_translate.py check` (CI job `flutter`) | **blocca** |
| Nomi delle funzioni diversi dal glossario | `scripts/i18n/glossary.py check` (CI job `flutter`, `pytest`) | **blocca** |
| Termini del glossario mancanti nei testi lunghi | `glossary.py check --soft`, `TRANSLATION_REVIEW.md` | suggerimento al revisore |
| Ogni catalogo del backend ha tutte le lingue | `tests/unit/test_translation_system.py` | **blocca** (lacune note elencate nel test) |
| Overflow in tedesco, a 320×568 e con testo ingrandito | `apps/mobile_app/test/language/language_qa_test.dart` | **blocca** |
| Bozze per le chiavi nuove o modificate | workflow `Translation drafts from Italian` | artifact da rivedere, mai pubblicato |
| Registro (es "tú", de "Sie", fr "vous") | `DEEPL_FORMALITY` in `auto_translate.py` | automatico nelle bozze |

## Attivazione

Il proprietario deve aggiungere **una sola cosa**: il secret repository `DEEPL_API_KEY`
(GitHub → Settings → Secrets and variables → Actions), con una chiave DeepL API già
autorizzata. Le chiavi API Free terminanti in `:fx` usano `api-free.deepl.com`; le altre
`api.deepl.com`. Non inserire la chiave nel codice o nell'APK. Non occorrono installazioni
o permessi amministrativi sul PC.

I glossari DeepL non si configurano a mano: a ogni esecuzione il workflow li ricrea da
`docs/i18n/glossary.json` (`glossary.py deepl-sync`) e passa gli id alle bozze. Il piano
Free di DeepL consente pochissimi glossari: se li rifiuta, le bozze escono comunque
senza glossario e `TRANSLATION_REVIEW.md` segnala i termini da correggere. Le vecchie
variables `DEEPL_GLOSSARY_EN` / `DEEPL_GLOSSARY_ES` non servono più (se impostate, vengono
sostituite dagli id creati).

Il workflow `Translation drafts from Italian` parte sui push in `main` o `MULTILANG` che
modificano le sorgenti configurate (ARB italiano, `localization.py`, `strings.xml`,
glossario, script). Non parte su pull request di fork e ha solo permessi di lettura GitHub.
L'avvio manuale richiede che il workflow esista sulla branch predefinita, come gli altri
workflow manuali.

Se ci sono testi da aggiornare, invia a DeepL solo stringhe del repository: mai
conversazioni, dati utente o documenti caricati. L'API può avere costi: limite
predefinito di 100 messaggi per esecuzione (ogni lingua conta separatamente),
timeout e nessun retry automatico per evitare spese incontrollate. Se manca la
chiave o la quota è esaurita, il workflow fallisce esplicitamente: non dichiara
traduzioni aggiornate.

## Revisione e integrazione

1. Scaricare l'artifact `translation-drafts-COMMIT` dall'esecuzione GitHub (l'elenco compare
   anche nel riepilogo dell'esecuzione).
2. Aprire `TRANSLATION_REVIEW.md`: **tutte le righe sono bozze da rivedere**, con testo
   italiano, bozza e avvisi di glossario; `TRANSLATION_REVIEW.json` ha gli stessi dati per
   gli strumenti, `TRANSLATION_REVIEW.txt` la lista semplice.
3. Integrare e revisionare i file rispettando i percorsi dell'artifact. Usare
   la stessa revisione sorgente indicata dal commit; se nel frattempo cambia il
   repository, rigenerare le bozze invece di sovrascrivere file più recenti.
4. Revisionare con particolare cura negazioni, messaggi clinici, triage e testi
   legali. Le traduzioni modificate manualmente dopo l'ultima impronta vengono
   preservate e segnalate (`MANUAL REVIEW`), non sovrascritte automaticamente.
5. Dopo la revisione eseguire dalla root:

```powershell
python scripts/i18n/check_i18n.py
python scripts/i18n/glossary.py check --soft
python scripts/i18n/auto_translate.py acknowledge
python scripts/i18n/auto_translate.py check
```

6. Nella cartella `apps/mobile_app` rigenerare il codice Flutter con
   `flutter gen-l10n`, eseguire analisi e test. Poi committare cataloghi,
   codice generato e manifest revisionati sulla branch di lavoro.

`acknowledge` attesta che tutti i testi correnti sono stati revisionati: non va
eseguito solo per far passare un controllo senza aggiornare le traduzioni.
L'artifact contiene un manifest candidato, da integrare solo insieme ai testi
revisionati. Il workflow non committa, non apre PR, non effettua merge e non
distribuisce l'app: nessuna traduzione automatica viene pubblicata da sola.

## Garanzie e limiti

Placeholder, strutture ICU/plurali, formati Android e separatori backend sono
protetti con tag XML ignorati dal traduttore; modifiche alla struttura vengono
rifiutate. Rimane necessaria la verifica del significato e del layout.
Non vengono modificati codici clinici, classificatori, prompt, contenuti utente
o testi esterni ai tre cataloghi configurati (ARB, `_MESSAGES`, `strings.xml`). Per nuovi
domini va aggiunto un adattatore esplicito: non si traduce arbitrariamente tutto il codice.
I dizionari del backend fuori da `_MESSAGES` (connettori, domande di colloquio, domande
di triage, messaggi di benvenuto, consensi) non passano da DeepL: li copre il test di
copertura delle lingue, la traduzione è a mano e va rivista.

Per generare bozze localmente usare `python scripts/i18n/auto_translate.py draft
--output PERCORSO_SEPARATO`. Il repository sorgente non viene sovrascritto.

[Documentazione API DeepL](https://developers.deepl.com/api-reference/translate/request-translation)
