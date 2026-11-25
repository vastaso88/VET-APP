# ruff: noqa: E501
"""Builds ONE page that shows every exit e-mail exactly as the customer sees it.

    python scripts/email/build_preview.py --out .local/consegne/email_anteprima/anteprima.html

Each e-mail is drawn with the real code (`layout.render_email`, the same words as
`texts`), on a phone and on a computer, light and dark, with the plain-text version beside it.
The sample names and dates are invented; nothing is sent and nothing leaves the page (the logo
is inline). The buttons say where they lead.
"""

from __future__ import annotations

import argparse
import base64
import json
import sys
from html import escape
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from packages.core.domain.exit_notices import layout  # noqa: E402
from packages.infrastructure.email.logo import quokka_head_png  # noqa: E402

LOGIN_URL = "https://app.example.com/accedi"
PRIVACY_URL = "https://example.com/privacy"
# The small grey line, shown only when the company and the contact are configured.
COMPANY_LINE = "Quokka è un servizio di Esempio S.r.l. · assistenza@example.com"

VARIABLES = {
    "saluto": "Ciao Giulia,",
    "data": "25 novembre 2026",
    "data_fine": "25 dicembre 2026",
    "link_informativa": PRIVACY_URL,
    "anni_registro": "5",
}

# (id, title, when it arrives, where the button leads)
EMAILS = [
    (
        "D1",
        "Subito dopo la richiesta di eliminazione",
        "Arriva appena la persona chiede di eliminare l'account.",
        "Apre Quokka alla pagina di accesso; dopo l'accesso la persona tocca «Annulla l'eliminazione».",
    ),
    (
        "D2",
        "Sette giorni prima della cancellazione",
        "Arriva 7 giorni prima del giorno della cancellazione.",
        "Apre Quokka alla pagina di accesso: da lì si annulla l'eliminazione.",
    ),
    (
        "D3",
        "Il giorno prima",
        "Arriva il giorno prima: è l'ultimo avviso.",
        "Apre Quokka alla pagina di accesso: da lì si annulla l'eliminazione.",
    ),
    (
        "D_LATE",
        "Avviso in ritardo (al posto di D2 o D3)",
        "Esce solo se un guasto nostro ha fatto saltare il giorno giusto: dice la data vera.",
        "Apre Quokka alla pagina di accesso: da lì si annulla l'eliminazione.",
    ),
    (
        "D4",
        "Dopo la cancellazione",
        "Arriva quando l'account è stato eliminato.",
        "Nessun pulsante: non c'è più nulla da fare.",
    ),
    (
        "R1",
        "Dopo il ripristino",
        "Arriva quando la persona ha annullato l'eliminazione.",
        "Apre Quokka alla pagina di accesso.",
    ),
]


def build(out: Path) -> None:
    logo = quokka_head_png()
    data_uri = "data:image/png;base64," + base64.b64encode(logo).decode("ascii")
    emails = []
    for template_id, title, when, leads in EMAILS:
        rendered = layout.render_email(
            template_id, dict(VARIABLES), login_url=LOGIN_URL, footer_line=""
        )
        with_company = layout.render_email(
            template_id, dict(VARIABLES), login_url=LOGIN_URL, footer_line=COMPANY_LINE
        )
        assert rendered.html is not None and with_company.html is not None
        light = layout.html_for_preview(rendered.html, data_uri)
        dark = light.replace("@media (prefers-color-scheme: dark)", "@media all")
        light_co = layout.html_for_preview(with_company.html, data_uri)
        dark_co = light_co.replace("@media (prefers-color-scheme: dark)", "@media all")
        emails.append(
            {
                "id": template_id,
                "title": title,
                "when": when,
                "leads": leads,
                "subject": rendered.subject,
                "button": rendered.button_label,
                "light": light,
                "dark": dark,
                "light_co": light_co,
                "dark_co": dark_co,
                "text": rendered.text,
            }
        )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(_page(emails), encoding="utf-8")


def _page(emails: list[dict[str, object]]) -> str:
    cards = "\n".join(_card(i, e) for i, e in enumerate(emails))
    payload = json.dumps(
        [{k: e[k] for k in ("light", "dark", "light_co", "dark_co")} for e in emails],
        ensure_ascii=False,
    ).replace("</", "<\\/")
    return f"""<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Anteprima delle e-mail di Quokka</title>
<style>
  :root {{ color-scheme: light; }}
  body {{ margin:0; background:#F6F1EA; color:#213134;
          font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif; line-height:1.5; }}
  header.top {{ background:#0E3B47; color:#F7F5F0; padding:22px 20px; }}
  header.top h1 {{ margin:0 0 6px; font-size:22px; }}
  header.top p {{ margin:0; max-width:760px; opacity:.92; }}
  .bar {{ position:sticky; top:0; z-index:5; background:#FCFAF7; border-bottom:1px solid #E6DDD2;
          padding:10px 20px; display:flex; gap:10px; flex-wrap:wrap; align-items:center; }}
  .bar button {{ border:1px solid #D8CCBF; background:#fff; padding:8px 14px; border-radius:999px;
                 font-size:14px; cursor:pointer; }}
  .bar button.on {{ background:#2E686A; color:#fff; border-color:#2E686A; }}
  main {{ max-width:1180px; margin:0 auto; padding:18px 16px 60px; }}
  .mail {{ background:#FCFAF7; border:1px solid #E6DDD2; border-radius:16px; padding:18px;
           margin:0 0 26px; }}
  .mail h2 {{ margin:0 0 4px; font-size:19px; }}
  .meta {{ margin:2px 0; font-size:14px; color:#52645F; }}
  .meta b {{ color:#213134; }}
  .stage {{ display:flex; gap:22px; align-items:flex-start; flex-wrap:wrap; margin-top:14px; }}
  .frame {{ border:1px solid #D8CCBF; border-radius:14px; overflow:hidden; background:#fff; }}
  .frame .cap {{ font-size:12px; color:#52645F; background:#EDE6DC; padding:4px 10px; }}
  .phone {{ width:390px; max-width:100%; }}
  .desk {{ width:640px; max-width:100%; }}
  iframe {{ display:block; width:100%; border:0; background:#fff; }}
  iframe {{ min-height:320px; }}
  details {{ margin-top:12px; }}
  pre {{ white-space:pre-wrap; background:#fff; border:1px solid #E6DDD2; border-radius:10px;
         padding:12px; font-size:13px; }}
</style>
</head>
<body>
<header class="top">
  <h1>Anteprima delle e-mail di Quokka</h1>
  <p>Così le vede chi le riceve, sul telefono e sul computer, con tema chiaro e scuro. I nomi e le date sono
  di esempio. Nessuna e-mail è stata inviata. I testi sono ancora «proposta, in attesa del sì».
  La pausa dell'account non esiste più: restano solo l'eliminazione e il ripristino.</p>
</header>
<div class="bar">
  <span>Tema:</span>
  <button id="tl" class="on" type="button">Chiaro</button>
  <button id="td" type="button">Scuro</button>
  <span style="margin-left:14px">Riga della società:</span>
  <button id="co" type="button">Nascosta (oggi)</button>
</div>
<main>
{cards}
</main>
<script>
  const MAILS = {payload};
  let mode = 'light';
  let company = false;
  function fit(f) {{
    try {{
      f.style.height = '0px';
      f.style.height = (f.contentDocument.documentElement.scrollHeight + 4) + 'px';
    }} catch (e) {{}}
  }}
  function paint() {{
    document.querySelectorAll('iframe[data-i]').forEach(f => {{
      f.onload = () => {{ fit(f); setTimeout(() => fit(f), 150); setTimeout(() => fit(f), 600); }};
      f.srcdoc = MAILS[+f.dataset.i][mode + (company ? '_co' : '')];
    }});
    document.getElementById('tl').classList.toggle('on', mode === 'light');
    document.getElementById('td').classList.toggle('on', mode === 'dark');
    const b = document.getElementById('co');
    b.classList.toggle('on', company);
    b.textContent = company ? "Come sarà quando c'è la società" : "Nascosta (oggi)";
  }}
  document.getElementById('co').onclick = () => {{ company = !company; paint(); }};
  window.addEventListener('resize', () => document.querySelectorAll('iframe[data-i]').forEach(fit));
  document.getElementById('tl').onclick = () => {{ mode = 'light'; paint(); }};
  document.getElementById('td').onclick = () => {{ mode = 'dark'; paint(); }};
  paint();
</script>
</body>
</html>
"""


def _card(index: int, e: dict[str, object]) -> str:
    button = e["button"]
    leads = (
        f"«{escape(str(button))}»: {escape(str(e['leads']))}" if button else escape(str(e["leads"]))
    )
    return f"""<section class="mail">
  <h2>{escape(str(e["id"]))} · {escape(str(e["title"]))}</h2>
  <p class="meta"><b>Oggetto:</b> {escape(str(e["subject"]))}</p>
  <p class="meta"><b>Quando:</b> {escape(str(e["when"]))}</p>
  <p class="meta"><b>Il pulsante:</b> {leads}</p>
  <div class="stage">
    <div class="frame phone"><div class="cap">Telefono</div><iframe data-i="{index}" title="Telefono {escape(str(e["id"]))}"></iframe></div>
    <div class="frame desk"><div class="cap">Computer</div><iframe data-i="{index}" title="Computer {escape(str(e["id"]))}"></iframe></div>
  </div>
  <details><summary>Versione solo testo (per chi non vede le immagini o il formato)</summary>
    <pre>{escape(str(e["text"]))}</pre></details>
</section>"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    build(Path(args.out))
    print(f"written: {args.out}")


if __name__ == "__main__":
    main()
