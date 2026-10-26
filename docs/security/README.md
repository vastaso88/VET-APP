# Cybersicurezza e protezione dati

Sezione permanente del progetto. Proprietario: la sessione "Cybersicurezza e
protezione dati"; ogni altra sessione la consulta prima di toccare dati
personali e la aggiorna quando cambia qualcosa (vedi `05_checklist.md`).

| File | Cosa contiene | Quando usarlo |
| --- | --- | --- |
| [`01_quadro_normativo.md`](01_quadro_normativo.md) | Quali leggi e standard si applicano (GDPR, Codice privacy, NIS2, Cyber Resilience Act, AI Act, ePrivacy, UK/CH/AU/USA, Google Play, OWASP), con fonti e date; cosa far confermare a un legale | prima del lancio in un paese nuovo, a ogni funzione nuova |
| [`02_audit.md`](02_audit.md) | Audit tecnico del 2026-10-26: rilievi per gravità, cosa è stato corretto, cosa resta | per capire lo stato di sicurezza e le priorità |
| [`audit/`](audit/) | Report dettagliati per area (backend, app, LLM, repo/CI/admin) con file e riga | quando si corregge un rilievo |
| [`03_procedura_violazioni.md`](03_procedura_violazioni.md) | Cosa fare in caso di violazione di dati: chi fa cosa entro 72 ore, modulo del registro | **subito**, appena si sospetta un incidente |
| [`04_registro_rischi.md`](04_registro_rischi.md) | I rischi noti con probabilità, impatto, misure e proprietario | ogni 3 mesi e a ogni funzione nuova |
| [`05_checklist.md`](05_checklist.md) | Checklist "prima di ogni rilascio", "funzione nuova con dati personali", "ogni 3 mesi" | a ogni rilascio e PR |
| [`06_inventario_dati_fornitori.md`](06_inventario_dati_fornitori.md) | Quali dati trattiamo, dove, per quanto; i fornitori con paese e base del trasferimento; bozza Data safety | registro trattamenti, informativa, Google Play |
| [`07_proposta_claude_md.md`](07_proposta_claude_md.md) | Regole di sicurezza da incollare nel `CLAUDE.md` del progetto | per l'Orchestratore |
| [`08_report_orchestratore_2026_10_26.md`](08_report_orchestratore_2026_10_26.md) | Sintesi per il proprietario: 5 rischi principali, correzioni, SQL da eseguire, azioni, punti per il legale | lettura di partenza |
| [`/SECURITY.md`](../../SECURITY.md) | Politica pubblica di segnalazione delle vulnerabilità (richiesta anche dal Cyber Resilience Act) | va attivata la "Private vulnerability reporting" su GitHub |

Strumenti:
- `scripts/security/check_anon_exposure.py`: controllo passivo di esposizione del
  database con la sola chiave publishable (da lanciare a ogni rilascio).
- `scripts/setup/security_*.sql`: hardening idempotente del progetto Supabase
  (eseguito dal proprietario nel SQL Editor, in ordine di data).
- `tests/unit/test_security_*.py`, `tests/integration/test_security_api.py`:
  test di non regressione delle correzioni.

Attivazioni una tantum su GitHub (proprietario): Settings → Code security →
**Private vulnerability reporting** (per `SECURITY.md`), **Secret scanning** e
**Push protection**, **Dependabot alerts** (il file `.github/dependabot.yml`
c'è già), branch protection su `main`.
