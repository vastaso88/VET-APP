"""How an exit e-mail looks: the same words as `texts` (docs/compliance/18), laid out.

Two renderings of one message, never different in meaning:
- plain text: short paragraphs, the link written out, "Il team di Quokka" at the end;
- HTML: a petrol band with the quokka (always the light version, never recoloured, also in dark
  mode), the title, the paragraphs, ONE button, the «what stays» paragraph smaller, the
  signature. Light and dark by `prefers-color-scheme`, one 600 px column that narrows on a
  phone, system fonts only.

Rules that hold for both: no tracking (no pixel, no redirecting link: the button goes straight
to the sign-in page), no external file (the logo is attached to the message and referenced by
`cid:`), nothing but what the text says. The words are the Normativa's: this module only splits
them into paragraphs, drops the closing «{titolare}, {contatto}.» (the signature is the team's)
and turns the link into a button. Whatever the Normativa decides about the sender's identity
goes in the footer line, which stays empty until it is configured.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from html import escape

from packages.core.domain.exit_notices import texts

LOGO_CID = "quokka-logo"
SIGNATURE = "Il team di Quokka"

# What the single button says, by notice. None: nothing to do any more, no button.
BUTTON_LABELS: dict[str, str | None] = {
    "D1": "Apri Quokka e annulla l'eliminazione",
    "D2": "Apri Quokka e annulla l'eliminazione",
    "D3": "Apri Quokka e annulla l'eliminazione",
    "D_LATE": "Apri Quokka e annulla l'eliminazione",
    "D4": None,
    "R1": "Apri Quokka",
    "D4_PAUSE": None,
}
# Where the link sat in the sentence («accedi con questa e-mail <link>»), the e-mail now says
# «accedi dal pulsante qui sotto»: the button does the work, the sentence stays the Normativa's.
LINK_WORDS = "dal pulsante qui sotto"

_COMPANY_MARK = "\x00T"
_CONTACT_MARK = "\x00C"
_LINK_MARK = "\x00L"
_LINK_IN_SENTENCE = re.compile(r"\s+con questa e-mail\s+" + re.escape(_LINK_MARK))
_GREETING = re.compile(r"^(Ciao[^,]*,)\s+(.*)$", re.DOTALL)
_QUESTION = "Hai cambiato idea?"
_SENTENCE_END = re.compile(r"(?<=[.!?])\s+(?=[A-ZÀ-Ý«])")


@dataclass(frozen=True)
class RenderedEmail:
    subject: str
    text: str
    html: str | None
    button_label: str | None


def _split_body(template_id: str, variables: dict[str, str]) -> tuple[str, list[str], str]:
    """(subject, paragraphs, what-stays) with the link left as a mark and no signature line."""
    marked = {
        **variables,
        "titolare": _COMPANY_MARK,
        "contatto": _CONTACT_MARK,
        "link_recupera": _LINK_MARK,
    }
    subject, body, block = texts.render_notice_split(template_id, marked)
    body = body.replace(f"{_COMPANY_MARK}, {_CONTACT_MARK}.", "").strip()
    # «Ciao Giulia,» alone on the first line; the next paragraph starts with a capital.
    paragraphs: list[str] = []
    match = _GREETING.match(body)
    if match:
        paragraphs.append(match.group(1))
        body = match.group(2)
        body = body[:1].upper() + body[1:]
    # Two sentences to a paragraph, short enough to read on a phone; «Hai cambiato idea?» opens
    # the paragraph that follows instead of closing the one before.
    current: list[str] = []
    for sentence in _SENTENCE_END.split(body):
        if current and (len(current) >= 2 or sentence.startswith(_QUESTION)):
            paragraphs.append(" ".join(current))
            current = []
        current.append(sentence)
    if current:
        paragraphs.append(" ".join(current))
    return subject, paragraphs, block


def render_email(
    template_id: str,
    variables: dict[str, str],
    *,
    login_url: str,
    footer_line: str = "",
) -> RenderedEmail:
    """The subject, the plain text and the HTML of one notice. [variables] are the text's own
    (dates, greeting, links); [login_url] is where the button goes."""
    subject, paragraphs, block = _split_body(template_id, variables)
    label = BUTTON_LABELS.get(template_id)
    text_parts = [_plain(p) for p in paragraphs]
    if block:
        text_parts.append(_plain(block))
    if label:
        text_parts.append(f"{label}: {login_url}")
    text_parts.append(SIGNATURE)
    if footer_line.strip():
        text_parts.append(footer_line.strip())
    text = "\n\n".join(text_parts) + "\n"

    html = _html(
        subject,
        paragraphs,
        block,
        label,
        login_url,
        footer_line,
        variables.get("link_informativa", ""),
    )
    return RenderedEmail(subject=subject, text=text, html=html, button_label=label)


def _plain(paragraph: str) -> str:
    """The sentence with the link turned into «dal pulsante qui sotto»."""
    paragraph = _LINK_IN_SENTENCE.sub(f" {LINK_WORDS}", paragraph)
    return paragraph.replace(_LINK_MARK, LINK_WORDS)


def _html(
    subject: str,
    paragraphs: list[str],
    block: str,
    label: str | None,
    login_url: str,
    footer_line: str,
    privacy_url: str = "",
) -> str:
    def para(paragraph: str, cls: str = "p") -> str:
        safe = escape(_plain(paragraph))
        if privacy_url:
            # The word «informativa» is the link; in the plain text the address stays written.
            safe = safe.replace(
                f"informativa {escape(privacy_url)}",
                f'<a href="{escape(privacy_url, quote=True)}" class="lnk">informativa</a>',
            )
        safe = safe.replace(_QUESTION, f"<strong>{_QUESTION}</strong>")
        return f'<p class="{cls}">{safe}</p>'

    body = "\n".join(para(p) for p in paragraphs)
    button = ""
    if label:
        button = (
            '<table role="presentation" cellpadding="0" cellspacing="0" border="0" '
            'class="btnwrap"><tr><td class="btn">'
            f'<a href="{escape(login_url, quote=True)}" class="btna">{escape(label)}</a>'
            "</td></tr></table>"
        )
    stays = para(block, "small") if block else ""
    footer = f'<p class="foot">{escape(footer_line.strip())}</p>' if footer_line.strip() else ""
    return f"""<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<title>{escape(subject)}</title>
<style>
  :root {{ color-scheme: light dark; supported-color-schemes: light dark; }}
  body {{ margin:0; padding:0; background:#F6F1EA; }}
  .wrap {{ background:#F6F1EA; padding:24px 12px; }}
  .card {{ max-width:600px; margin:0 auto; background:#FFFFFF; border-radius:14px;
           overflow:hidden; }}
  .band {{ background:#0E3B47; padding:22px 28px; }}
  .band img {{ display:block; border:0; outline:none; }}
  .inner {{ padding:28px; font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;
            color:#213134; font-size:16px; line-height:1.55; }}
  h1 {{ font-size:21px; line-height:1.3; margin:0 0 18px; color:#0E3B47; }}
  .p {{ margin:0 0 14px; }}
  .small {{ margin:22px 0 0; font-size:13px; line-height:1.5; color:#52645F; }}
  .btnwrap {{ margin:22px 0 6px; }}
  .btn {{ background:#2E686A; border-radius:10px; }}
  .btna {{ display:inline-block; padding:14px 22px; color:#FFFFFF; text-decoration:none;
           font-weight:600; font-size:16px; border-radius:10px; }}
  .lnk {{ color:#2E686A; }}
  .sign {{ margin:26px 0 0; font-weight:600; }}
  .foot {{ margin:14px 0 0; font-size:12px; color:#52645F; }}
  @media (max-width:480px) {{
    .wrap {{ padding:0; }} .card {{ border-radius:0; }}
    .inner {{ padding:22px 18px; }} .band {{ padding:18px; }}
    .btn, .btna {{ display:block; text-align:center; }}
  }}
  @media (prefers-color-scheme: dark) {{
    body, .wrap {{ background:#10191C !important; }}
    .card {{ background:#1A2A2E !important; }}
    .inner {{ color:#E6EEEC !important; }}
    h1 {{ color:#E6EEEC !important; }}
    .small, .foot {{ color:#A9BAB6 !important; }}
    .btn {{ background:#4F9A9C !important; }}
    .btna {{ color:#0B1A1D !important; }}
    .lnk {{ color:#8CCBCD !important; }}
    /* the band stays petrol and the logo is never recoloured */
    .band {{ background:#0E3B47 !important; }}
  }}
</style>
</head>
<body>
<div class="wrap">
<div class="card">
  <div class="band"><img src="cid:{LOGO_CID}" width="64" alt="Quokka"></div>
  <div class="inner">
    <h1>{escape(subject)}</h1>
{body}
{button}
{stays}
    <p class="sign">{escape(SIGNATURE)}</p>
{footer}
  </div>
</div>
</div>
</body>
</html>
"""


def html_for_preview(html: str, logo_data_uri: str) -> str:
    """The same HTML with the logo inline (a browser has no message to take the attachment from)."""
    return html.replace(f"cid:{LOGO_CID}", logo_data_uri)
