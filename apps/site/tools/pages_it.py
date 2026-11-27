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
<p class="lead">Questa pagina spiega come eliminare l'account di <strong>Quokka</strong>, l'app di [TITOLARE], e i dati collegati, con o senza l'app. Se lo fai dall'app, per 30 giorni puoi cambiare idea; poi la cancellazione è definitiva.</p>

<h2 id="dall-app">Dall'app (il modo più rapido)</h2>
<ol>
<li>Apri Quokka e accedi.</li>
<li>Vai in <strong>Impostazioni</strong>, sezione <strong>Account</strong>.</li>
<li>Tocca <strong>Elimina account</strong>.</li>
<li>Leggi l'avviso, scrivi la tua password per conferma, spunta «Ho capito» e tocca <strong>Elimina definitivamente il mio account</strong>.</li>
</ol>
<p>L'account si disattiva subito. Se preferisci che la cancellazione sia immediata, nella stessa pagina tocca <strong>Elimina subito, senza possibilità di recupero</strong>.</p>
<p>Prima di eliminare puoi scaricare una copia dei tuoi dati da <strong>Impostazioni → Account → Scarica i miei dati</strong>.</p>

<h2 id="ripensamento">Se cambi idea</h2>
<p>Per 30 giorni dalla richiesta puoi annullare l'eliminazione: apri l'app e accedi con la stessa e-mail. Se non ricordi la password, tocca <strong>Recupera account</strong> nella schermata di accesso e reimpostala con il link che ti mandiamo per e-mail. Poi tocca <strong>Annulla l'eliminazione</strong>. Se invece vuoi chiudere subito, tocca <strong>Elimina subito</strong>.</p>

<h2 id="tempi">Quando cancelliamo i dati</h2>
<ul>
<li>Appena chiedi l'eliminazione dall'app l'account si disattiva: non è più visibile e non lo usiamo.</li>
<li>Dopo 30 giorni cancelliamo l'account e i dati.</li>
<li>Se abbiamo un indirizzo e-mail confermato a cui scriverti, ti scriviamo quando riceviamo la richiesta, 7 giorni prima, il giorno prima e a cancellazione fatta. Sono messaggi di servizio, senza offerte. Se un guasto nostro ritarda l'avviso finale, la cancellazione può slittare di qualche giorno, al massimo 7, e ti scriviamo la nuova data.</li>
</ul>

<h2 id="senza-app">Se non hai più l'app</h2>
<p>Hai due strade.</p>
<ol>
<li><strong>Reinstalla l'app.</strong> Scarica di nuovo Quokka, accedi con la stessa e-mail (se non ricordi la password, reimpostala con il link che ti mandiamo per e-mail) e segui i passi qui sopra.</li>
<li><strong>Scrivici</strong> a <a href="mailto:{CONTACT_EMAIL}">{CONTACT_EMAIL}</a>, se non riesci ad accedere.
<ul>
<li>Scrivi <strong>dall'indirizzo e-mail con cui ti sei registrato</strong>, con oggetto «Cancellazione account Quokka».</li>
<li>Dicci che vuoi eliminare l'account. Non serve altro.</li>
<li>Non mandarci la password né documenti sulla tua salute.</li>
<li>Per essere sicuri che la richiesta sia tua, potremmo chiederti una conferma rispondendo a quello stesso messaggio.</li>
</ul>
Cancelliamo l'account e ti confermiamo per e-mail, al massimo entro un mese. Per questa strada la cancellazione è subito definitiva: non c'è il periodo di 30 giorni per cambiare idea.</li>
</ol>

<h2 id="cosa-si-cancella">Cosa viene cancellato</h2>
<ul>
<li>I profili dei tuoi animali, le misurazioni, le foto e i video.</li>
<li>Le chat con l'assistente e i loro allegati.</li>
<li>I promemoria e le passeggiate, compresi i percorsi.</li>
<li>I referti e i documenti che hai caricato.</li>
<li>I tuoi consensi, la posizione salvata e l'elenco dei tuoi dispositivi.</li>
<li>Gli annunci che hai pubblicato nel Mercatino e i messaggi delle tue conversazioni (con l'eccezione indicata sotto).</li>
<li>Il profilo: nome, numero di telefono e foto profilo, se li avevi inseriti.</li>
<li>Le credenziali di accesso: e-mail e password.</li>
</ul>

<h2 id="cosa-puo-restare">Cosa può restare, e per quanto tempo</h2>
<ul>
<li><strong>Un registro della cancellazione</strong>: un'impronta non reversibile dell'identificativo dell'account, la data e il motivo, senza nome, e-mail né contenuti. Resta 5 anni, come prova di aver rispettato la tua richiesta.</li>
<li><strong>Una conversazione del Mercatino che è stata segnalata</strong>, se la segnalazione è aperta o è stata accolta: resta, senza i tuoi dati di account, fino a 6 mesi dopo la decisione, perché serve a difendere un diritto. Le conversazioni non segnalate, o la cui segnalazione è stata respinta, si cancellano subito.</li>
<li><strong>I registri delle decisioni del team</strong> sul Mercatino, senza testi e senza dati del tuo account: 24 mesi.</li>
<li>Le segnalazioni e i voti che hai dato sui luoghi della mappa non portano il tuo nome. Il contenuto può restare nella mappa, senza alcun riferimento a te.</li>
<li>Ciò che la legge ci obbliga a conservare, per esempio i documenti fiscali, se hai fatto acquisti.</li>
<li>I testi che l'assistente ha già inviato al fornitore di intelligenza artificiale per scriverti le risposte: di norma il fornitore li cancella entro 30 giorni dall'invio; più a lungo solo in casi eccezionali, descritti nell'informativa.</li>
<li>Eventuali copie di sicurezza si cancellano entro 30 giorni dalla cancellazione definitiva.</li>
</ul>
<p>Il dettaglio è nell'<a href="/it/privacy/">informativa sulla privacy</a>, sezione «Per quanto tempo conserviamo i dati».</p>""",
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
<p>Le risposte possono essere incomplete o sbagliate. Usale come informazione generale e controlla ogni cosa importante con il tuo veterinario. Se una risposta non ti convince, tocca «Non mi ha aiutato»: l'assistente riprova con più attenzione. Per segnalarci un errore scrivici da Impostazioni → Contattaci.</p>

<h2 id="emergenze">Se il tuo animale sta male</h2>
<div class="callout">
<p><strong>Quokka non gestisce le urgenze: non aspettare la risposta dell'app.</strong> Chiama subito il tuo veterinario o la clinica veterinaria più vicina. Non rimandare una visita per qualcosa che ha detto l'app.</p>
</div>

<h2 id="dati">Che fine fanno le tue domande</h2>
<p>Per rispondere, il testo delle tue domande viene inviato a un fornitore esterno di intelligenza artificiale. Prima, il sistema toglie in automatico alcuni dati personali riconoscibili, come e-mail e telefono. Non può riconoscerli tutti: evita di scrivere dati personali tuoi o di altri. Se alleghi un documento PDF a un messaggio, anche il suo testo, ripulito allo stesso modo, viene inviato al fornitore per essere letto; le foto non vengono lette da nessun fornitore.</p>
<p>La chat legge la cartella clinica di un tuo animale solo se lo consenti, animale per animale, e puoi revocare il consenso quando vuoi. Il dettaglio è nell'<a href="/it/privacy/">informativa sulla privacy</a>, nella sezione «Come usiamo l'intelligenza artificiale».</p>""",
    },
]

NOT_FOUND = {
    "title": "Pagina non trovata",
    "body": """<h1>Pagina non trovata</h1>
<p class="lead">La pagina che cerchi non esiste o è stata spostata.</p>
<p><a href="/it/">Torna alla home</a>.</p>""",
}
