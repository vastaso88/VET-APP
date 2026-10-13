# Traduzioni incrementali assistite

L'italiano resta la sorgente. `source_manifest.json` registra l'impronta dei testi
e dei metadati dei placeholder Flutter, delle risposte in `_MESSAGES` nel backend
e delle stringhe Android. La CI segnala traduzioni obsolete anche quando la
chiave esiste gia in EN/ES: un fix senza cambi di testo non richiede traduzioni.
L'impronta iniziale registra i cataloghi esistenti, senza ritradurli.

## Attivazione

Aggiungere il secret repository `DEEPL_API_KEY` usando una chiave DeepL API gia
autorizzata. Le chiavi API Free terminanti in `:fx` usano `api-free.deepl.com`;
le altre usano `api.deepl.com`. Non inserire la chiave nel codice o nell'APK.
Facoltativamente configurare le variables `DEEPL_GLOSSARY_EN` e
`DEEPL_GLOSSARY_ES` con gli ID di glossari IT→EN e IT→ES.
Non occorrono installazioni o permessi amministrativi sul PC.

Il workflow `Translation drafts IT to EN ES` parte sui push in `main` o
`MULTILANG` che modificano le sorgenti configurate. Non parte su pull request di
fork e ha solo permessi di lettura GitHub. L'avvio manuale richiede che il workflow
esista sulla branch predefinita, come gli altri workflow manuali.

Se ci sono testi da aggiornare, invia a DeepL solo stringhe del repository:
mai conversazioni, dati utente o documenti caricati. L'API puo avere costi: limite
predefinito di 100 messaggi per esecuzione (ogni lingua conta separatamente),
timeout e nessun retry automatico per evitare spese incontrollate. Se manca la
chiave o la quota e esaurita, il workflow fallisce esplicitamente: non dichiara
traduzioni aggiornate.

## Revisione e integrazione

1. Scaricare l'artifact `translation-drafts-COMMIT` dall'esecuzione GitHub.
2. Leggere `TRANSLATION_REVIEW.txt`: tutte le traduzioni sono bozze.
3. Integrare e revisionare i file rispettando i percorsi dell'artifact. Usare
   la stessa revisione sorgente indicata dal commit; se nel frattempo cambia il
   repository, rigenerare le bozze invece di sovrascrivere file piu recenti.
4. Revisionare con particolare cura negazioni, messaggi clinici, triage e testi
   legali. Le traduzioni modificate manualmente dopo l'ultima impronta vengono
   preservate e segnalate, non sovrascritte automaticamente.
5. Dopo la revisione eseguire dalla root:

```powershell
python scripts/i18n/check_i18n.py
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
o testi esterni ai tre cataloghi configurati. Per nuovi domini va aggiunto un
adattatore esplicito: non si traduce arbitrariamente tutto il codice.

Per generare bozze localmente usare `python scripts/i18n/auto_translate.py draft
--output PERCORSO_SEPARATO`. Il repository sorgente non viene sovrascritto.

[Documentazione API DeepL](https://developers.deepl.com/api-reference/translate/request-translation)
