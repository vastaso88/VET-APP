"""Does the fixed clarifying question fit what the owner wrote? (synthetic
users 2026-11-07, P3 and P4)

The clarifying questions are one per category: "did the heavy breathing
start after a run?" was asked about a cough at night and about a degu that
fell from a hand; "how many hours without urinating?" about a cat that
urinates everywhere. Before a question is asked, three checks:

* a grave picture (blue gums, collapse, open-mouth breathing while lying
  still, heavy bleeding, a fall) gets the action first, no question;
* a question that contradicts the message is skipped: the ordinary answer,
  with its own rule on when to see the vet, serves better;
* a past event ("l'incidente di anni fa", "nessun sangue") is not a current
  emergency, and a reply that denies the emergency closes the question.
"""

from __future__ import annotations

import re

from packages.core.domain.safety.emergency_patterns import normalize_for_matching
from packages.core.domain.safety.first_aid import HOUSE_SOILING

_GRAVE = re.compile(
    r"\b(?:gengive (?:blu|bianche|grigie|viola|violacee|pallide)|lingua (?:blu|viola|violacea)|"
    r"bocca (?:aperta e )?blu|labbra blu|collass\w*|svenut\w*|svien\w*|priv[oa] di sensi|"
    r"incoscient\w*|non si muove(?: piu)?|immobile|non risponde|non reagisce|a terra e non|"
    r"sangue (?:molto|tanto|a fiotti|che non si ferma)|sanguina (?:molto|tanto|forte)|"
    r"emorragi\w*|perde molto sangue|cadut[oa] (?:da|dal|dalla|giu)|investit[oa]|schiacciat[oa]|"
    r"blue gums|white gums|pale gums|blue tongue|collapsed|unconscious|not moving|"
    r"lying still|bleeding (?:heavily|a lot)|won't stop bleeding|fell from|hit by a car|"
    r"encias (?:azules|blancas|palidas)|lengua (?:azul|morada)|colaps\w*|inconsciente|"
    r"no se mueve|sangra mucho|se cayo de|atropellad[oa]|"
    r"blaues zahnfleisch|weisses zahnfleisch|blasses zahnfleisch|blaue zunge|kollabiert|"
    r"bewusstlos|bewegt sich nicht|blutet stark|ist gefallen|angefahren|"
    r"gencives (?:bleues|blanches|pales)|langue (?:bleue|violette)|effondr\w*|inconscient|"
    r"ne bouge plus|saigne beaucoup|est tombe|renverse par|"
    # Synthetic users round 2 (2026-11-16): the answer to the clarifying
    # question was already in the message, and the owner got questions
    # before any help. Bleeding that pressure does not stop:
    r"sanguina parecchio|(?:sangue|sanguina\w*)[^.?!]{0,40}non si ferma|continua a sanguinare|"
    r"sangue che cola|"
    r"won't stop|doesn't stop bleeding|keeps bleeding|no para de sangrar|hort nicht auf zu "
    r"bluten|blutet weiter|ne s'arrete pas de saigner|saigne toujours|"
    # straining with nothing or a few drops (a blocked urinary tract):
    r"non riesce a fare (?:la )?pipi|non riesce a urinare|"
    r"(?:lettiera|pipi)[^.?!]{0,60}non esce (?:niente|nulla)|"
    r"poche gocce di pipi|fa (?:solo )?poche gocce|poche gocce di urin\w*|"
    # round 3 eval: "fa forza nella lettiera, poche gocce di urina" got questions
    r"fa forza (?:in|nella) lettiera|si sforza (?:in|nella) lettiera|"
    r"(?:\d+|piu di \w+) ore che non (?:fa|ha fatto) (?:la )?pipi|non fa pipi da|"
    r"can't pee|cannot pee|straining to (?:pee|urinate)|(?:pees|peeing) only a few drops|"
    r"a few drops of (?:urine|pee)|no puede orinar|solo unas gotas de orina|"
    r"kann nicht (?:pinkeln|urinieren)|nur ein paar tropfen urin|n'arrive pas a uriner|"
    r"quelques gouttes d'urine|"
    # a seizure that is happening or has just happened:
    r"convuls\w*|crisi epilettic\w*|attacco epilettic\w*|seizure\w*|having a fit|"
    r"convulsion\w*|krampfanfall|krampft|anfall|crise d'epilepsie|"
    # breathing with the mouth open, or a whistling breath, at rest:
    r"(?:respira|tiene la bocca|con la bocca) (?:con la bocca )?aperta|respiro (?:che )?fischi\w*|"
    r"rantol\w*|breathing with (?:its|his|her|the) mouth open|wheez\w*|"
    r"respira con la boca abierta|silba al respirar|atmet mit offenem maul|pfeift beim atmen|"
    r"respire la bouche ouverte|siffle en respirant)\b"
)


def describes_a_grave_picture(message: str) -> bool:
    """Action first, questions later."""
    return bool(_GRAVE.search(normalize_for_matching(message)))


_POLYURIA = re.compile(
    r"\b(?:fa (?:tanta|molta|troppa) pipi|pipi dappertutto|urina (?:molto|tanto|spesso|troppo|"
    r"dappertutto)|beve (?:tanto|tantissimo|molto|troppo)|pees? a lot|pees everywhere|"
    r"drinks a lot|urinates a lot|orina mucho|bebe mucho|pinkelt viel|trinkt viel|"
    r"urine beaucoup|boit beaucoup)\b"
)
_BREATHING = re.compile(
    r"\b(?:respir\w*|fiato|affann\w*|ansim\w*|bocca aperta|becco aperto|dispne\w*|boccheggi\w*|"
    r"breath\w*|panting|gasping|open mouth|respira\w*|jadea\w*|boca abierta|atm\w*|hechelt|"
    r"maul offen|respire|haletement|halete|bouche ouverte)\b"
)
_COUGH = re.compile(r"\b(?:toss\w*|cough\w*|tos\b|tose|huste\w*|husten|tousse\w*|toux)\b")
_BLOOD_OR_WOUND = re.compile(
    r"\b(?:sangu\w*|sanguin\w*|emorrag\w*|ferit\w*|tagli\w*|squarci\w*|morso|morsicat\w*|"
    r"blood\w*|bleed\w*|wound\w*|cut|cuts|gash\w*|bitten|sangr\w*|herid\w*|cort[ea]\w*|"
    r"blut\w*|wunde\w*|verletz\w*|schnitt\w*|gebissen|sang|saign\w*|plaie\w*|blessure\w*|"
    r"coupure\w*|mordu\w*)\b"
)
_NO_BLEEDING = re.compile(
    r"\b(?:nessun sangue|niente sangue|non sanguina|non c'e sangue|senza sangue|non esce sangue|"
    r"no blood|not bleeding|isn't bleeding|no sangra|sin sangre|kein blut|blutet nicht|"
    r"pas de sang|ne saigne pas)\b"
)


def clarifying_question_fits(category: str | None, message: str) -> bool:
    """False when the category's fixed question would contradict the
    message (a question about not urinating to an owner who says the cat
    urinates everywhere; about heavy breathing to a cough with no breathing
    words; about the bleeding to an owner who says there is none)."""
    text = normalize_for_matching(message)
    # Urinating a lot, or outside the usual place in any language ("la gata
    # orina fuera del arenero", Haiku round 2026-11-07): the animal urinates.
    if category == "urinary" and (_POLYURIA.search(text) or HOUSE_SOILING.search(text)):
        return False
    # Synthetic users round 3 (2026-11-16): the question on the breathing went to
    # "un telo sulla gabbia: la soffoco?" and to a canary with a sneeze that eats and
    # sings, and the one on the bleeding to a gecko dropping its tail with no blood
    # written. Each question needs its own sign in the owner's words.
    if category == "respiratory" and not _BREATHING.search(text):
        return False
    if category == "bleeding_trauma" and (
        _NO_BLEEDING.search(text) or not _BLOOD_OR_WOUND.search(text)
    ):
        return False
    return True


_PAST = re.compile(
    r"\b(?:anni fa|mesi fa|settimane fa|l'anno scorso|anno scorso|tempo fa|da cucciol[oa]|"
    r"da piccol[oa]|quando era (?:piccol[oa]|cucciol[oa]|giovane)|in passato|"
    r"years ago|months ago|weeks ago|last year|a while ago|when (?:he|she|it) was (?:a puppy|"
    r"a kitten|young|little)|in the past|hace (?:anos|meses|semanas)|el ano pasado|de cachorro|"
    r"vor (?:jahren|monaten|wochen)|letztes jahr|als welpe|als er klein war|als sie klein war|"
    r"il y a (?:des annees|des mois|des semaines)|l'annee derniere|"
    r"quand il etait (?:petit|chiot))\b"
)
_NOW = re.compile(
    r"\b(?:adesso|ora|in questo momento|appena|da stamattina|da ieri|oggi|stanotte|right now|"
    r"just now|today|this morning|since yesterday|ahora|hoy|recien|gerade|jetzt|heute|"
    r"maintenant|a l'instant|aujourd'hui)\b"
    r"(?! (?:sta bene|va bene|e tranquill\w*|e a posto|is fine|is ok|esta bien|geht es gut|"
    r"va bien))"
)


def is_a_past_event(message: str) -> bool:
    """The owner tells of something that happened long ago, with no sign
    that it is happening now."""
    text = normalize_for_matching(message)
    return bool(_PAST.search(text)) and not _NOW.search(text)


_DENIES = re.compile(
    r"\b(?:nessun sangue|niente sangue|non sanguina|non c'e sangue|si e fermat[oa]|e passat[oa]|"
    r"sta bene (?:adesso|ora)|non e urgente|non e successo (?:ora|adesso|oggi)|era (?:anni|"
    r"mesi|tempo) fa|parlavo (?:di|dell'|del) \w+ (?:di )?(?:anni|mesi|tempo) fa|falso allarme|"
    r"no blood|not bleeding|it stopped|has stopped|is fine now|not urgent|not now|years ago|"
    r"false alarm|no sangra|ya paro|esta bien ahora|no es urgente|hace anos|kein blut|"
    r"blutet nicht|hat aufgehort|geht es gut|nicht dringend|vor jahren|pas de sang|"
    r"ne saigne pas|s'est arrete|va bien maintenant|pas urgent|il y a des annees)\b"
)


def denies_the_emergency(reply: str) -> bool:
    """A reply to the clarifying question that says there is no emergency
    (or that it was long ago): the question is closed, the reply is read
    as an ordinary message."""
    return bool(_DENIES.search(normalize_for_matching(reply)))


_ON_A_PERSON = re.compile(
    r"\b(?:(?:il graffio|la ferita|il morso|il taglio|il sangue) (?:e|era) (?:sul|sulla|su|a|al|"
    r"alla) (?:bambin[oa]|bimb[oa]|mi[oa] figli[oa]|me|mia moglie|mio marito|mia madre|mio "
    r"padre|una persona|un bambino|me stess[oa])|(?:sul|sulla|al|alla|a) (?:bambin[oa]|bimb[oa])"
    r"[,!]|ha (?:morso|graffiato) (?:me|mio figlio|mia figlia|il bambino|la bambina|mia moglie|"
    r"mio marito)|mi ha (?:morso|graffiato)|"
    r"(?:the scratch|the wound|the bite|the cut) is on (?:the child|my son|my daughter|me|the "
    r"baby|my wife|my husband)|(?:bit|scratched) (?:me|my son|my daughter|the child|the baby)|"
    r"(?:el aranazo|la herida|la mordida) (?:es|esta) en (?:el nino|la nina|mi hijo|mi hija|mi)|"
    r"me (?:mordio|arano)|(?:der kratzer|die wunde|der biss) ist (?:am|beim|an) (?:kind|mir|"
    r"meinem sohn|meiner tochter)|hat (?:mich|mein kind|meinen sohn|meine tochter) (?:gebissen|"
    r"gekratzt)|(?:la griffure|la blessure|la morsure) est sur (?:l'enfant|mon fils|ma fille|moi)|"
    r"m'a (?:mordu|griffe))\b"
)


def injury_is_on_a_person(message: str) -> bool:
    """The wound is on a child or on the owner, not on the animal."""
    return bool(_ON_A_PERSON.search(normalize_for_matching(message)))


PERSON_INJURY_TEXTS: dict[str, str] = {
    "it": (
        "Capito: la ferita è su una persona, non su {name}. Allora serve il medico, non il "
        "veterinario. Lava subito con acqua corrente e sapone per qualche minuto e premi con "
        "un panno pulito; per un morso, o un graffio vicino all'occhio, fallo vedere oggi al "
        "pediatra, al medico o al pronto soccorso (i morsi di cane e gatto si infettano "
        "facilmente e può servire l'antitetanica). Per {name}: nessuna punizione, lascialo "
        "tranquillo in un'altra stanza. Quando vuoi, ti spiego perché è successo e come "
        "evitare che si ripeta."
    ),
    "en": (
        "Understood: the wound is on a person, not on {name}. Then it is a doctor's matter, "
        "not the vet's. Wash right away under running water with soap for a few minutes and "
        "press with a clean cloth; for a bite, or a scratch near the eye, have it seen today "
        "by the paediatrician, the doctor or the emergency room (dog and cat bites get "
        "infected easily and a tetanus shot may be needed). For {name}: no punishment, leave "
        "them quiet in another room. When you want, I will explain why it happened and how "
        "to keep it from happening again."
    ),
    "es": (
        "Entendido: la herida está en una persona, no en {name}. Entonces es cosa del médico, "
        "no del veterinario. Lava enseguida con agua corriente y jabón durante unos minutos y "
        "aprieta con un paño limpio; si es un mordisco, o un arañazo cerca del ojo, que lo "
        "vea hoy el pediatra, el médico o urgencias (las mordeduras de perro y gato se "
        "infectan con facilidad y puede hacer falta la antitetánica). Para {name}: nada de "
        "castigos, déjalo tranquilo en otra habitación. Cuando quieras te explico por qué ha "
        "pasado y cómo evitar que se repita."
    ),
    "de": (
        "Verstanden: Die Wunde ist an einem Menschen, nicht an {name}. Dann ist das eine Sache "
        "für den Arzt, nicht für die Tierarztpraxis. Sofort einige Minuten unter fließendem "
        "Wasser mit Seife waschen und mit einem sauberen Tuch draufdrücken; bei einem Biss oder "
        "einem Kratzer nahe am Auge heute vom Kinderarzt, Hausarzt oder in der Notaufnahme "
        "anschauen lassen (Hunde- und Katzenbisse entzünden sich leicht, und eine Tetanusimpfung "
        "kann nötig sein). Für {name}: keine Strafe, in Ruhe in einem anderen Zimmer lassen. Wenn "
        "Sie möchten, erkläre ich Ihnen, warum es passiert ist und wie Sie es künftig vermeiden."
    ),
    "fr": (
        "Compris : la blessure est sur une personne, pas sur {name}. C'est donc l'affaire du "
        "médecin, pas du vétérinaire. Lavez tout de suite à l'eau courante et au savon "
        "pendant quelques minutes et appuyez avec un linge propre ; pour une morsure, ou une "
        "griffure près de l'œil, faites voir aujourd'hui par le pédiatre, le médecin ou les "
        "urgences (les morsures de chien et de chat s'infectent facilement et un rappel "
        "antitétanique peut être nécessaire). Pour {name} : aucune punition, laissez-le "
        "tranquille dans une autre pièce. Quand vous voudrez, je vous expliquerai pourquoi "
        "c'est arrivé et comment éviter que cela se reproduise."
    ),
}
