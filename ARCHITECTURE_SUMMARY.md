# Architecture Summary

This document is a living architecture summary for the project.

It must be updated whenever the architecture evolves, especially when one of these changes:
- project structure
- domain boundaries
- agent responsibilities
- data contracts
- knowledge governance rules
- RAG behavior
- anamnesis protocol design
- vocabulary and ontology structure

## 1. Project Structure

The repository follows a modular monolith design with two delivery surfaces and a layered backend core.

### Top-level layout
- `apps/mobile_app`
  Flutter client used as the main demo and future mobile-ready surface.
- `apps/api`
  FastAPI delivery layer exposing HTTP endpoints for chat, pets, reminders, auth, and conversations.
- `packages/core`
  Domain and application logic.
- `packages/infrastructure`
  Concrete adapters for LLM, retrieval, auth, persistence, logging, telemetry, and protocol storage.
- `packages/shared`
  Shared config, auth context, types, and error definitions.
- `docs`
  Product, architecture, LLM, and runbook documentation.
- `tests`
  Unit, integration, contract, and end-to-end tests.
- `ai_core`
  Core AI domain package for trusted knowledge quality controls and owner education logic.

### Backend layering
- `apps/*`
  UI and transport concerns only.
- `packages/core/domain`
  Business entities and structured case models.
- `packages/core/application`
  Use-case orchestration, ports, and multi-agent turn pipeline.
- `packages/infrastructure`
  Adapters and runtime implementations.
- `packages/shared`
  Cross-cutting primitives and configuration.

## 2. Agent Architecture

The system exposes one assistant externally, but internally it uses a hybrid multi-agent architecture.

The design is hybrid because:
- routing, safety, protocol execution, and state transitions are deterministic
- bounded LLM usage is limited to educational answer generation and language shaping

### Core agents and services
- `Turn Orchestrator`
  Central controller for one synchronous turn. It coordinates all agents and enforces policy.
- `Context Injector`
  Builds the per-turn `ContextEnvelope` from pet data, session case state, observation memory, protocol rules, and communication settings.
- `Observation Interpreter Agent`
  Converts raw user text into a `StructuredObservation` with intent, pathway, concern category, normalized terms, and extracted slots.
- `Risk Supervisor Agent`
  Runs at least twice per turn:
  - early pass to intercept urgent red flags
  - final pass after case state update
- `Anamnesis Agent`
  Applies protocol rules to decide what information is missing and whether to ask a follow-up question or move to guidance.
- `Knowledge Retrieval Agent`
  Builds a normalized retrieval query and fetches an `EvidencePack` from curated sources only.
- `Knowledge Quality Firewall`
  Defensive layer between retrieval and answer generation. It scores evidence, validates species relevance, detects contradictions, filters weak evidence, and can trigger unknown mode.
- `Pet Owner Education Knowledge Layer`
  Converts approved clinical evidence into structured educational blocks, monitoring guidance, prevention tips, and owner-adapted explanations.
- `Educational Response Agent`
  Produces the medically bounded draft answer using only approved evidence and the current case state.
- `Plain-Language Translator Agent`
  Rewrites the approved answer into calm, owner-safe language without changing meaning or safety posture.
- `Response Composer`
  Returns the final `TurnResponse` payload.
- `Memory Curator`
  Persists observation artifacts and session state for longitudinal continuity.

### Guiding rules
- no free-form planner decides the clinical flow
- risk evaluation is continuous
- the system asks only for missing information
- the system must remain non-diagnostic

## 3. Data Flow

### Turn input
- authenticated owner context
- `PET_ID`
- `SESSION_ID`
- user message
- locale

### Turn context assembly
The `ContextEnvelope` is assembled in this order:
1. identity context
2. pet profile context
3. active session case state
4. observation memory summary
5. protocol bundle
6. communication context
7. short conversation window

### Turn execution flow
`API -> SendChatMessageService -> ChatOrchestrator -> agents -> TurnResponse -> persisted Conversation`

Detailed flow:
1. user message is appended to the conversation
2. observation interpreter extracts intent, pathway, slots, and normalized concepts
3. risk supervisor performs early safety check
4. if urgent, the flow short-circuits to triage
5. anamnesis agent updates `SessionCaseState`
6. if information is missing, the assistant asks the next protocol question
7. if enough context exists, retrieval is activated
8. knowledge quality firewall evaluates admissibility of the retrieved evidence
9. if the firewall rejects evidence, unknown mode or safe fallback is triggered
10. if the firewall approves evidence, the education engine builds owner-safe educational blocks
11. risk supervisor performs final assessment
12. educational response agent drafts guidance
13. translator shapes the response for the owner
14. response composer returns structured output
15. memory curator stores observation event, updated case state, and audit log

### Persistent conversational state
Each conversation now carries:
- `locale`
- `messages`
- `session_case_state`
- `observation_events`
- `audit_log`

This makes the conversation a real session container, not only a message list.

## 4. Knowledge Flow

The system separates knowledge into two layers.

### A. Protocol Knowledge
This defines how the anamnesis is conducted.

It includes:
- species-aware pathways
- concern categories
- required slots
- follow-up questions
- red flags
- stop conditions
- minimum evidence tier
- protocol notes and limitations

Current implementation uses an in-memory protocol store, but the target model is versioned external configuration or DSL.

### B. Evidence Knowledge
This defines what the system is allowed to say educationally.

It includes:
- curated sources
- clinical domain tagging
- species relevance
- evidence tier
- snippets used for retrieval and answer grounding
- quality firewall decisions
- contradiction and confidence metadata

### C. Education Knowledge
This transforms approved evidence into owner-facing educational intelligence.

It includes:
- educational blocks
- monitoring guidance
- prevention tips
- curiosity and normal-behavior explanations
- owner knowledge profile adaptation

The orchestrator must never use raw knowledge directly.
It requests:
- a `ProtocolBundle` for conversation control
- an `EvidencePack` for answer grounding

## 5. RAG Design

The RAG design is `evidence-first` and `retrieval-gated`.

### Core rules
- no approved evidence pack, no substantive educational answer
- citations must come only from retrieved sources
- source quality and species relevance affect retrieval eligibility
- the model is used for synthesis, not for inventing unsupported content

### RAG flow
1. normalize user observation into structured case context
2. resolve pathway and evidence intent
3. build retrieval query from:
   - species
   - pathway
   - user message
   - confirmed slots
4. apply domain and minimum-tier constraints
5. retrieve matching sources
6. pass the evidence through the quality firewall
7. if approved, build educational blocks from the surviving evidence
8. build answer prompt from:
   - pet context
   - active case state
   - educational guidance
   - risk level
   - evidence snippets
9. generate bounded educational draft
10. validate and format response

### RAG output characteristics
- concise educational response
- explicit limits
- risk-aware guidance
- source references
- confidence level

## 6. Anamnesis Engine Structure

The anamnesis engine is the protocol-driven part of the architecture.

### Main concepts
- `StructuredObservation`
  The normalized understanding of the latest user turn.
- `SessionCaseState`
  The structured current understanding of the case.
- `ProtocolBundle`
  The resolved rules for the active pathway.
- `TurnDecision`
  The orchestrator decision for the current turn.
- `ObservationEvent`
  The normalized memory artifact created after a turn.

### Case state responsibilities
`SessionCaseState` tracks:
- active pathway
- concern category
- confirmed slots
- missing slots
- readiness for guidance
- last question asked
- last risk level
- protocol version
- evidence status
- turn count

### Pathway examples
Current protocol examples include:
- `general`
- `appetite`
- `gastrointestinal`
- `respiratory`
- `behavior`
- `preventive`

Each pathway defines:
- required information
- the next best follow-up question
- red flag rules
- minimum evidence expectations

### Operating model
- first collect only clinically relevant missing information
- do not ask for known pet profile data again
- escalate immediately if red flags appear
- move to guidance only when the case is sufficiently framed

## 7. Vocabulary Structure

The vocabulary layer is the bridge between owner language and controlled reasoning.

### Current role
The current implementation uses keyword normalization and pathway hints.
This is an initial vocabulary layer, not the final ontology system.

### Target vocabulary architecture
The vocabulary system should evolve into a structured ontology with:
- symptom vocabulary
- behavior vocabulary
- preventive care vocabulary
- species mapping
- synonym mapping
- severity markers
- owner-language to clinical-concept mapping

### Expected vocabulary capabilities
- normalize layperson phrasing into reusable concepts
- detect concern category from wording
- detect red flags from common language
- support species-aware interpretation
- reduce prompt noise by passing structured concepts downstream

### Example concept families
- appetite and feeding
- vomiting and diarrhea
- respiratory effort and cough
- activity and energy
- urination and hydration
- fear, anxiety, aggression, and environmental triggers
- preventive care, vaccine, parasite prevention, and check-up terminology

## 8. Governance And Reliability Direction

This architecture assumes a trustworthy knowledge system with:
- whitelisted sources
- scientific quality filtering
- confidence scoring
- unknown-answer protocol
- hallucination prevention
- a knowledge quality firewall between retrieval and generation
- a dedicated pet owner education layer for non-diagnostic explanation

The knowledge layer must always be able to say:
- what source was used
- why it was eligible
- how confident the system is
- when the system does not know enough

## 9. Evolution Rules

This file must be updated whenever:
- a new agent is introduced or removed
- a protocol bundle or pathway structure changes
- RAG behavior changes
- vocabulary/ontology design changes
- data contracts change
- the knowledge governance model changes
- persistence of session state changes

If implementation and this file diverge, update this file in the same workstream as the architectural change.
