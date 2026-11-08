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
    "footer_owner": "Titolare: <mark>[TITOLARE]</mark>, <mark>[SEDE]</mark>, <mark>[CF_PIVA]</mark>.",
    "footer_note": "Questo sito non usa cookie né strumenti di analisi.",
    "footer_draft": "Sito in costruzione.",
}

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
<p class="lead">Quokka ti aiuta a capire il tuo animale: perché fa quello che fa, come gestirlo ogni giorno, quali sono i tuoi doveri e quando serve il veterinario. Risposte basate su fonti scientifiche e posizioni ufficiali, per ogni specie.</p>
<p>Nell'app trovi un assistente basato su intelligenza artificiale, le schede dei tuoi animali con referti e vaccini, i promemoria, le passeggiate e i servizi vicino a te. Quokka non è un veterinario e non sostituisce un educatore o un comportamentalista.</p>
<p>Il sito è in costruzione e l'app non è ancora disponibile negli store. Qui trovi le informazioni che servono a chi la usa o la userà.</p>
<ul class="cards">
<li><a href="/it/supporto/"><strong>Assistenza</strong><span>Come contattarci e le domande più frequenti.</span></a></li>
<li><a href="/it/privacy/"><strong>Informativa sulla privacy</strong><span>Quali dati trattiamo, perché e quali sono i tuoi diritti.</span></a></li>
<li><a href="/it/termini/"><strong>Termini di servizio</strong><span>Le regole per usare Quokka.</span></a></li>
<li><a href="/it/cancellazione-account/"><strong>Cancellazione dell'account</strong><span>Come eliminare l'account e i tuoi dati, con o senza l'app.</span></a></li>
<li><a href="/it/avviso-ia/"><strong>Avviso sull'intelligenza artificiale</strong><span>L'assistente non è un veterinario.</span></a></li>
</ul>""",
    },
    {
        "slug": "supporto",
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
        "nav": "Privacy",
        "title": "Informativa sulla privacy",
        "description": "Quali dati personali tratta Quokka, perché, con chi li condivide e quali sono i tuoi diritti.",
        "md": "docs/compliance/it/02_informativa_privacy_it.md",
        "subs": _URLS,
        "toc": True,
    },
    {
        "slug": "termini",
        "nav": "Termini",
        "title": "Termini di servizio",
        "description": "Le regole per usare Quokka.",
        "md": "docs/compliance/it/03_termini_di_servizio_it.md",
        "subs": _URLS,
        "toc": True,
    },
    {
        "slug": "cancellazione-account",
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
<p><strong>Quokka non è un servizio di emergenza.</strong> Chiama subito il tuo veterinario o la clinica veterinaria più vicina. Non rimandare una visita per qualcosa che ha detto l'app.</p>
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
<p><a href="/it/">Torna alla home</a> oppure vai all'<a href="/it/supporto/">assistenza</a>.</p>""",
}
