"""How the exit e-mails look (docs/compliance/18, the owner's brief of 25 November 2026): the same
words as the texts, one button, the team's signature, nothing that tracks or fetches."""

from __future__ import annotations

import re

import pytest

from packages.core.domain.exit_notices import layout, texts
from packages.infrastructure.email.logo import quokka_head_png

LOGIN = "https://app.example.com/accedi"
VARIABLES = {
    "saluto": "Ciao Giulia,",
    "data": "25 novembre 2026",
    "data_fine": "25 dicembre 2026",
    "link_informativa": "https://example.com/privacy",
    "anni_registro": "5",
}
ALL = ["D1", "D2", "D3", "D4", "D_LATE", "R1"]


def _render(template_id: str, footer: str = "") -> layout.RenderedEmail:
    return layout.render_email(template_id, dict(VARIABLES), login_url=LOGIN, footer_line=footer)


@pytest.mark.parametrize("template_id", ALL)
def test_the_subject_is_the_text_s_and_the_signature_is_the_team(template_id: str) -> None:
    email = _render(template_id)
    assert email.subject == texts.TEXTS[template_id].subject
    assert email.text.rstrip().endswith("Il team di Quokka")
    assert email.html is not None and "Il team di Quokka" in email.html
    # No company or contact in the body any more, and no hole left.
    assert "{" not in email.text and "}" not in email.text
    assert "\x00" not in email.text and "\x00" not in email.html


@pytest.mark.parametrize("template_id", ALL)
def test_the_words_are_the_normativa_s_apart_from_the_link_and_the_closing_line(
    template_id: str,
) -> None:
    """Every sentence of the text is in the e-mail: nothing is cut, nothing is added."""
    _, body = texts.render_notice(
        template_id,
        {**VARIABLES, "titolare": "@@T@@", "contatto": "@@C@@", "link_recupera": "@@LINK@@"},
    )
    email = _render(template_id).text
    flat = re.sub(r"\s+", " ", email).lower()
    body = body.replace(" @@T@@, @@C@@.", "")
    body = re.sub(r"\s+con questa e-mail\s+@@LINK@@", " dal pulsante qui sotto", body)
    body = body.replace("@@LINK@@", "dal pulsante qui sotto")
    for sentence in re.split(r"(?<=[.!?])\s+", body):
        # (the paragraph after the greeting starts with a capital: compare without case)
        assert sentence.strip().lower() in flat


@pytest.mark.parametrize(
    ("template_id", "label"),
    [
        ("D1", "Apri Quokka e annulla l'eliminazione"),
        ("D2", "Apri Quokka e annulla l'eliminazione"),
        ("D3", "Apri Quokka e annulla l'eliminazione"),
        ("D_LATE", "Apri Quokka e annulla l'eliminazione"),
        ("R1", "Apri Quokka"),
        ("D4", None),
    ],
)
def test_one_button_that_goes_straight_to_the_sign_in_page(
    template_id: str, label: str | None
) -> None:
    email = _render(template_id)
    assert email.button_label == label
    assert email.html is not None
    links = re.findall(r'<a [^>]*href="([^"]+)"', email.html)
    # One button (the sign-in page, no redirect, no tracking); the only other link is the word
    # «informativa», to the privacy notice, in the e-mails with the «what stays» paragraph.
    assert [x for x in links if x != VARIABLES["link_informativa"]] == ([LOGIN] if label else [])
    assert len(re.findall(r'class="btna"', email.html)) == (1 if label else 0)
    if label:
        assert f"{label}: {LOGIN}" in email.text


def test_the_html_fetches_nothing_and_tracks_nothing() -> None:
    for template_id in ALL:
        html = _render(template_id).html
        assert html is not None
        assert "http://" not in html
        # The only address that is not a link is the logo, inside the message.
        sources = re.findall(r'(?:src|href)="([^"]+)"', html)
        assert [s for s in sources if s.startswith("cid:")] == [f"cid:{layout.LOGO_CID}"]
        assert all(s.startswith(("cid:", LOGIN, VARIABLES["link_informativa"])) for s in sources)
        assert "<script" not in html and "<iframe" not in html and "<link" not in html
        assert 'width="1"' not in html  # no pixel


def test_light_and_dark_and_a_narrow_screen_are_handled_and_the_band_stays_petrol() -> None:
    html = _render("D1").html
    assert html is not None
    assert 'name="color-scheme"' in html and "prefers-color-scheme: dark" in html
    assert "max-width:480px" in html
    # The band is petrol also in dark mode and the logo is never recoloured.
    dark = html[html.index("prefers-color-scheme: dark") :]
    assert ".band { background:#0E3B47 !important; }" in dark
    assert "filter" not in html


LINE = "Quokka è un servizio di Esempio S.r.l. · assistenza@example.com"


def test_the_small_grey_line_is_hidden_unless_the_company_is_configured() -> None:
    hidden = _render("D1")
    assert "servizio di" not in hidden.text and hidden.html is not None
    assert "servizio di" not in hidden.html and 'class="foot"' not in hidden.html
    shown = _render("D1", LINE)
    assert shown.text.rstrip().endswith(LINE)
    assert shown.html is not None and LINE in shown.html and 'class="foot"' in shown.html
    # Under the signature, never above it.
    assert shown.html.index("Il team di Quokka") < shown.html.index(LINE)


@pytest.mark.parametrize("template_id", ["D1", "D2", "D3", "D_LATE", "D4", "R1"])
def test_the_greeting_is_alone_on_the_first_line(template_id: str) -> None:
    email = _render(template_id)
    assert email.text.split("\n")[0] == "Ciao Giulia,"
    assert email.html is not None and '<p class="p">Ciao Giulia,</p>' in email.html
    # The paragraph that follows starts with a capital.
    assert email.text.split("\n\n")[1][0].isupper()


@pytest.mark.parametrize("template_id", ["D1", "D2", "D3", "D_LATE"])
def test_the_question_opens_its_paragraph_in_bold_and_never_closes_the_one_before(
    template_id: str,
) -> None:
    email = _render(template_id)
    paragraphs = email.text.split("\n\n")
    opening = [p for p in paragraphs if p.startswith("Hai cambiato idea?")]
    assert len(opening) == 1
    assert not any(p.rstrip().endswith("Hai cambiato idea?") for p in paragraphs)
    assert email.html is not None and "<strong>Hai cambiato idea?</strong>" in email.html


def test_the_restore_e_mail_does_not_say_what_stays_after_a_deletion() -> None:
    """Nothing is erased when an account is restored: no «dopo la cancellazione restano…»."""
    restore = _render("R1")
    assert "restano solo alcuni dati" not in restore.text
    assert restore.html is not None and "restano solo alcuni dati" not in restore.html
    for other in ("D1", "D2", "D3", "D_LATE", "D4"):
        assert "restano solo alcuni dati" in _render(other).text


def test_the_privacy_address_is_a_link_on_the_word_only_in_the_html() -> None:
    email = _render("D4")
    address = VARIABLES["link_informativa"]
    assert address in email.text  # the plain text keeps it written
    assert email.html is not None
    assert f'<a href="{address}" class="lnk">informativa</a>' in email.html
    visible = re.sub(r"<[^>]+>", "", email.html)
    assert address not in visible  # not written in the page


def test_the_name_is_escaped_in_the_html() -> None:
    email = layout.render_email(
        "D1",
        {**VARIABLES, "saluto": "Ciao <b>x</b>,"},
        login_url=LOGIN,
    )
    assert email.html is not None
    assert "<b>x</b>" not in email.html and "&lt;b&gt;x&lt;/b&gt;" in email.html


def test_the_logo_is_a_small_png_inside_the_package() -> None:
    data = quokka_head_png()
    assert data.startswith(b"\x89PNG") and len(data) < 30_000
