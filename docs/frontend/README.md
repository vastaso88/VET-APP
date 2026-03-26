# Frontend Base Docs — App IA Veterinaria

Questa cartella contiene l'ossatura documentale di partenza per impostare il frontend dell'app in modalità **web-first**, con workflow **MCP-first** e backend **Supabase**.

## Obiettivo
Definire una base semplice, modulare e pronta per:
- progettazione UI in Figma
- implementazione web in Flutter
- integrazione backend con Supabase
- collaborazione con Codex/AI coding assistants

## File inclusi
- `00-project-overview.md`
- `01-repo-structure.md`
- `02-feature-modules.md`
- `03-navigation-and-screens.md`
- `04-design-system.md`
- `05-supabase-integration.md`
- `06-state-management-and-data-flow.md`
- `07-mcp-workflow.md`
- `08-codex-bootstrap-prompt.md`
- `09-mobile-preview-state.md`
- `10-ux-review-2026-03-26.md`

## Principi guida
1. **Web-first**: tutte le decisioni UI e architetturali partono dal browser, con mobile-ready configuration per release successive.
2. **Modularità**: ogni feature è isolata e può evolvere senza rompere il resto dell'app.
3. **Backend as a Service**: Supabase gestisce auth, database, storage e funzioni server-side.
4. **Design-to-code**: Figma definisce il sistema visivo; Flutter implementa componenti e flow reali.
5. **MVP reale**: la prima versione deve far funzionare i flussi chiave, non tutto il prodotto finale.

## MVP frontend: scope iniziale
- onboarding essenziale
- login / registrazione
- home dashboard
- profilo pet
- chat assistente IA
- archivio documenti clinici
- reminder base

## Evoluzione successiva
- multi-pet avanzato
- pagamenti / trial
- supporto multilingua
- network veterinari
- marketplace e servizi B2B

## Stato demo attuale
Per la situazione concreta della preview Flutter web, della route pubblica demo e dei flussi attualmente navigabili, vedi:
- [09-mobile-preview-state.md](/C:/Users/vasta/OneDrive%20-%20Techbau%20SpA/Documenti/PERS/VET%20APP/GIT/docs/frontend/09-mobile-preview-state.md)
- [10-ux-review-2026-03-26.md](/C:/Users/vasta/OneDrive%20-%20Techbau%20SpA/Documenti/PERS/VET%20APP/GIT/docs/frontend/10-ux-review-2026-03-26.md)
