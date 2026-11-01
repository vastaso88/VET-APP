# 06 — Backlog Prioritizzato

## Regole di priorità
- **P0** = indispensabile per validare la v1
- **P1** = importante ma non blocca il test del core loop
- **P2** = utile dopo i primi feedback
- **Icebox** = parcheggiato fuori dal ciclo attuale

## P0 — Must have

### Utente e accesso
- registrazione
- login
- stato sessione

### Profilo pet minimo
- creazione profilo
- modifica profilo
- campi minimi definiti

### Esperienza chat
- avvio nuova conversazione
- risposta contestualizzata sul pet
- salvataggio conversazione
- elenco conversazioni

### Reminder base
- creazione reminder
- lista reminder
- stato reminder

### Esperienza prodotto
- home semplice con accesso rapido a chat, pet e reminder
- microcopy coerente e rassicurante
- feedback base per errori o stato vuoto

## P1 — Should have
- suggerimento di reminder a partire da una conversazione
- tagging o categorie conversazioni
- onboarding ottimizzato
- schermata recap pet
- paywall / trial minimo

## P2 — Could have
- archivio semplice documenti del pet
- note manuali aggiuntive
- preferenze utente
- FAQ / guide contestuali

## Icebox — Esplicitamente congelato
- marketplace veterinario
- prenotazione visite
- assicurazioni
- matching geolocalizzato professionisti
- integrazione con software veterinari
- computer vision
- piani dietetici avanzati
- modulo comportamentale avanzato (**riaperto il 2026-11-01**, vedi `11_riposizionamento_consapevolezza_proprietario.md`: fasi 2 e 3)
- multilingua di espansione
- contenuti social AI come stream operativo principale

## Criteri di ingresso backlog
Ogni item entra nel backlog attivo solo se:
1. supporta direttamente il core loop
2. riduce una frizione evidente
3. aumenta la qualità del test con utenti reali
4. non apre un sottosistema sproporzionato rispetto alla fase

## Criteri di uscita verso Icebox
Un item viene congelato se:
- richiede validazioni che non possediamo ancora
- introduce un nuovo mercato o buyer
- allunga significativamente i tempi di rilascio
- non migliora il completamento del core loop
