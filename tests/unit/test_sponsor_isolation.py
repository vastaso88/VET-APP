import ast
from pathlib import Path

# Every module that participates in the scientific/safety reasoning
# pipeline (spec v3 §34) — commercial/sponsor data must never reach any of
# these, enforced here rather than left as a policy statement, so a future
# accidental import breaks the test suite instead of shipping quietly.
CHAT_PIPELINE_MODULES = (
    "packages/core/application/services/chat_orchestrator.py",
    "packages/core/application/services/safety_gate.py",
    "packages/core/application/services/situation_model_builder.py",
    "packages/core/application/services/interview_planner.py",
    "packages/core/application/services/evidence_quality_engine.py",
    "packages/core/application/services/medical_record_context_retriever.py",
    "packages/core/domain/situation/coverage.py",
    "packages/core/domain/knowledge/quality.py",
    "packages/core/domain/knowledge/answer_validation.py",
    "packages/core/domain/safety/triage_clarification.py",
    "packages/infrastructure/llm/retrieval/europe_pmc_evidence_retriever.py",
    "packages/infrastructure/llm/retrieval/in_memory_evidence_retriever.py",
    "packages/infrastructure/llm/retrieval/supabase_evidence_retriever.py",
)

BANNED_SUBSTRINGS = ("sponsor", "advertis", "commercial_banner")

REPO_ROOT = Path(__file__).resolve().parents[2]


def _imported_module_names(source: str) -> list[str]:
    tree = ast.parse(source)
    names: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            names.extend(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            names.append(node.module)
    return names


def test_chat_pipeline_modules_never_import_sponsor_or_advertising_code() -> None:
    violations = []
    for relative_path in CHAT_PIPELINE_MODULES:
        path = REPO_ROOT / relative_path
        assert path.exists(), f"expected pipeline module not found: {relative_path}"
        for imported in _imported_module_names(path.read_text(encoding="utf-8")):
            lowered = imported.lower()
            if any(banned in lowered for banned in BANNED_SUBSTRINGS):
                violations.append(f"{relative_path} imports {imported}")

    assert not violations, (
        "Sponsor/advertising isolation violated (spec v3 §34): " + "; ".join(violations)
    )
