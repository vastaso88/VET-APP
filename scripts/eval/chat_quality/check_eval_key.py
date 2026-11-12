"""Says whether the evaluation key is in place — never what it is.

    uv run python scripts/eval/chat_quality/check_eval_key.py

Prints one of: "chiave trovata", "chiave NON trovata", or a warning when it
is the same as the production key (the evaluation must never spend the
production quota). Nothing else: no value, no prefix, no length.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
for path in (str(ROOT_DIR), str(HERE)):
    if path not in sys.path:
        sys.path.insert(0, path)

from run import _env_value  # noqa: E402


def main() -> int:
    eval_key = _env_value("EVAL_LLM_API_KEY")
    if not eval_key:
        print("chiave NON trovata: manca EVAL_LLM_API_KEY nel file .env (o nell'ambiente).")
        return 1
    if eval_key == _env_value("LLM_API_KEY") and not _env_value("EVAL_LLM_BASE_URL"):
        print(
            "ATTENZIONE: EVAL_LLM_API_KEY e' uguale a LLM_API_KEY (la chiave di produzione). "
            "Serve la chiave del secondo account."
        )
        return 2
    if not eval_key.startswith("gsk_"):
        print("chiave trovata, ma non sembra una chiave Groq (non inizia con gsk_): ricontrolla.")
        return 3
    print("chiave trovata.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
