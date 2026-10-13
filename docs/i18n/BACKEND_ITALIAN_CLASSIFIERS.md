# Classificatori backend — stato MULTILANG

Aggiornato sulla build 30: la precedente lista di lavoro italiano è stata
integrata in MULTILANG. Il dettaglio dell'architettura e della verifica è in
[MULTILANG_IMPLEMENTATION.md](MULTILANG_IMPLEMENTATION.md).

## Implementato in IT / EN / ES

- Messaggi deterministici centralizzati: triage, chiarimenti, consenso cartella,
  disponibilità dei documenti, errori provider, evidenze insufficienti,
  limitazioni e azioni, suggerimento peso e riepilogo veterinario.
- Istruzioni linguistiche per risposta naturale, sintesi delle evidenze e
  domande di colloquio; la lingua della richiesta non è stato globale condiviso.
- Intent, saluti, richieste di dosaggio, riconoscimento di specie nei messaggi,
  segnali urgenti generali e specifici per specie, risposte ai consensi e
  richieste di spiegazione dei referti ampliati alle tre lingue.
- Collegamento lessicale ES → termini delle fonti EN nel filtro di rilevanza;
  verifiche contro affermazioni assolute in tutte e tre le lingue.
- Cataloghi legali IT/EN/ES e header Accept-Language per i consensi account.
- Test della matrice 3 × 3 di lingua del messaggio e lingua della risposta urgente.

## Confini da mantenere

Le liste lessicali sono una rete prudenziale, non un riconoscimento esaustivo di
qualsiasi formulazione clinica. Una nuova formulazione o un nuovo rischio
richiede test di regressione nelle tre lingue e verifica delle false positività.
Non abbassare il livello clinico perché una traduzione contiene parole rassicuranti:
i segnali di peggioramento continuano a prevalere.

I nomi dei referti e le parole scritte dal proprietario non si traducono.
I titoli delle conversazioni derivati dal primo messaggio rimangono quel
contenuto originale. Le date salvate, i codici di specie e gli stati clinici non
cambiano; si traducono le etichette visibili.

La protezione PII esistente include regole specifiche per indirizzi e identificativi
italiani e il supporto opzionale Presidio. Questa integrazione non dichiara un nuovo
riconoscimento completo di indirizzi/identificativi di ogni paese; l'internazionalizzazione
di tali regole necessita una verifica privacy dedicata.
