# 03 — Scope MVP v1

## Obiettivo della v1
Validare il primo loop di valore consumer con una versione semplice, usabile e focalizzata.

## Core loop da validare
1. L'utente crea il proprio account.
2. Inserisce il profilo minimo del pet.
3. Fa una domanda rilevante.
4. Riceve una risposta percepita come utile e chiara.
5. Salva o ritrova il contesto.
6. Imposta o riceve un reminder.
7. Torna sull'app.

## Funzioni che entrano in v1

### A. Accesso e identità utente
- registrazione
- login
- recupero accesso di base

### B. Profilo minimo del pet
- nome
- specie
- età o fascia d'età
- peso indicativo
- condizioni / note essenziali
- stile di vita essenziale

### C. Chat orientativa
- campo domanda libero
- risposta testuale
- contesto basato sul profilo pet
- tono chiaro e non allarmistico
- eventuale invito ad approfondire / rivolgersi a un professionista nei casi sensibili

### D. Storico conversazioni
- elenco conversazioni precedenti
- ripresa del contesto
- ricerca semplice o filtro base se necessario

### E. Reminder base
- vaccinazioni / controlli / routine
- scadenza con titolo, data, nota
- visualizzazione dei reminder attivi

## Funzioni che NON entrano in v1
- network veterinario
- prenotazioni
- marketplace di specialisti
- matching con assicurazioni
- upload e interpretazione avanzata di PDF clinici
- piani dietetici complessi e personalizzazione profonda
- modulo comportamentale esteso (**riaperto il 2026-11-01**: il comportamento e la relazione sono il centro del prodotto, vedi `11_…`)
- computer vision
- app mobile nativa
- multilingua reale di lancio
- piano enterprise / B2B

## Funzioni in osservazione per v1.1
- upload manuale di referti come archivio semplice
- tagging conversazioni
- reminder suggeriti dal contesto
- trial e paywall minimo

## Requisiti di qualità della v1
- usabilità rapida
- onboarding non dispersivo
- percezione di affidabilità
- continuità tra chat, profilo e reminder
- zero frizioni superflue

## Definizione di “done” di v1
La v1 è considerata pronta quando un utente reale può completare l'intero core loop senza assistenza manuale del team.
