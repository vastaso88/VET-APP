# ruff: noqa: E501
"""Italian page definitions for the Quokka site. See build.py.

The legal texts (privacy, terms, support) are NOT written here: they are read from
docs/compliance/it/, which the legal workstream owns. This file only holds the pages
that are about the site itself (home, account deletion, AI notice) and the layout words.
"""

LANG = "it"

# Project contact address. Used only on the pages written here and on the support page;
# the privacy policy and the terms keep their own [EMAIL_*] placeholders until the owner decides.
CONTACT_EMAIL = "quokkaapp26@gmail.com"
_MAIL = f"[{CONTACT_EMAIL}](mailto:{CONTACT_EMAIL})"

UI = {
    "skip": "Vai al contenuto",
    "nav_label": "Pagine del sito",
    "toc_label": "Indice della pagina",
    "draft_banner": (
        "<strong>BOZZA.</strong> Questo testo non è ancora definitivo e non è stato rivisto da un "
        "legale. I dati tra parentesi quadre, evidenziati, sono ancora da compilare."
    ),
    # Company facts the law wants on the site of an S.r.l. (art. 2250 c.c.; VAT number on
    # the home page, art. 35 DPR 633/1972). Values come from QUOKKA_SITE_*, never from here.
    "footer_owner": (
        "Quokka è un servizio di [TITOLARE], sede legale [SEDE], codice fiscale e partita IVA "
        "[CF_PIVA]. Registro delle imprese: [REA_REGISTRO_IMPRESE_SE_SOCIETA]. "
        "Capitale sociale versato: [CAPITALE_SOCIALE_VERSATO]. "
        "[SOCIO_UNICO_O_VUOTO] [LIQUIDAZIONE_O_VUOTO]"
    ),
    "footer_note": "Questo sito non usa cookie né strumenti di analisi.",
    "footer_draft": "Sito in costruzione.",
    # Home: shown while PLAY_STORE_URL is empty, then replaced by the button.
    "play_soon": (
        '<div class="callout"><p><strong>Quokka arriverà presto su Google Play.</strong> '
        "Quando sarà disponibile, qui troverai il link per scaricarla.</p></div>"
    ),
    "play_button": (
        '<p><a class="button" href="{url}" rel="noopener">Scarica Quokka da Google Play</a></p>'
    ),
}

# The app's page on Google Play. Empty until Google approves the listing; when it is set,
# the home shows the download button instead of the "coming soon" line.
PLAY_STORE_URL = ""

_URLS = {"[URL_INFORMATIVA]": "/it/privacy/", "[URL_TERMINI]": "/it/termini/"}

_SUPPORT_SUBS = {
    **_URLS,
    "**[EMAIL_ASSISTENZA]**": _MAIL,
    "[EMAIL_ASSISTENZA]": _MAIL,
    "[EMAIL_PRIVACY]": _MAIL,
    "[EMAIL_SEGNALAZIONI]": _MAIL,
    "[EMAIL_SICUREZZA]": _MAIL,
}

PAGES = [
    {
        "slug": "",
        "nav": "Home",
        "title": "Quokka",
        "description": "Quokka ti aiuta a capire il tuo animale: perché fa quello che fa, come gestirlo ogni giorno, i tuoi doveri e quando serve il veterinario.",
        "body": """<h1>Quokka</h1>
<p class="lead">Quokka ti aiuta a capire il tuo animale: perché fa quello che fa, come gestirlo ogni giorno, quali sono i tuoi doveri e quando serve il veterinario. Risposte in parole semplici, pensate per ogni specie.</p>
<p>Nell'app trovi un assistente basato su intelligenza artificiale, le schede dei tuoi animali con referti e vaccini, i promemoria, le passeggiate e i servizi vicino a te. Quokka non è un veterinario e non sostituisce un educatore o un comportamentalista.</p>
<!--PLAY-->
<!--CARDS-->
<h2 id="contatti">Contatti</h2>
<p>Per qualsiasi domanda scrivi a <a href="mailto:{CONTACT_EMAIL}">{CONTACT_EMAIL}</a>.</p>""".replace(
            "{CONTACT_EMAIL}", CONTACT_EMAIL
        ),
    },
    {
        "slug": "supporto",
        "card": "Come contattarci e le domande più frequenti.",
        "nav": "Assistenza",
        "title": "Assistenza",
        "description": "Come contattare l'assistenza di Quokka e le domande più frequenti.",
        "md": "docs/compliance/it/04_pagina_assistenza_it.md",
        "subs": _SUPPORT_SUBS,
        "toc": False,
        "intro": (
            '<div class="callout"><h2>Tempi di risposta indicativi</h2>'
            "<p>Di solito rispondiamo entro 3–5 giorni lavorativi. È un'indicazione, non una "
            "promessa. Le richieste sui tuoi dati personali (copia, correzione, cancellazione) "
            "hanno comunque i tempi previsti dalla legge, di norma un mese al massimo.</p></div>"
        ),
    },
    {
        "slug": "privacy",
        "card": "Quali dati trattiamo, perché e quali sono i tuoi diritti.",
        "nav": "Privacy",
        "title": "Informativa sulla privacy",
        "description": "Quali dati personali tratta Quokka, perché, con chi li condivide e quali sono i tuoi diritti.",
        "md": "docs/compliance/it/02_informativa_privacy_it.md",
        "subs": _URLS,
        "toc": True,
    },
    {
        "slug": "termini",
        "card": "Le regole per usare Quokka.",
        "nav": "Termini",
        "title": "Termini di servizio",
        "description": "Le regole per usare Quokka.",
        "md": "docs/compliance/it/03_termini_di_servizio_it.md",
        "subs": _URLS,
        "toc": True,
    },
    {
        "slug": "cancellazione-account",
        "card": "Come eliminare l'account e i tuoi dati, con o senza l'app.",
        "nav": "Cancella account",
        "title": "Cancellazione dell'account",
        "description": "Come eliminare il tuo account Quokka e i tuoi dati, dall'app o scrivendoci.",
        "draft": True,
        "body": f"""<h1>Cancellazione dell'account</h1>
<p class="lead">Puoi eliminare il tuo account Quokka e i dati collegati in due modi. La cancellazione è definitiva: non possiamo recuperare nulla.</p>

<h2 id="dall-app">Dall'app (il modo più rapido)</h2>
<ol>
<li>Apri Quokka e accedi.</li>
<li>Vai in <strong>Impostazioni</strong>, sezione <strong>Account</strong>.</li>
<li>Tocca <strong>Elimina account</strong>.</li>
<li>Leggi l'avviso, scrivi la tua password per conferma, spunta «Ho capito» e tocca <strong>Elimina definitivamente il mio account</strong>.</li>
</ol>
<p>Prima di eliminare puoi scaricare una copia dei tuoi dati da <strong>Impostazioni → Account → Scarica i miei dati</strong>.</p>

<h2 id="senza-app">Senza l'app, scrivendoci</h2>
<p>Se non hai più l'app o non riesci ad accedere, scrivi a <a href="mailto:{CONTACT_EMAIL}">{CONTACT_EMAIL}</a>.</p>
<ul>
<li>Scrivi <strong>dall'indirizzo e-mail con cui ti sei registrato</strong>, con oggetto «Cancellazione account Quokka».</li>
<li>Dicci che vuoi eliminare l'account. Non serve altro.</li>
<li>Non mandarci la password né documenti sulla tua salute.</li>
<li>Per essere sicuri che la richiesta sia tua, potremmo chiederti una conferma rispondendo a quello stesso messaggio.</li>
</ul>
<p>Cancelliamo l'account appena possibile e ti confermiamo per e-mail. Al massimo entro un mese.</p>

<h2 id="cosa-si-cancella">Cosa viene cancellato</h2>
<ul>
<li>I profili dei tuoi animali, le misurazioni, le foto e i video.</li>
<li>Le chat con l'assistente e i loro allegati.</li>
<li>I promemoria e le passeggiate, compresi i percorsi.</li>
<li>I referti e i documenti che hai caricato.</li>
<li>I tuoi consensi e la posizione salvata.</li>
<li>Gli annunci che hai pubblicato nel Mercatino.</li>
<li>Il profilo: nome, numero di telefono e foto profilo, se li avevi inseriti.</li>
<li>Le credenziali di accesso: e-mail e password.</li>
</ul>

<h2 id="cosa-puo-restare">Cosa può restare</h2>
<ul>
<li>Le segnalazioni e i voti che hai dato sui luoghi della mappa non portano il tuo nome. Il contenuto può restare nella mappa, senza alcun riferimento a te. Il dettaglio è nella sezione «Per quanto tempo conserviamo i dati» dell'<a href="/it/privacy/">informativa sulla privacy</a>.</li>
<li>I nostri fornitori (database e hosting) tengono copie di sicurezza per un periodo limitato, poi spariscono da sole. <mark>[da verificare: durata delle copie di sicurezza]</mark></li>
</ul>

<p>Altre domande: <a href="/it/supporto/">pagina di assistenza</a>.</p>""",
    },
    {
        "slug": "avviso-ia",
        "card": "L'assistente non è un veterinario.",
        "nav": "Avviso IA",
        "title": "Avviso sull'intelligenza artificiale",
        "description": "L'assistente di Quokka è un'intelligenza artificiale: non fa diagnosi e non sostituisce il veterinario.",
        "draft": True,
        "body": """<h1>Avviso sull'intelligenza artificiale</h1>
<p class="lead">L'assistente di Quokka è un'intelligenza artificiale. Non è una persona e non è un veterinario.</p>

<h2 id="cosa-fa">Cosa può fare</h2>
<p>Dà informazioni generali: ti aiuta a capire un termine o un esame, a organizzare i dubbi e a preparare le domande da fare al tuo veterinario.</p>

<h2 id="cosa-non-fa">Cosa non fa</h2>
<ul>
<li>Non fa diagnosi.</li>
<li>Non prescrive medicinali e non indica dosaggi di farmaci con obbligo di prescrizione.</li>
<li>Non sostituisce una visita veterinaria.</li>
</ul>

<h2 id="puo-sbagliare">Può sbagliare</h2>
<p>Le risposte possono essere incomplete o sbagliate. Usale come informazione generale e controlla ogni cosa importante con il tuo veterinario. Se una risposta ti sembra sbagliata, usa il pulsante per segnalarla: ci aiuta a correggere il problema.</p>

<h2 id="emergenze">Se il tuo animale sta male</h2>
<div class="callout">
<p><strong>Quokka non gestisce le urgenze: non aspettare la risposta dell'app.</strong> Chiama subito il tuo veterinario o la clinica veterinaria più vicina. Non rimandare una visita per qualcosa che ha detto l'app.</p>
</div>

<h2 id="dati">Che fine fanno le tue domande</h2>
<p>Per rispondere, il testo delle tue domande viene inviato a un fornitore esterno di intelligenza artificiale. Prima, il sistema toglie in automatico alcuni dati personali riconoscibili, come e-mail e telefono. Non può riconoscerli tutti: evita di scrivere dati personali tuoi o di altri.</p>
<p>La chat legge la cartella clinica di un tuo animale solo se lo consenti, animale per animale, e puoi revocare il consenso quando vuoi. Il dettaglio è nell'<a href="/it/privacy/">informativa sulla privacy</a>, nella sezione «Come usiamo l'intelligenza artificiale».</p>""",
    },
]

NOT_FOUND = {
    "title": "Pagina non trovata",
    "body": """<h1>Pagina non trovata</h1>
<p class="lead">La pagina che cerchi non esiste o è stata spostata.</p>
<p><a href="/it/">Torna alla home</a>.</p>""",
}
