# Permessi del dispositivo (OS)

Verificato (2026-09-17): VetApp non richiede oggi alcun permesso OS reale — nessuna dipendenza `permission_handler`/fotocamera/notifiche in `pubspec.yaml`, le icone "notifiche" in Reminders sono decorative, `file_picker` non richiede permessi runtime sullo storage scoped moderno. Costruire ora una sezione Impostazioni con una lista di permessi per permessi che non esistono sarebbe speculativo — non è stata costruita (vedi [04_termini_e_consensi.md](04_termini_e_consensi.md)).

Questa pagina resta come guida per chi implementerà il primo permesso OS reale (es. fotocamera per allegare foto ai documenti clinici, notifiche locali per i promemoria).

## Due principi, imposti dalle policy Apple/Play Store (non dal GDPR)

1. **Richiesta just-in-time**: chiedi il permesso nel momento in cui l'utente prova a usare la funzione che lo richiede, mai in una schermata iniziale generica prima che serva davvero.
2. **Graceful degradation**: se l'utente nega, disabilita solo quella funzione specifica. L'app deve restare pienamente utilizzabile per tutto il resto. Bloccare l'intero accesso all'app per un permesso OS negato non supera la review di Apple/Google, oltre a essere una pessima esperienza.

## Nota

L'evento di consenso autorevole per un permesso OS è il dialog nativo del sistema operativo, non un testo scritto dall'app — l'app può solo spiegare *prima* del dialog perché sta per chiederlo (rationale), non registrare essa stessa il consenso come fa per i consensi GDPR in [04_termini_e_consensi.md](04_termini_e_consensi.md).
