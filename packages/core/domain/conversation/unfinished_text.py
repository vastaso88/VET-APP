"""A text the model left unfinished is never shown as it is (collaudo, wave 0, 23/11/2026).

Five answers of seventeen ended in the middle of a word: the model's reasoning had spent the
token budget and the provider reported `finish_reason: length`, which nobody looked at. This
module closes such a text at its last finished sentence. Deterministic, any provider, any
language of the chat; used only when the provider says the text was cut.
"""

from __future__ import annotations

import re

# The end of a sentence: . ! ? or an ellipsis, with any closing quote or bracket after it,
# followed by a space or the end of the line. "2.5", "1.000" and "www.x" have no space after.
_SENTENCE_END = re.compile(r"[.!?…]+[\"'”»)\]*_]*(?=\s|$)")
# A dot that does not end a sentence: a list number ("3."), or a common abbreviation in the
# five languages of the chat. Read on the text up to and including the dot.
_NOT_AN_END = re.compile(
    r"(?:^|\s)(?:[-*•]\s*)?\d{1,2}\.$"
    r"|(?<!\w)(?i:es|ecc|ca|circa|max|min|dott|dr|prof|sig|pag|fig|n|nr|art|vs|etc|e\.g|i\.e|"
    r"approx|mr|mrs|ms|st|p\.\s?ej|ej|aprox|sr|sra|z\.\s?b|d\.\s?h|bzw|usw|evtl|ggf|"
    r"p\.\s?ex|env|cf|mme)\.$"
    # one lower-case letter ("z." of "z. B."); a capital one may end a sentence ("vitamina C.")
    r"|(?<!\w)[a-zäöü]\.$"
)
# A line that only opens what was cut: "Nel frattempo:", a heading, a lone list marker.
_OPENS_SOMETHING = re.compile(r":[\"'”»)*_]*$|^\s*(?:[-*•]|\d{1,2}[.)])\s*$|^\s*#{1,6}\s")


def _finished_part(line: str) -> str:
    """`line` up to its last finished sentence ("" when it has none)."""
    end = 0
    for match in _SENTENCE_END.finditer(line):
        if not _NOT_AN_END.search(line[: match.end()]):
            end = match.end()
    return line[:end].rstrip()


def close_at_last_sentence(text: str) -> str:
    """The text up to its last finished sentence, without the list item, the heading or the
    "in the meantime:" left hanging by the cut. "" when no sentence is finished."""
    lines = text.rstrip().split("\n")
    if not lines:
        return ""
    lines[-1] = _finished_part(lines[-1])
    return _without_hanging_lines(lines)


def close_at_last_line(text: str) -> str:
    """For a text made of lines (a list of values, the sections of a summary): the cut line
    goes whole, because half of a value ("ALT 1") is a wrong value."""
    lines = text.rstrip().split("\n")
    if len(lines) == 1:
        return close_at_last_sentence(text)
    if _finished_part(lines[-1]) != lines[-1].rstrip():
        lines.pop()
    return _without_hanging_lines(lines)


def _without_hanging_lines(lines: list[str]) -> str:
    while lines and (not lines[-1].strip() or _OPENS_SOMETHING.search(lines[-1].rstrip())):
        lines.pop()
    return "\n".join(lines).rstrip()
