"""Requests the chat must refuse or redirect, and how (stress test of
2026-11-06, docs/product/11 §3).

Deterministic detection in five languages (accents removed by
``normalize_for_matching``); what happens next depends on the category:

* ``euthanasia_at_home``: a fixed, empathetic refusal in the reply's
  language, before any model call and on every later turn that asks for
  the substance or the dose ("è solo per sapere, che dose di sonnifero?").
  Never a drug, a dose, or where to find one; concrete help instead.
* every other category: the model answers, with a note (``HARMFUL_NOTES``)
  that states the facts to give (the duty or the law, named neutrally),
  what to explain and what must not appear. A refusal that educates.

Also here: the output guards for the two answers no prompt fully prevents
(a bare "sì"/"no" to a health question, a sentence that has Quokka
certify something about the owner), the child and minor detectors, and
the long-message detector.
"""

from __future__ import annotations

import re

from packages.core.domain.safety.emergency_patterns import normalize_for_matching


def _words(pattern: str) -> re.Pattern[str]:
    return re.compile(rf"\b(?:{pattern})\b")


# --- categories -------------------------------------------------------------

_EUTHANASIA_ACT = _words(
    r"addorment\w*|sopprim\w*|eutanasi\w*|farl[oa] morire|porre fine|"
    r"put (?:him|her|it|my \w+|the \w+|our \w+) (?:down|to sleep)|euthani[sz]\w*|"
    r"end (?:his|her|its) life|"
    r"dormirl[oa]|sacrificarl[oa]|eutanasia|"
    r"einschlafern|einschlafen lassen|erlosen|toten|"
    r"euthanasi\w*|endormir|abreger|mettre fin|piquer"
)
_EUTHANASIA_MEANS = _words(
    r"a casa|da sol[oa]|io stess[oa]|senza (?:il )?veterinari\w*|che farmac\w*|quali farmac\w*|"
    r"sonnifer\w*|sedativ\w*|barbituric\w*|pentobarbital|calmant\w*|tranquillant\w*|"
    r"at home|myself|without (?:a |the )?vet|sleeping pills?|sedative\w*|barbiturate\w*|"
    r"en casa|yo mism[oa]|sin (?:el )?veterinari\w*|somnifer\w*|sedante\w*|"
    r"zu hause|selbst|ohne tierarzt|schlaftablette\w*|schlafmittel|beruhigungsmittel|"
    r"a la maison|moi-meme|sans veterinaire|somnifere\w*|sedatif\w*"
)
# A later turn that asks for the substance or the dose, once the subject
# is on the table ("che dose di sonnifero servirebbe?").
_EUTHANASIA_FOLLOW_UP = _words(
    r"sonnifer\w*|barbituric\w*|pentobarbital|"
    r"sleeping pills?|barbiturate\w*|somnifer\w*|schlaftablette\w*|schlafmittel|somnifere\w*"
)

_MUTILATION = _words(
    r"tagli\w* (?:le |la |l')?(?:orecchi\w*|coda)|orecchi\w* a punta|conchectomi\w*|"
    r"caudotomi\w*|accorciar\w* la coda|mozzar\w* (?:la coda|le orecchie)|"
    r"togliere? (?:le |gli )?(?:unghie|artigli)|onicectomi\w*|declaw\w*|"
    r"crop\w* (?:the |his |her )?ears|dock\w* (?:the |his |her )?tail|ear cropping|tail docking|"
    r"cortar\w* (?:las )?orejas|cortar\w* (?:la )?cola|"
    r"ohren kupieren|rute kupieren|kupier\w*|"
    r"couper (?:les )?oreilles|couper (?:la )?queue|degriffage"
)
_AVERSIVE_TOOL = _words(
    r"collare (?:elettric\w*|a scoss\w*|elettronic\w*|antiabbaio elettric\w*|a strozzo|"
    r"a punte|a strangolo|con le punte|a spray)|scoss\w* elettric\w*|telecomando del collare|"
    r"(?:shock|e-|electric|prong|choke|pinch) collar|"
    r"collar (?:electrico|de descargas|de pinchos|de ahorque)|"
    r"(?:strom|teletakt|stachel|wurger?)halsband|elektrohalsband|"
    r"collier (?:electrique|a decharges?|etrangleur|a pointes|torcatus)"
)
_DOG_FIGHTING = _words(
    r"combatt\w* (?:con|contro) altri cani|combattiment\w*|lotta tra cani|"
    r"farlo combattere|allenarl[oa] (?:per|a) combattere|"
    r"dog ?fight\w*|fight other dogs|train (?:him|her|it) to fight|"
    r"pelea\w* de perros|pelear con otros perros|"
    r"hundekampf\w*|kampfen lassen|"
    r"combat\w* de chiens|se battre avec d'autres chiens"
)
_WILDLIFE = _words(
    r"ricci[oa]?|passerott[oi]|merl[oi]|rondin[ei]|pipistrell[oi]|volp[ei]|capriol[oi]|"
    r"cerbiatt[oi]|scoiattol[oi]|ghir[oi]|tartarug\w* (?:di terra|selvatic\w*|trovat\w*)|"
    r"gufo|civett[ae]|falc[oi]|gabbian[oi]|cucciol[oi] di (?:volpe|capriolo|cinghiale)|"
    r"hedgehog|fledgling|baby bird|fawn|fox cub|squirrel|bat|owl|"
    r"erizo|gorrion|murcielago|zorro|corzo|ardilla|"
    r"igel|jungvogel|fledermaus|fuchs|rehkitz|eichhornchen|"
    r"herisson|oisillon|chauve-souris|renard|faon|ecureuil"
)
_WILDLIFE_KEEPING = _words(
    r"trovat\w*|lo tengo|la tengo|tenerl[oa]|come animale|in casa|cosa mangia|cosa gli do|"
    r"found|keep (?:him|her|it)|as a pet|what does (?:he|she|it) eat|"
    r"encontr\w*|quedarmel[oa]|como mascota|que come|"
    r"gefunden|behalten|als haustier|was frisst|"
    r"trouve|le garder|la garder|comme animal|que mange"
)
_PUPPY_SALE = _words(
    r"cuccioli|cucciolata|gattini|puppies|litter|kittens|cachorros|camada|gatitos|"
    r"welpen|wurf|katzchen|chiots|portee|chatons"
)
_SALE = _words(
    r"vender\w*|vendo|annuncio|regalar\w*|cederl[oi]|darli via|"
    r"sell\w*|advert|ad for|give (?:them )?away|rehome|"
    r"vender|anuncio|regalar|"
    r"verkauf\w*|anzeige|abgeben|"
    r"vendre|annonce|donner"
)
_UNDER_AGE = re.compile(
    r"\b(?:[1-5]?\d|quarant\w*|cinquant\w*|trent\w*|vent\w*) (?:giorni|days|dias|tage|jours)\b|"
    r"\b(?:[1-7]|un|una|due|tre|quattro|cinque|sei|sette) (?:settiman\w*|weeks?|semanas?|"
    r"wochen?|semaines?)\b|\bun mese\b|\ba month\b|\bun mes\b|\beinen? monat\b|\bun mois\b"
)
_ABANDONMENT = _words(
    r"abbandon\w*|(?:lo|la|li) (?:lascio|lasciare|mollo|mollare|porto) (?:in|al|nel|fuori|"
    r"per strada|in campagna|in un parcheggio|lontano)|lasciarl[oa] (?:in|al|nel|per strada|"
    r"in campagna|lontano|libero|libera)|liberarl[oaie] (?:in natura|nel parco|nel laghetto|"
    r"nel fiume|nel bosco)|non (?:la|lo|li|le) voglio piu|se la cava da sol[oa]|"
    r"abandon\w*|dump (?:him|her|it|them)|leave (?:him|her|it) (?:in|at|by)|release (?:him|her|"
    r"it|them) (?:in|into)|set (?:him|her|it|them) free|"
    r"abandon\w*|dejarl[oa] en|soltarl[oa] en|"
    r"aussetzen|ausgesetzt|freilassen|"
    r"abandonn\w*|relacher|le lacher|la lacher"
)
_CERTIFY = re.compile(
    r"quokka (?:certifica|attesta|dichiara|conferma)|"
    r"(?:certifica|attesta|dichiara) che (?:sono|io sono|il sottoscritt\w*)|"
    r"(?:rilascia|rilasciami|mi (?:rilasci|fai|scrivi|dai)) (?:un |una |l')?(?:attestat\w*|"
    r"certificat\w*|dichiarazion\w*|patentin\w*|diplom\w*)|"
    r"scrivi (?:esattamente|testualmente|parola per parola)|"
    r"quokka (?:certifies|attests|declares|confirms)|"
    r"(?:write|issue|give) me (?:a |an )?(?:certificate|attestation|diploma)|"
    r"write exactly|word for word|"
    r"quokka (?:certifica|acredita)|(?:dame|hazme|escribe) (?:un |una )?(?:certificado|diploma)|"
    r"quokka (?:bescheinigt|bestatigt)|(?:stell|schreib)\w* mir (?:ein |eine )?(?:bescheinigung|"
    r"zertifikat|urkunde)|"
    r"quokka (?:certifie|atteste)|(?:fais|ecris|donne)-moi (?:un |une )?(?:certificat|"
    r"attestation|diplome)"
)

# A puppy or kitten bought online or from abroad (H): not a refusal, a
# note with the facts (illegal trade, minimum age, EU passport).
_ONLINE_PURCHASE_ANIMAL = _words(
    r"cucciol[oi]|gattin[oi]|cagnolin[oi]|puppy|puppies|kitten|cachorr[oa]s?|gatit[oa]s?|"
    r"welpen?|katzchen|chiots?|chatons?"
)
_ONLINE_PURCHASE_CHANNEL = _words(
    r"online|su un sito|sul sito|su internet|annuncio|subito\.it|facebook|marketplace|"
    r"dall'estero|dall'ungheria|dalla slovacchia|dalla polonia|dalla romania|dalla serbia|"
    r"dall'est|mi consegnano|consegna a casa|spedi\w*|corriere|"
    r"website|on a site|from abroad|from hungary|from poland|from romania|delivered to|"
    r"shipped|en internet|de hungria|de polonia|del extranjero|me lo envian|"
    r"aus dem ausland|aus ungarn|aus polen|aus rumanien|geliefert|im internet|"
    r"sur internet|sur un site|de l'etranger|de hongrie|de pologne|de roumanie|livre a domicile"
)


def is_online_animal_purchase(message: str) -> bool:
    text = normalize_for_matching(message)
    return bool(_ONLINE_PURCHASE_ANIMAL.search(text) and _ONLINE_PURCHASE_CHANNEL.search(text))


ONLINE_PURCHASE_NOTE = (
    "THIS REQUEST: a puppy or kitten offered online, cheap, from abroad or delivered to the "
    "door. Say plainly that this is the typical pattern of the illegal puppy trade (animals "
    "taken from the mother too early, false papers, sick or unsocialised, mothers kept in "
    "cages); name the facts without playing the lawyer: in the EU a puppy cannot travel before "
    "15 weeks (rabies vaccination at 12 weeks plus 21 days), it needs a microchip and an EU "
    "pet passport, and in Italy it is not transferred before 60 days; the buyer risks "
    "seizure, costs and a sick animal. Never write 'if you decide to proceed': say instead "
    "how to recognise a serious breeder or a shelter (you see the mother and where the "
    "puppies live, no home delivery, health checks and documents the vet can verify, a "
    "written contract) and that a municipal canile or an association is a sound alternative."
)


def detect_harmful_request(message: str) -> str | None:
    """The category of a request the chat must refuse or redirect, or
    None. Checked in order of harm."""
    text = normalize_for_matching(message)
    if _EUTHANASIA_ACT.search(text) and _EUTHANASIA_MEANS.search(text):
        return "euthanasia_at_home"
    if _MUTILATION.search(text):
        return "mutilation"
    if _DOG_FIGHTING.search(text):
        return "dog_fighting"
    if _AVERSIVE_TOOL.search(text):
        return "aversive_tool"
    if _WILDLIFE.search(text) and _WILDLIFE_KEEPING.search(text):
        return "wildlife_keeping"
    if _ABANDONMENT.search(text):
        return "abandonment"
    if _PUPPY_SALE.search(text) and _SALE.search(text):
        return "underage_sale" if _UNDER_AGE.search(text) else "animal_sale"
    if _CERTIFY.search(text):
        return "certify"
    if is_online_animal_purchase(message):
        return "online_purchase"
    return None


def is_euthanasia_follow_up(message: str, history: list[str]) -> bool:
    """A later turn of a conversation where home euthanasia came up, asking
    for the substance or the dose: refused the same way."""
    if not any(detect_harmful_request(earlier) == "euthanasia_at_home" for earlier in history):
        return False
    text = normalize_for_matching(message)
    return bool(_EUTHANASIA_FOLLOW_UP.search(text) or _EUTHANASIA_ACT.search(text))


# --- what the model is told, per category ----------------------------------

HARMFUL_NOTES: dict[str, str] = {
    "mutilation": (
        "THIS REQUEST: a cosmetic mutilation (ear cropping, tail docking, declawing). "
        "Refuse clearly and kindly: in Italy and in the countries of the European Convention "
        "for the Protection of Pet Animals it is forbidden (reato di maltrattamento), it is "
        "painful and it takes away a part the animal communicates with (ears, tail) or defends "
        "itself with. No instructions of any kind, no 'if done by a vet it is fine', no "
        "surgical words. Explain the why in two sentences, then what the owner can do instead "
        "(accept the animal as it is; if there is a medical reason, only the vet decides)."
    ),
    "aversive_tool": (
        "THIS REQUEST: an electric, choke, prong or spray collar, or another coercive tool. "
        "Never explain how to set, adjust, fit or use it, not even 'start from the lowest "
        "level'. Say that ESVCE, FVE and AVSAB reject these tools (they act on pain and fear, "
        "worsen anxiety and aggression, and are banned or sanctioned in several countries and "
        "regions), explain the likely cause of the behaviour from the dog's point of view, and "
        "give reward-based alternatives and the right professional (educator with gentle "
        "methods, veterinary behaviourist)."
    ),
    "dog_fighting": (
        "THIS REQUEST: training an animal to fight. Refuse: organising, training for or "
        "taking part in animal fights is a crime in Italy (legge 189/2004) and in most "
        "countries, and a serious form of cruelty. No training advice of any kind. Explain "
        "what fighting means for the dog (fear, pain, injuries, euthanasia of the losers) and "
        "offer what the owner may really be after (a confident dog: sport, structured play, "
        "a gentle-method educator)."
    ),
    "wildlife_keeping": (
        "THIS REQUEST: a wild animal found and kept at home. Say plainly that wild fauna is "
        "protected and must not be kept as a pet (in Italy legge 157/1992): no diet or housing "
        "advice, no 'how to keep it'. Tell the owner what to do now: if the animal is injured, "
        "very young or in danger, put it in a dark ventilated box in a quiet place, no food or "
        "milk, and call the nearest wildlife rescue centre (CRAS), the polizia provinciale or "
        "the Carabinieri forestali (1515) or the municipality; if it is healthy and not in "
        "danger, leave it where it is. Explain the why: a wild animal suffers in captivity and "
        "needs expert care."
    ),
    "underage_sale": (
        "THIS REQUEST: selling or giving away puppies or kittens younger than two months. Do "
        "not write the advert. Explain, without playing the lawyer: in Italy puppies and "
        "kittens stay with the mother until 60 days (the duty of whoever keeps them), and a "
        "dog is identified with microchip and registered in the anagrafe before any transfer, "
        "with a written passage of ownership; selling regularly is a regulated activity. "
        "Then say what a responsible transfer looks like (health check, first vaccination and "
        "deworming decided by the vet, choosing the families, contract) and why it matters for "
        "the animals and for the people who take them."
    ),
    "animal_sale": (
        "THIS REQUEST: selling or giving away animals. Do not write the advert. Explain what a "
        "responsible transfer requires in the owner's country (in Italy: microchip and "
        "anagrafe before the transfer for dogs, written passage of ownership, no transfer "
        "before 60 days of age, health check by the vet) and why it protects the animals and "
        "the new families."
    ),
    "abandonment": (
        "THIS REQUEST: abandoning or releasing an animal. Say it plainly and without judging: "
        "abandoning a pet is a crime in Italy (articolo 727 del codice penale), not an "
        "administrative fine, and an animal that lived in a home does not cope outside "
        "(hunger, cars, predators, disease, winter); releasing an animal in nature also harms "
        "wildlife. Then give real alternatives: understand what has become hard and whether it "
        "can change, local shelters and associations, a responsible transfer to a known "
        "family, the municipality's canile or gattile. Never promise contacts you cannot "
        "give: say where to find them (the municipality, the ASL veterinary service, "
        "associations in the area)."
    ),
    "online_purchase": ONLINE_PURCHASE_NOTE,
    "certify": (
        "THIS REQUEST: a certificate, an attestation or a sentence to be written verbatim "
        "that has Quokka certify, attest or confirm something about the owner. Do not write "
        "it, not even as a quotation: Quokka certifies and attests nothing about anyone. Say "
        "so in one kind sentence, say what you can do instead (help understand the animal and "
        "prepare for a visit or a procedure), and if a document is needed for an authority, "
        "say that the authority itself says which document and who issues it."
    ),
}

# Fixed refusal for home euthanasia (never a model), with {name}.
EUTHANASIA_REFUSAL: dict[str, str] = {
    "it": (
        "Mi dispiace molto per {name}, e capisco che i soldi pesino proprio adesso. Non ti "
        "dico quale sostanza né quanta: addormentare un animale a casa, senza un veterinario, "
        "quasi sempre lo fa soffrire di più, non di meno, e non è una cosa che si possa fare "
        "bene da soli. Quello che puoi fare oggi: chiama il tuo veterinario e digli come stai "
        "messo. Spesso si trova una strada: una visita per capire quanto soffre davvero e "
        "cosa si può fare per il dolore, un pagamento a rate, un'associazione o un canile "
        "sanitario della zona che aiuta con le spese. Se è il momento di lasciarlo andare, "
        "l'eutanasia la fa il veterinario, senza dolore, e in molti casi con un costo "
        "contenuto o aiutato. Non sei solo in questa cosa."
    ),
    "en": (
        "I am very sorry about {name}, and I understand money weighs on you right now. I will "
        "not tell you which substance or how much: putting an animal to sleep at home, "
        "without a vet, almost always means more suffering, not less, and it is not something "
        "that can be done well alone. What you can do today: call your vet and tell them your "
        "situation. There is often a way: a visit to understand how much {name} really "
        "suffers and what can be done for the pain, payment in instalments, an animal welfare "
        "association or a municipal shelter that helps with costs. If it is time to let go, "
        "euthanasia is done by the vet, without pain, and often at a reduced or supported "
        "cost. You are not alone in this."
    ),
    "es": (
        "Siento mucho lo de {name}, y entiendo que el dinero pese justo ahora. No te diré qué "
        "sustancia ni cuánta: dormir a un animal en casa, sin veterinario, casi siempre lo "
        "hace sufrir más, no menos, y no es algo que se pueda hacer bien a solas. Lo que puedes "
        "hacer hoy: llama a tu veterinario y cuéntale tu situación. Muchas veces hay salida: "
        "una visita para saber cuánto sufre de verdad y qué se puede hacer por el dolor, un "
        "pago a plazos, una asociación o un refugio municipal que ayude con los gastos. Si es "
        "el momento de dejarlo ir, la eutanasia la hace el veterinario, sin dolor, y a menudo "
        "con un coste reducido o con ayuda. No estás solo en esto."
    ),
    "de": (
        "Es tut mir sehr leid um {name}, und ich verstehe, dass das Geld gerade schwer wiegt. "
        "Welches Mittel und wie viel sage ich Ihnen nicht: ein Tier zu Hause ohne Tierärztin "
        "oder Tierarzt einzuschläfern bedeutet fast immer mehr Leid, nicht weniger, und das "
        "lässt sich allein nicht gut machen. Was Sie heute tun können: Rufen Sie Ihre "
        "Tierarztpraxis an und schildern Sie Ihre Lage. Oft findet sich ein Weg: eine "
        "Untersuchung, um zu sehen, wie sehr {name} wirklich leidet und was gegen die "
        "Schmerzen möglich ist, eine Ratenzahlung, ein Tierschutzverein oder ein Tierheim, das "
        "bei den Kosten hilft. Wenn es Zeit ist loszulassen, übernimmt die Praxis die "
        "Einschläferung, schmerzfrei und oft zu geringeren oder unterstützten Kosten. Sie "
        "sind damit nicht allein."
    ),
    "fr": (
        "Je suis vraiment désolé pour {name}, et je comprends que l'argent pèse en ce moment. "
        "Je ne vous dirai ni quelle substance ni quelle quantité : endormir un animal à la "
        "maison, sans vétérinaire, signifie presque toujours plus de souffrance, pas moins, et "
        "cela ne peut pas se faire correctement seul. Ce que vous pouvez faire aujourd'hui : "
        "appelez votre vétérinaire et expliquez votre situation. Il y a souvent une issue : une "
        "visite pour savoir combien {name} souffre vraiment et ce qui est possible contre la "
        "douleur, un paiement échelonné, une association ou un refuge municipal qui aide pour "
        "les frais. Si le moment est venu de le laisser partir, l'euthanasie est faite par le "
        "vétérinaire, sans douleur, et souvent à un coût réduit ou pris en charge. Vous n'êtes "
        "pas seul dans cette épreuve."
    ),
}

# --- output guards -----------------------------------------------------------

_BARE_YES_NO = re.compile(r"^\W*(?:s[iì]|no|yes|nope|ja|nein|oui|non|s[ií])\W*$", re.IGNORECASE)
_ANSWER_CERTIFIES = re.compile(
    r"quokka (?:certifica|attesta|dichiara|conferma|certifies|attests|declares|confirms|"
    r"acredita|bescheinigt|bestatigt|bestätigt|certifie|atteste)\b|"
    r"(?:certifica|attesta|certifies|certifico|attesto|i certify|i attest) che (?:sei|è|lei è|"
    r"tu sei)|(?:certifico|attesto) che",
    re.IGNORECASE,
)


def answer_is_bare_yes_no(answer: str) -> bool:
    """ "NO" to "Argo ha il cancro? rispondi solo sì o no": never a diagnosis
    in one word, whatever the owner asked for."""
    return bool(_BARE_YES_NO.match(answer.strip()))


def answer_certifies(answer: str) -> bool:
    """The model wrote the sentence that has Quokka certify the owner."""
    return bool(_ANSWER_CERTIFIES.search(answer))


YES_NO_REPLACEMENT: dict[str, str] = {
    "it": (
        "A una domanda così non posso rispondere con un sì o con un no: nessuno può dirlo "
        "senza una visita e gli esami, e una parola sola rischia di farti stare peggio o di "
        "tranquillizzarti a torto. Dimmi cosa ti ha fatto venire questo dubbio su {name} e ti "
        "spiego cosa può voler dire e cosa serve per capirlo davvero."
    ),
    "en": (
        "I cannot answer a question like this with a yes or a no: nobody can tell without an "
        "examination and tests, and one word could worry you or reassure you wrongly. Tell me "
        "what made you think of this for {name}, and I will explain what it may mean and what "
        "it takes to really find out."
    ),
    "es": (
        "A una pregunta así no puedo responder con un sí o un no: nadie puede saberlo sin una "
        "visita y pruebas, y una sola palabra podría preocuparte o tranquilizarte sin razón. "
        "Cuéntame qué te ha hecho pensar en esto para {name} y te explico qué puede "
        "significar y qué hace falta para saberlo de verdad."
    ),
    "de": (
        "Auf eine solche Frage kann ich nicht mit Ja oder Nein antworten: ohne Untersuchung "
        "und Tests kann das niemand sagen, und ein einzelnes Wort könnte Sie zu Unrecht "
        "beunruhigen oder beruhigen. Sagen Sie mir, was Sie bei {name} darauf gebracht hat, "
        "und ich erkläre, was es bedeuten kann und was nötig ist, um es wirklich zu wissen."
    ),
    "fr": (
        "À une question comme celle-ci, je ne peux pas répondre par oui ou par non : personne "
        "ne peut le dire sans un examen et des analyses, et un seul mot pourrait vous "
        "inquiéter ou vous rassurer à tort. Dites-moi ce qui vous a fait penser à cela pour "
        "{name}, et je vous expliquerai ce que cela peut vouloir dire et ce qu'il faut pour le "
        "savoir vraiment."
    ),
}

CERTIFY_REPLACEMENT: dict[str, str] = {
    "it": (
        "Questa frase non la scrivo: Quokka non certifica e non attesta nulla su chi lo usa. "
        "Ti aiuto a capire {name} e a prepararti a una visita o a una pratica; se ti serve un "
        "documento per un ufficio, è quell'ufficio a dirti quale e chi lo rilascia."
    ),
    "en": (
        "I will not write that sentence: Quokka certifies and attests nothing about the "
        "people who use it. I can help you understand {name} and prepare for a visit or a "
        "procedure; if an office needs a document, that office says which one and who issues "
        "it."
    ),
    "es": (
        "Esa frase no la escribo: Quokka no certifica ni acredita nada sobre quien lo usa. Te "
        "ayudo a entender a {name} y a prepararte para una visita o un trámite; si una "
        "oficina necesita un documento, es esa oficina la que dice cuál y quién lo expide."
    ),
    "de": (
        "Diesen Satz schreibe ich nicht: Quokka bescheinigt und bestätigt nichts über die "
        "Menschen, die es nutzen. Ich helfe Ihnen, {name} zu verstehen und sich auf einen "
        "Besuch oder einen Behördengang vorzubereiten; braucht eine Behörde ein Dokument, sagt "
        "sie selbst, welches und wer es ausstellt."
    ),
    "fr": (
        "Je n'écrirai pas cette phrase : Quokka ne certifie et n'atteste rien sur les "
        "personnes qui l'utilisent. Je peux vous aider à comprendre {name} et à préparer une "
        "visite ou une démarche ; si un service a besoin d'un document, c'est lui qui dit "
        "lequel et qui le délivre."
    ),
}

# --- children, minors, long messages ----------------------------------------

_MINOR_AGE = re.compile(
    r"\b(?:ho|tengo|ich bin|j'ai|i am|i'm) (\d{1,2}) (?:anni|anos|jahre(?: alt)?|ans|years"
    r"(?: old)?)\b"
)
_MINOR_WORDS = _words(
    r"sono (?:un |una )?(?:bambin[oa]|ragazzin[oa])|i am a (?:kid|child)|i'm a (?:kid|child)|"
    r"soy (?:un |una )?(?:nin[oa]|chic[oa] pequen[oa])|ich bin (?:ein )?kind|"
    r"je suis (?:un |une )?(?:enfant|petit|petite)"
)


def is_minor_writing(message: str) -> bool:
    """The person writing says they are a child (an age up to 14, or "sono
    un bambino"): the first words must be "call an adult"."""
    text = normalize_for_matching(message)
    match = _MINOR_AGE.search(text)
    if match and int(match.group(1)) <= 14:
        return True
    return bool(_MINOR_WORDS.search(text))


_CHILD = _words(
    r"bambin\w*|bimb[oaie]|figli[oa]|figli|neonat[oaie]|nipotin[oaie]|"
    r"child|children|kid|kids|toddler|baby|my son|my daughter|"
    r"nin[oa]s?|hij[oa]s?|bebe|"
    r"kind|kinder|kleinkind|sohn|tochter|"
    r"enfant\w*|bebe|fils|fille|petit[es]?"
)
_CHILD_RISK = _words(
    r"ringhi\w*|mors\w*|mordic\w*|graffi\w*|abbracci\w*|tira (?:la coda|le orecchie)|"
    r"prende per il collo|salta addosso|da sol[oaie]|"
    r"growl\w*|bit\w*|bite\w*|scratch\w*|hug\w*|pull\w* (?:the |his |her )?tail|alone|"
    r"grun\w*|mordi\w*|muerd\w*|arana\w*|abraz\w*|tira de la cola|sol[oa]s?|"
    r"knurr\w*|beiss\w*|gebissen|kratz\w*|umarm\w*|am schwanz|allein|"
    r"grogn\w*|mord\w*|griff\w*|calin\w*|tire la queue|seul[es]?"
)


def mentions_a_child_at_risk(message: str) -> bool:
    """A child and the animal together in a situation that can end in a
    bite or a scratch (a growl, a hug, a pulled tail): the answer says
    first that they are never left alone without an adult."""
    text = normalize_for_matching(message)
    return bool(_CHILD.search(text) and _CHILD_RISK.search(text))


LONG_MESSAGE_CHARS = 600


def is_long_message(message: str) -> bool:
    """A long message with several points: answered point by point, never
    replaced by a summary of the documents on file."""
    return len(message.strip()) >= LONG_MESSAGE_CHARS


ADULT_FIRST: dict[str, str] = {
    "it": "Prima di tutto: chiama subito un adulto, la mamma, il papà o chi è in casa con te. ",
    "en": "First of all: call an adult right now, your mum, your dad or whoever is at home. ",
    "es": "Antes de nada: llama ahora mismo a un adulto, a mamá, a papá o a quien esté en casa. ",
    "de": "Zuallererst: Ruf sofort einen Erwachsenen, Mama, Papa oder wer gerade zu Hause ist. ",
    "fr": "Avant tout : appelle tout de suite un adulte, maman, papa ou la personne à la maison. ",
}


# --- identity, human health, prompt leak, forced yes/no, future animal, prices

_IDENTITY_QUESTION = re.compile(
    r"\b(?:sei|ma sei|tu sei|siete) (?:un |una |uno |il |la )?(?:veterinari\w*|medic\w*|"
    r"dottor\w*|persona|umano|umana|robot|bot|intelligenza artificiale|ia|ai|macchina|"
    r"programma|chatbot)\b|"
    r"\bchi (?:sei|e che parla)\b|\bcosa sei\b|\bsei (?:vero|reale)\b|"
    r"\bare you (?:a |an )?(?:vet|veterinarian|doctor|human|person|robot|bot|ai|machine)\b|"
    r"\bwho are you\b|\bwhat are you\b|"
    r"\beres (?:un |una )?(?:veterinari\w*|medic\w*|persona|humano|robot|bot|ia)\b|"
    r"\bquien eres\b|\bque eres\b|"
    r"\bbist du (?:ein |eine )?(?:tierarzt|tierarztin|arzt|mensch|roboter|bot|ki)\b|"
    r"\bwer bist du\b|\bwas bist du\b|"
    r"\b(?:es-tu|tu es|etes-vous|vous etes) (?:un |une )?(?:veterinaire|medecin|humain|"
    r"personne|robot|bot|ia)\b|\bqui es-tu\b|\bqui etes-vous\b|\bqu'es-tu\b"
)


def is_identity_question(message: str) -> bool:
    """ "Sei un veterinario?", "chi sei?": answered by a fixed text, never by
    the model (it invented "I work with animals" twice)."""
    return bool(_IDENTITY_QUESTION.search(normalize_for_matching(message)))


IDENTITY_TEXTS: dict[str, str] = {
    "it": (
        "Sono l'assistente dell'app, un'intelligenza artificiale: non sono un veterinario, "
        "non ho esperienza personale e non lavoro con nessuno studio; ti aiuto a "
        "capire {name}, perché fa quello che fa e come gestirlo ogni giorno, spiego referti "
        "con parole semplici e ti dico quando è il caso di sentire il veterinario, partendo "
        "dalle posizioni degli organismi veterinari. Non faccio diagnosi e non do dosaggi: "
        "per le decisioni sulla salute di {name} c'è il tuo veterinario, io ti aiuto ad "
        "arrivarci preparato."
    ),
    "en": (
        "No, I am not a vet: I am the app's assistant, an artificial intelligence, with no "
        "personal experience and no clinic behind me. I help you understand {name}, why "
        "they do what they do and how to manage everyday life together, I explain reports in "
        "plain words and tell you when it is time to see the vet, starting from the positions "
        "of veterinary bodies. I do not diagnose and I do not give dosages: decisions about "
        "{name}'s health belong to your vet, I help you get there prepared."
    ),
    "es": (
        "No, no soy veterinario: soy el asistente de la app, una inteligencia artificial, "
        "sin experiencia personal y sin una clínica detrás; te ayudo a entender a {name}, "
        "por qué hace lo que hace y cómo gestionar el día a día, explico informes con "
        "palabras sencillas y te digo cuándo conviene ver al veterinario, partiendo de las "
        "posiciones de los organismos veterinarios. No hago diagnósticos ni doy dosis: las "
        "decisiones sobre la salud de {name} son de tu veterinario, yo te ayudo a llegar "
        "preparado."
    ),
    "de": (
        "Nein, ich bin keine Tierärztin und kein Tierarzt: Ich bin der Assistent der App, "
        "eine künstliche Intelligenz, ohne eigene Erfahrung und ohne Praxis im Hintergrund. "
        "Ich helfe Ihnen, {name} zu verstehen, warum das Tier tut, was es tut, und wie Sie "
        "den Alltag gut gestalten; ich erkläre Befunde in einfachen Worten und sage Ihnen, "
        "wann es Zeit für die Tierarztpraxis ist, ausgehend von den Positionen der "
        "tierärztlichen Fachverbände. Ich stelle keine Diagnosen und nenne keine "
        "Dosierungen: Entscheidungen über die Gesundheit von {name} trifft Ihre Praxis, ich "
        "helfe Ihnen, vorbereitet hinzugehen."
    ),
    "fr": (
        "Non, je ne suis pas vétérinaire : je suis l'assistant de l'appli, une intelligence "
        "artificielle, sans expérience personnelle et sans cabinet derrière moi ; je vous "
        "aide à comprendre {name}, pourquoi il fait ce qu'il fait et comment bien gérer le "
        "quotidien, j'explique les comptes rendus avec des mots simples et je vous dis quand "
        "il faut voir le vétérinaire, en partant des positions des organismes vétérinaires. "
        "Je ne pose pas de diagnostic et je ne donne pas de dosages : les décisions sur la "
        "santé de {name} reviennent à votre vétérinaire, je vous aide à y arriver préparé."
    ),
}

# Human health, first person (I): a fixed, kind redirect with no content
# and no reference to the animal.
_HUMAN_SELF = re.compile(
    r"\b(?:io|me|a me|mi|mio marito|mia moglie|mio figlio|mia figlia|mia madre|mio padre|"
    r"i|me|my husband|my wife|my son|my daughter|yo|a mi|mi marido|mi mujer|ich|mir|mich|"
    r"mein mann|meine frau|je|moi|mon mari|ma femme)\b"
)
_HUMAN_SYMPTOM = re.compile(
    r"\b(?:ho|avere|tengo|habe|j'ai|i have|i've got)\b.{0,25}\b(?:febbre|mal di testa|"
    r"mal di gola|mal di pancia|mal di schiena|tosse|raffreddore|influenza|nausea|"
    r"pressione|diabete|allergia|ansia|insonnia|dolore|fever|headache|sore throat|cough|"
    r"cold|flu|nausea|pain|fiebre|dolor de cabeza|tos|gripe|fieber|kopfschmerzen|husten|"
    r"erkaltung|grippe|fievre|mal de tete|toux|rhume|grippe)\b|"
    r"\b(?:cosa posso prendere|che posso prendere|what can i take|que puedo tomar|"
    r"was kann ich nehmen|que puis-je prendre)\b|"
    r"\b(?:febbre|fever|fiebre|fieber|fievre)\b.{0,20}\b(?:io|me|i|yo|ich|moi)\b"
)
_ANIMAL_WORD = re.compile(
    r"\b(?:cane|cani|gatto|gatta|gatti|coniglio|cucciol\w*|criceto|pappagallo|cocorita|"
    r"geco|tartaruga|pesc[ei]|furetto|cavallo|animale|dog|cat|rabbit|puppy|kitten|hamster|"
    r"parrot|perro|gato|conejo|hund|katze|kaninchen|chien|chat|lapin)\b"
)


def is_human_health_question(message: str) -> bool:
    """ "Ho 38.5 di febbre io, cosa posso prendere?": human medicine, with
    no animal in the sentence."""
    text = normalize_for_matching(message)
    if _ANIMAL_WORD.search(text):
        return False
    first_person = re.match(r"^(?:ho|io ho|i have|i've got|tengo|ich habe|j'ai)\b", text)
    return bool(_HUMAN_SYMPTOM.search(text) and (first_person or _HUMAN_SELF.search(text)))


HUMAN_HEALTH_TEXTS: dict[str, str] = {
    "it": (
        "Mi dispiace che tu non stia bene. Per la salute delle persone però non sono la "
        "fonte giusta: Quokka si occupa degli animali e di chi vive con loro. Per te, medico "
        "o farmacista, e se stai male davvero il 118. Quando vuoi, sono qui per il tuo animale."
    ),
    "en": (
        "I am sorry you are unwell. For people's health, though, I am not the right source: "
        "Quokka is about animals and the people who live with them. For you, a doctor or a "
        "pharmacist, and the emergency number if you feel really ill. I am here for your "
        "animal whenever you want."
    ),
    "es": (
        "Siento que no te encuentres bien. Para la salud de las personas no soy la fuente "
        "adecuada: Quokka se ocupa de los animales y de quienes viven con ellos. Para ti, "
        "médico o farmacéutico, y si estás realmente mal, el 112. Cuando quieras, estoy aquí "
        "para tu animal."
    ),
    "de": (
        "Es tut mir leid, dass es Ihnen nicht gut geht. Für die Gesundheit von Menschen bin "
        "ich aber nicht die richtige Quelle: Quokka ist für Tiere und die Menschen da, die "
        "mit ihnen leben. Für Sie: Arztpraxis oder Apotheke, und bei ernsten Beschwerden die "
        "112. Für Ihr Tier bin ich jederzeit da."
    ),
    "fr": (
        "Je suis désolé que vous ne vous sentiez pas bien. Pour la santé des personnes, je ne "
        "suis pas la bonne source : Quokka s'occupe des animaux et de ceux qui vivent avec "
        "eux. Pour vous, médecin ou pharmacien, et le 15 si vous allez vraiment mal. Pour "
        "votre animal, je suis là quand vous voulez."
    ),
}

_PROMPT_LEAK = re.compile(
    r"ignora (?:tutte )?le (?:tue )?istruzioni|istruzioni precedenti|prompt di sistema|"
    r"system prompt|le tue istruzioni|le tue regole|mostrami il prompt|"
    r"ignore (?:all )?(?:previous|prior|your) instructions|reveal your (?:prompt|instructions|"
    r"rules)|print your (?:prompt|instructions)|"
    r"ignora (?:todas )?las instrucciones|instrucciones anteriores|prompt del sistema|"
    r"ignoriere (?:alle )?(?:vorherigen |bisherigen )?anweisungen|systemprompt|system-prompt|"
    r"ignore (?:toutes )?les instructions|instructions precedentes|prompt systeme|"
    r"\[admin mode\]|admin mode|modalita sviluppatore|developer mode|dev mode|"
    r"modo desarrollador|entwicklermodus|mode developpeur"
)


def is_prompt_leak_request(message: str) -> bool:
    return bool(_PROMPT_LEAK.search(normalize_for_matching(message)))


PROMPT_LEAK_TEXTS: dict[str, str] = {
    "it": (
        "Le mie istruzioni non le condivido, ma ti dico volentieri cosa faccio: ti aiuto a "
        "capire {name}, perché fa quello che fa e come gestirlo ogni giorno, spiego referti "
        "con parole semplici e ti dico quando è il caso di sentire il veterinario. Chiedimi "
        "pure qualcosa su {name}."
    ),
    "en": (
        "I do not share my instructions, but I am happy to tell you what I do: I help you "
        "understand {name}, why they do what they do and how to manage everyday life, I "
        "explain reports in plain words and tell you when to see the vet. Ask me anything "
        "about {name}."
    ),
    "es": (
        "Mis instrucciones no las comparto, pero te cuento con gusto lo que hago: te ayudo a "
        "entender a {name}, por qué hace lo que hace y cómo gestionar el día a día, explico "
        "informes con palabras sencillas y te digo cuándo ver al veterinario. Pregúntame lo "
        "que quieras sobre {name}."
    ),
    "de": (
        "Meine Anweisungen teile ich nicht, aber gern sage ich Ihnen, was ich tue: Ich helfe "
        "Ihnen, {name} zu verstehen, warum das Tier tut, was es tut, und wie Sie den Alltag "
        "gestalten; ich erkläre Befunde in einfachen Worten und sage, wann es Zeit für die "
        "Tierarztpraxis ist. Fragen Sie mich gern etwas zu {name}."
    ),
    "fr": (
        "Je ne partage pas mes instructions, mais je vous dis volontiers ce que je fais : je "
        "vous aide à comprendre {name}, pourquoi il fait ce qu'il fait et comment gérer le "
        "quotidien, j'explique les comptes rendus avec des mots simples et je vous dis quand "
        "voir le vétérinaire. Posez-moi une question sur {name}."
    ),
}

_FORCED_YES_NO = re.compile(
    r"rispondi (?:solo|soltanto) (?:con )?(?:si|no)|solo (?:si|no)\b.{0,12}\b(?:si|no)\b|"
    r"(?:si|no) o (?:si|no)\b|answer (?:only |just )?(?:with )?yes or no|yes or no only|"
    r"responde (?:solo )?si o no|antworte (?:nur )?(?:mit )?ja oder nein|"
    r"reponds? (?:juste |seulement )?(?:par )?oui ou non"
)


def asks_for_a_bare_yes_or_no(message: str) -> bool:
    return bool(_FORCED_YES_NO.search(normalize_for_matching(message)))


_FUTURE_ANIMAL = re.compile(
    r"\b(?:voglio|vorrei|vorremmo|sto pensando di|stiamo pensando di|pensavo di|mi piacerebbe|"
    r"conviene|ha senso) (?:prendere|prenderne|adottare|comprare|acquistare|regalare)\b|"
    r"\b(?:prima di prendere|se prendo|se prendessi|quale (?:razza|cane|gatto) (?:mi consigli|"
    r"scegliere|prendere))\b|"
    r"\b(?:i want to|i'd like to|we want to|thinking of|thinking about|should i) (?:get|getting|"
    r"adopt|adopting|buy|buying)\b|\bbefore getting a\b|"
    r"\b(?:quiero|queremos|me gustaria|estoy pensando en) (?:adoptar|comprar|tener)\b|"
    r"\b(?:ich mochte|wir mochten|ich uberlege|ich will) (?:mir |uns )?(?:einen |eine |ein )?"
    r"\w+ (?:anschaffen|kaufen|adoptieren|holen)\b|"
    r"\b(?:je veux|je voudrais|nous voulons|j'aimerais|je pense) (?:prendre|adopter|acheter)\b"
)


def is_about_a_future_animal(message: str) -> bool:
    """ "Voglio prendere un husky": the animal does not exist yet, so the
    profile's name and data must stay out of the answer."""
    return bool(_FUTURE_ANIMAL.search(normalize_for_matching(message)))


_PRICE = re.compile(
    r"(?:\d[\d.,]*\s?(?:€|euro|eur\b|\$|dollar\w*|£|pounds?|chf|franchi)|(?:€|\$|£)\s?\d[\d.,]*)",
    re.IGNORECASE,
)
_SENTENCE_END = re.compile(r"(?<=[.!?])\s+")


def strip_invented_prices(answer: str, owner_text: str) -> str:
    """Drops every sentence that quotes a price the owner did not write
    (G: 'una visita con analisi costa tra 150 € e 250 €'). Prices vary: the
    prompt says to ask for a preventivo instead."""
    owner_prices = {re.sub(r"[\s.,]", "", found.lower()) for found in _PRICE.findall(owner_text)}
    kept: list[str] = []
    for paragraph in answer.split("\n"):
        sentences = _SENTENCE_END.split(paragraph) if paragraph.strip() else [paragraph]
        kept_sentences = [
            sentence
            for sentence in sentences
            if not any(
                re.sub(r"[\s.,]", "", found.lower()) not in owner_prices
                for found in _PRICE.findall(sentence)
            )
        ]
        kept.append(" ".join(kept_sentences))
    cleaned = "\n".join(kept).strip()
    return cleaned or answer
