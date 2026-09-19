# Brainstorm impostazioni

Idee raccolte progressivamente per la pagina "Impostazioni". Non ancora prioritizzate né validate: servono come materiale grezzo da cui, in futuro, estrarre feature concrete.

## Località: filtro geografico per news ed eventi (2026-09-16)

Prima funzione da implementare nella pagina Impostazioni: la Località. Da qui l'utente sceglierà l'ambito delle news da visualizzare (locali, regionali, nazionali), ma soprattutto la Località servirà per cercare gli eventi nella zona.

- **Inserimento posizione**: manuale (digitata dall'utente) oppure automatica via geolocalizzazione del dispositivo.
- **Posizione attuale vs residenza abituale**: se l'utente cambia zona temporaneamente (es. per turismo), deve poter scegliere se vuole news ed eventi della posizione in cui si trova in quel momento oppure del suo luogo di residenza abituale. Nome provvisorio dell'opzione: "vuoi essere seguito?" — da migliorare. Alternative da validare in futuro: "Segui la mia posizione", "Modalità viaggio", "Aggiorna automaticamente in base a dove mi trovo".

Contesto tecnico attuale (per il futuro sviluppo): la pagina Impostazioni esiste già in [settings_page.dart](../../apps/mobile_app/lib/features/settings/presentation/pages/settings_page.dart) ma non ha ancora nessun campo di località; [local_events_page.dart](../../apps/mobile_app/lib/features/local_events/presentation/pages/local_events_page.dart) ha già un placeholder che richiede la posizione ma senza logica reale; [pet_news_repository.dart](../../apps/mobile_app/lib/features/pet_news/data/pet_news_repository.dart) oggi filtra le news solo per specie animale con scope nazionale fisso (`hl=it&gl=IT`), nessun filtro locale/regionale. Nessun package di geolocalizzazione è ancora presente nel progetto.

Punti aperti da definire in futuro: nome definitivo del toggle "posizione attuale vs residenza"; quale package di geolocalizzazione adottare; dove salvare la posizione (solo locale sul device, o anche lato backend legata all'utente); fonte dati per gli eventi e per le news regionali/locali.

---

Altre idee sulla pagina Impostazioni verranno aggiunte in questo file mano a mano.

**Promemoria**: quando il materiale in questo file sarà sufficiente, l'utente chiederà un riassunto delle potenziali feature da validare e pianificare, sintetizzando le idee raccolte qui.
