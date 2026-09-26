"""Generic approximate string matching (edit distance) — used where a
fixed keyword substring match is too brittle against real typos.
Real-world finding: "posso dare la tachipirna al mio gatto?" (missing one
letter) matched nothing in SafetyGate or EvidenceQueryPlanner, silently
losing a genuine poisoning-risk signal over a single typo.

Deliberately conservative, not a general spell-checker:
- Only single-word keywords are fuzzy-matched; a keyword containing a
  space keeps exact substring matching only (edit distance between whole
  phrases isn't well-defined the same way, and phrases are already lower
  false-positive risk).
- Short keywords are excluded entirely (see MIN_FUZZY_KEYWORD_LENGTH) — a
  1-letter typo tolerance on a 3-4 letter word would match too many
  unrelated words, reintroducing exactly the kind of common-word collision
  this app has repeatedly had to guard against (see safety_gate.py's
  "moment"/"momento" and "sole diretto"/"consolare" notes). Callers should
  additionally avoid passing word STEMS (e.g. "aliment", deliberately
  shorter than "alimentazione" to match several inflections by substring)
  into fuzzy matching — a stem isn't a real word, so its "typo distance"
  to unrelated real words is not a meaningful signal the way a complete
  word's is.
- The allowed edit distance scales with keyword length, never a fixed
  constant: one typo in a 6-letter word is a much bigger relative change
  than one typo in a 12-letter word.
"""

import re
from collections.abc import Iterable

MIN_FUZZY_KEYWORD_LENGTH = 6

_WORD_PATTERN = re.compile(r"[^\W\d_]+", re.UNICODE)


def _levenshtein_distance(a: str, b: str) -> int:
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    previous_row = list(range(len(b) + 1))
    for i, char_a in enumerate(a, start=1):
        current_row = [i]
        for j, char_b in enumerate(b, start=1):
            insert_cost = current_row[j - 1] + 1
            delete_cost = previous_row[j] + 1
            substitute_cost = previous_row[j - 1] + (char_a != char_b)
            current_row.append(min(insert_cost, delete_cost, substitute_cost))
        previous_row = current_row
    return previous_row[-1]


def _max_edit_distance(keyword_length: int) -> int:
    if keyword_length < MIN_FUZZY_KEYWORD_LENGTH:
        return 0
    if keyword_length <= 9:
        return 1
    return 2


def contains_keyword(message: str, keyword: str) -> bool:
    """True if `keyword` appears as a prefix of some word in `message`
    (a phrase keyword, containing a space, falls back to plain substring
    matching, since it inherently spans multiple tokens rather than being
    one word).

    Real-world finding: "aglio" (garlic) as a raw substring-anywhere match
    also matched "per sbaglio" ("by mistake") — an extremely common,
    unrelated phrase, and one especially likely to appear in exactly the
    accidental-poisoning reports this keyword exists to catch. Anchoring
    to the START of a word rather than matching anywhere fixes this
    generically: every deliberate word stem in this app's keyword lists
    (e.g. "cioccolat" for cioccolato/cioccolata, "aggress" for
    aggressivo/aggressione) was written to be a PREFIX of its target
    word, so anchoring to word-start preserves all of them while
    rejecting a keyword that only happens to appear buried mid-word.
    """
    lowered = message.lower()
    if " " in keyword:
        return keyword in lowered
    return any(word.startswith(keyword) for word in _WORD_PATTERN.findall(lowered))


def find_fuzzy_keyword_matches(message: str, keywords: Iterable[str]) -> set[str]:
    """Returns the subset of `keywords` that either match `message` via
    `contains_keyword`, or are a close typo of one of its words.
    Case-insensitive; `message` may be passed already-lowercased. A
    multi-word keyword is only ever matched exactly (see module docstring).
    """
    words = _WORD_PATTERN.findall(message.lower())
    matched: set[str] = set()
    for keyword in keywords:
        if contains_keyword(message, keyword):
            matched.add(keyword)
            continue
        if " " in keyword:
            continue
        threshold = _max_edit_distance(len(keyword))
        if threshold == 0:
            continue
        for word in words:
            if abs(len(word) - len(keyword)) > threshold:
                continue
            if _levenshtein_distance(word, keyword) <= threshold:
                matched.add(keyword)
                break
    return matched
