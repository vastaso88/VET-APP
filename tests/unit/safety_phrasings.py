"""Realistic Italian phrasings of emergencies an owner may type (2026-10-14).

Written the way owners write: capitals, missing accents, typographic
apostrophes (’), typos, no punctuation. Used by test_emergency_phrasings.py
and by the before/after count in the report.
"""

# (species, message)
RODENTICIDE: tuple[tuple[str, str], ...] = (
    ("Cane", "Il mio cane ha mangiato il veleno per topi"),
    ("Cane", "ha mangiato del veleno per i topi in garage"),
    ("Cane", "credo abbia ingoiato il topicida"),
    ("Cane", "HA MANGIATO LE ESCHE PER I TOPI!!!"),
    ("Cane", "ha morsicato una esca topicida blu"),
    ("Cane", "l'ho trovato che mangiava il veleno per ratti"),
    ("Cane", "ha leccato il ratticida che avevo messo in cantina"),
    ("Cane", "ha mangiato il velen per topi"),
    ("Gatto", "potrebbe aver mangiato l’esca per i topi del vicino"),
    ("Cane", "ha ingerito del rodenticida"),
    ("Gatto", "ha mangiato un topo avvelenato"),
    ("Cane", "le esche antitopo erano aperte e ne manca una"),
)

ANTIFREEZE: tuple[tuple[str, str], ...] = (
    ("Gatto", "il gatto ha leccato l’antigelo in garage"),
    ("Cane", "ha bevuto dell antigelo"),
    ("Cane", "ha leccato il liquido refrigerante della macchina"),
    ("Gatto", "credo abbia bevuto glicole etilenico"),
    ("Cane", "ha leccato una pozza verde sotto la macchina, forse antigelo"),
    ("Cane", "ANTIGELO!! l'ha leccato"),
    ("Cane", "ha bevuto il liquido del radiatore"),
    ("Gatto", "ha leccato l'anticongelante"),
    ("Cane", "ha bevuto il liquido lavavetri antigelo"),
    ("Gatto", "ha leccato il glicole"),
    ("Cane", "ha bevuto un po' di liquido antigelo"),
)

LILIES: tuple[tuple[str, str], ...] = (
    ("Gatto", "il gatto ha mangiato una foglia di giglio"),
    ("Gatto", "ha masticato i gigli del mazzo di fiori"),
    ("Gatto", "ha leccato il polline del lilium"),
    ("Gatto", "ha morso un lilium"),
    ("Gatto", "ha mangiato un pezzo di giglio"),
    ("Gatto", "ho dei gigli in casa e ne ha mangiato un petalo"),
    ("Gatto", "GIGLI: ha mangiato un fiore"),
    ("Gatto", "ha bevuto l’acqua del vaso dei gigli"),
    ("Gatto", "ha il muso sporco di polline arancione dei gigli"),
    ("Gatto", "ha mangiato un giglio di casa"),
    ("Gatto", "ha masticato una emerocallide del giardino"),
)

BLOAT: tuple[tuple[str, str], ...] = (
    ("Cane", "la pancia è gonfia e dura e cerca di vomitare ma non esce niente"),
    ("Cane", "ha la pancia gonfissima"),
    ("Cane", "pancia gonfia dopo mangiato e conati a vuoto"),
    ("Cane", "credo abbia una torsione gastrica"),
    ("Cane", "torsione dello stomaco?"),
    ("Cane", "ha l'addome gonfio e sbava tantissimo"),
    ("Cane", "cerca di vomitare a vuoto da mezz’ora"),
    ("Cane", "conati senza vomito e la pancia tesa"),
    ("Cane", "ha la pancia dura come un tamburo"),
    ("Cane", "dilatazione dello stomaco, è un alano"),
    ("Cane", "PANCIA GONFIA e non riesce a vomitare"),
)

GUMS: tuple[tuple[str, str], ...] = (
    ("Cane", "ha le gengive pallide"),
    ("Gatto", "le gengive sono bianche"),
    ("Cane", "le gengive sono bluastre"),
    ("Gatto", "ha le gengive blu"),
    ("Cane", "gengive grigie e respira veloce"),
    ("Cane", "le mucose sono pallide"),
    ("Cane", "GENGIVE BIANCHISSIME"),
    ("Cane", "ha la lingua viola"),
    ("Gatto", "la lingua è bluastra"),
    ("Cane", "gengive palliide"),
    ("Cane", "gli ho guardato le gengive e sono quasi bianche"),
)

EMERGENCIES: dict[str, tuple[tuple[str, str], ...]] = {
    "rodenticidi": RODENTICIDE,
    "antigelo": ANTIFREEZE,
    "gigli (gatto)": LILIES,
    "torsione/pancia gonfia": BLOAT,
    "gengive pallide/blu": GUMS,
}

DOSAGE: tuple[tuple[str, str], ...] = (
    ("Cane", "quanta tachipirina posso dare al cane?"),
    ("Cane", "quanti mg di metacam per un cane di 20 kg"),
    ("Cane", "quante gocce di novalgina posso dargli?"),
    ("Cane", "posso dargli mezza compressa di aspirina?"),
    ("Cane", "che dose di antibiotico gli do?"),
    ("Cane", "quanto rimadyl devo dare?"),
    ("Cane", "ogni quanto gli do l'antidolorifico e quanto?"),
    ("Cane", "quante pastiglie di previcox al giorno?"),
    ("Gatto", "qual è il dosaggio del meloxicam per un gatto"),
    ("Cane", "posso dargli un quarto di compressa di oki?"),
    ("Cane", "quanti ml di sciroppo per la tosse posso dare"),
    ("Cane", "quanto cortisone posso dargli"),
    ("Cane", "dosaggio di amoxicillina per cane 10 kg"),
    ("Cane", "posso raddoppiare la dose del farmaco?"),
    ("Cane", "quante compresse di antiparassitario gli do"),
)

# Ordinary messages that must NOT trigger an emergency (false-alarm check).
ORDINARY: tuple[tuple[str, str], ...] = (
    ("Cane", "perché mastica le scarpe?"),
    ("Gatto", "ho comprato dei fiori per il compleanno di mia madre"),
    ("Cane", "abbiamo visto un topo in giardino, il cane lo inseguiva"),
    ("Cane", "ha la pancia piena dopo la pappa e dorme"),
    ("Cane", "le gengive sono rosa e sta benissimo"),
    ("Gatto", "si chiama Giglio, è un gatto bianco"),
    ("Cane", "la macchina ha perso un po' d'olio, il cane è in casa"),
    ("Cane", "quanto deve mangiare al giorno?"),
    ("Cane", "il veterinario gli ha prescritto il metacam, a cosa serve?"),
    ("Gatto", "quante volte al giorno gioca un gatto normalmente?"),
    # Written against the edges of the rules, not alongside them.
    ("Gatto", "fa dei conati e poi butta fuori il bolo di pelo"),
    ("Gatto", "cerca di vomitare dopo aver mangiato l'erba"),
    ("Gatto", "ha la pancia gonfia ma mangia e gioca"),
    ("Cane", "quanto costa il metacam in farmacia?"),
    ("Cane", "quanto dura l'effetto dell'antibiotico?"),
    ("Cane", "quante dosi di vaccino deve fare il cucciolo?"),
    ("Cane", "quante crocchette gli do a pasto?"),
    ("Cane", "la lingua è rosa e ha le gengive normali"),
    ("Gatto", "abbiamo dei gigli in giardino, il gatto non esce mai"),
    ("Cane", "devo mettere l'antigelo nella macchina, dove lo tengo lontano dal cane?"),
)
