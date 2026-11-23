"""Telling real speech from what the recogniser invents out of silence (collaudo: a dictation
of silence came back as "Thank you.").

Whisper models are trained on subtitled videos and, given an audio without speech, often write
what closes them ("Thank you.", "Thanks for watching", the subtitle credit of a community).
Two kinds of evidence, in this order:

1. what the provider itself says about each segment (`verbose_json`): `no_speech_prob` high AND
   `avg_logprob` low is Whisper's own "there is no speech here"; a very high `compression_ratio`
   is a repetition loop;
2. only for a very short clip, a closed list of the typical invented phrases in the five
   languages of the app. A real dictation of "grazie" lasting a second is the price of this
   rule, and it is paid on purpose: the field stays empty, the user says it again or types it.

Pure functions, no I/O: the provider feeds them its answer, the tests feed them canned ones."""

import re
import unicodedata
from typing import Any

# Whisper's own thresholds (openai/whisper transcribe.py): a segment with no_speech_prob above
# 0.6 whose average log-probability is below -1.0 is silence; compression above 2.4 is a loop.
NO_SPEECH_PROB_LIMIT = 0.6
AVG_LOGPROB_LIMIT = -1.0
COMPRESSION_RATIO_LIMIT = 2.4

# Below this, the provider's doubt about speech is already worth listening to when the text
# is one of the typical invented phrases (not enough alone to drop a segment).
DOUBTFUL_NO_SPEECH_PROB = 0.3

# A clip this short (seconds, or bytes when the provider gives no duration) is where the
# invented phrases appear; a longer one that really says "thank you" is speech.
SHORT_CLIP_SECONDS = 3.0
SHORT_CLIP_BYTES = 48_000

# Normalised (lower case, no accents or punctuation). Whole-text match, not "contains".
INVENTED_PHRASES = frozenset(
    {
        # English
        "thank you",
        "thanks",
        "thank you very much",
        "thank you for watching",
        "thanks for watching",
        "thanks for watching and see you next time",
        "please subscribe",
        "bye",
        "bye bye",
        "you",
        # Italian
        "grazie",
        "grazie a tutti",
        "grazie mille",
        "grazie per la visione",
        "grazie per aver guardato il video",
        "sottotitoli creati dalla comunita di amara org",
        "sottotitoli e revisione a cura di qtss",
        "ciao",
        "a presto",
        # Spanish
        "gracias",
        "muchas gracias",
        "gracias por ver el video",
        "gracias por ver",
        "subtitulos realizados por la comunidad de amara org",
        "hasta luego",
        # German
        "danke",
        "vielen dank",
        "danke furs zuschauen",
        "vielen dank fur ihre aufmerksamkeit",
        "untertitel der amara org community",
        "untertitel im auftrag des zdf fur funk 2017",
        "tschuss",
        # French
        "merci",
        "merci beaucoup",
        "merci d avoir regarde cette video",
        "merci d avoir regarde",
        "sous titres realises par la communaute d amara org",
        "sous titrage st 501",
        "au revoir",
    }
)


def _normalise(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text.lower())
    without_marks = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9]+", " ", without_marks)).strip()


def _number(value: object) -> float | None:
    return float(value) if isinstance(value, int | float) and not isinstance(value, bool) else None


def _is_silence_segment(segment: dict[str, Any]) -> bool:
    no_speech = _number(segment.get("no_speech_prob"))
    logprob = _number(segment.get("avg_logprob"))
    compression = _number(segment.get("compression_ratio"))
    if no_speech is not None and logprob is not None:
        if no_speech > NO_SPEECH_PROB_LIMIT and logprob < AVG_LOGPROB_LIMIT:
            return True
    return compression is not None and compression > COMPRESSION_RATIO_LIMIT


def spoken_text(payload: dict[str, Any], audio_size: int) -> str:
    """The text of what was really said, or "" when nothing was.

    [payload] is the provider's `verbose_json` answer; [audio_size] the bytes sent (the clip's
    length when the provider does not say)."""
    segments = [s for s in payload.get("segments") or [] if isinstance(s, dict)]
    if segments:
        kept = [s for s in segments if not _is_silence_segment(s)]
        text = " ".join(str(s.get("text") or "").strip() for s in kept).strip()
    else:
        text = str(payload.get("text") or "").strip()
    if not text or not _normalise(text):
        return ""

    duration = _number(payload.get("duration"))
    if duration is None and segments:
        duration = max((_number(s.get("end")) or 0.0 for s in segments), default=None)
    short = (
        duration <= SHORT_CLIP_SECONDS if duration is not None else audio_size <= SHORT_CLIP_BYTES
    )
    doubts = [_number(s.get("no_speech_prob")) for s in segments]
    doubtful = bool(doubts) and all(d is not None and d >= DOUBTFUL_NO_SPEECH_PROB for d in doubts)
    if (short or doubtful) and _normalise(text) in INVENTED_PHRASES:
        return ""
    return text
