"""Which Groq models the app may use (docs/compliance/19, 2026-11-16).

Groq's data agreement does not cover its preview models (§3.6), and with a
legal doubt a model is not used (Orchestrator decision, 2026-11-16). So the
rule is an allow-list: only the models Groq lists as PRODUCTION may appear in
a chat chain, as the light model or as the vision model; any other Groq model
is dropped at start-up, and a vision model outside the list switches photo
reading off. Check console.groq.com/docs/models before adding a name, and
record the check in docs/compliance/19.
"""

from __future__ import annotations

GROQ_PRODUCTION_MODELS: frozenset[str] = frozenset(
    {
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b",
        "llama-3.3-70b-versatile",
        "llama-3.1-8b-instant",
        "whisper-large-v3",
        "whisper-large-v3-turbo",
    }
)

# Known preview models, named so a test can say why they are refused.
GROQ_PREVIEW_MODELS: frozenset[str] = frozenset({"qwen/qwen3.8-27b"})


def is_groq_production_model(model: str) -> bool:
    return model.strip() in GROQ_PRODUCTION_MODELS


def production_models_only(chain: str) -> tuple[str, list[str]]:
    """The comma-separated [chain] without any model outside the production
    list, and the names it dropped."""
    names = [name.strip() for name in chain.split(",") if name.strip()]
    kept = [name for name in names if is_groq_production_model(name)]
    dropped = [name for name in names if not is_groq_production_model(name)]
    return ",".join(kept), dropped
