# Disclosure "contenuto generato da IA"

Obbligo di riferimento: AI Act (Regolamento UE 2024/1689), art. 50 — obbligo di trasparenza verso gli utenti che interagiscono con un sistema di IA o ricevono contenuti da esso generati.

## Meccanismo

Il backend espone un campo esplicito `ai_generated: bool` su ogni risposta di chat (`ChatOrchestratorResult` in [packages/core/application/services/chat_orchestrator.py](../../packages/core/application/services/chat_orchestrator.py), propagato da `SendChatMessageOutput` in [packages/core/application/services/send_chat_message.py](../../packages/core/application/services/send_chat_message.py) fino alla risposta JSON di `POST /chat`).

- `ai_generated = True`: la risposta è stata generata da un modello LLM (`mode="general"` o `mode="evidence"` con provider reale).
- `ai_generated = False`: la risposta è templata/rule-based (triage di sicurezza, domande di interview, rifiuto per mancanza di fonti). Non è generata da IA nel senso rilevante per l'AI Act, quindi non porta il badge — scelta esplicita, non una dimenticanza.

Lato mobile, l'atom [`AiDisclosureBadge`](../../apps/mobile_app/lib/design_system/atoms/ai_disclosure_badge.dart) — primo componente "atom" del design system — viene mostrato in `chat_message_bubble.dart` quando il messaggio dell'assistente ha `aiGenerated == true`.

In aggiunta, la schermata di onboarding [`onboarding_privacy_disclaimer_page.dart`](../../apps/mobile_app/lib/features/onboarding/presentation/pages/onboarding_privacy_disclaimer_page.dart) informa l'utente, una volta, che i contenuti generati automaticamente vengono sempre segnalati.

## Estendere ad altre feature (report, immagini)

Oggi l'unica superficie che produce contenuto IA è la chat. Quando verranno costruite feature di generazione report o immagini, devono seguire lo stesso schema:

1. Il backend che genera il contenuto espone un campo `ai_generated` (o equivalente) nella risposta.
2. Il client mostra `AiDisclosureBadge` (o un derivato) vicino al contenuto generato.

Non aggiungere queste feature senza il flag — è il requisito che l'AI Act impone e che questo meccanismo è pensato per non far perdere di vista.
