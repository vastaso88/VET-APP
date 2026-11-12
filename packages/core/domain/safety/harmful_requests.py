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
    "pet passport, and in Italy it is not transferred before 60 days OF AGE (two months old, "
    "counted from birth, never from arrival); the buyer risks seizure, costs and a sick "
    "animal. Never write 'se decidi comunque di procedere', 'if you decide to proceed' or "
    "any sentence that frames this purchase as an option: say instead "
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
        "Welches Mittel und wie viel sage ich Ihnen nicht: ein Tier zu Hause ohne Tierärztin oder "
        "Tierarzt einzuschläfern bedeutet fast immer mehr Leid, nicht weniger, und das lässt sich "
        "allein nicht gut machen. Was Sie heute tun können: Rufen Sie Ihre Tierarztpraxis an und "
        "schildern Sie Ihre Lage. Oft findet sich ein Weg: eine Untersuchung, um zu sehen, wie "
        "sehr {name} wirklich leidet und was gegen die Schmerzen möglich ist, eine Ratenzahlung, "
        "ein Tierschutzverein oder ein Tierheim, das bei den Kosten hilft. Wenn es Zeit ist "
        "loszulassen, übernimmt die Praxis die Einschläferung, schmerzfrei und oft zu geringeren "
        "oder unterstützten Kosten. Sie sind damit nicht allein."
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
        "Auf eine solche Frage kann ich nicht mit Ja oder Nein antworten: ohne Untersuchung und "
        "Tests kann das niemand sagen, und ein einzelnes Wort könnte Sie zu Unrecht beunruhigen "
        "oder beruhigen. Sagen Sie mir, was Sie bei {name} darauf gebracht hat, und ich erkläre, "
        "was es bedeuten kann und was nötig ist, um es wirklich zu wissen."
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
        "Menschen, die es nutzen. Ich helfe Ihnen, {name} zu verstehen und sich auf einen Besuch "
        "oder einen Behördengang vorzubereiten; braucht eine Behörde ein Dokument, sagt sie "
        "selbst, welches und wer es ausstellt."
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
    r"\b(?:ho|tengo|ich bin|j'ai|i am|i'm|scrive \w+,?|sono \w+,?|mi chiamo \w+,?|qui \w+,?|"
    r"\w+ \(|this is \w+,?|soy \w+,?|hier (?:ist|schreibt) \w+,?|ici \w+,?) (\d{1,2}) "
    r"(?:anni|anos|jahre(?: alt)?|ans|years(?: old)?)\b"
)
_WRITTEN_AGE = {
    "cinque": 5,
    "sei": 6,
    "sette": 7,
    "otto": 8,
    "nove": 9,
    "dieci": 10,
    "undici": 11,
    "dodici": 12,
    "tredici": 13,
    "quattordici": 14,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
    "eleven": 11,
    "twelve": 12,
    "thirteen": 13,
    "fourteen": 14,
    "cinco": 5,
    "seis": 6,
    "siete": 7,
    "ocho": 8,
    "nueve": 9,
    "diez": 10,
    "once": 11,
    "doce": 12,
    "trece": 13,
    "catorce": 14,
    "funf": 5,
    "sechs": 6,
    "sieben": 7,
    "acht": 8,
    "neun": 9,
    "zehn": 10,
    "elf": 11,
    "zwolf": 12,
    "dreizehn": 13,
    "vierzehn": 14,
    "cinq": 5,
    "sept": 7,
    "huit": 8,
    "neuf": 9,
    "dix": 10,
    "onze": 11,
    "douze": 12,
    "treize": 13,
    "quatorze": 14,
}
_WRITTEN_AGE_RE = re.compile(
    r"\b(?:ho|sono \w+,?|scrive \w+,?|i am|i'm|tengo|ich bin|j'ai) ("
    + "|".join(sorted(_WRITTEN_AGE, key=len, reverse=True))
    + r") (?:anni|years(?: old)?|anos|jahre|ans)\b"
)
# A child alone at home, with an age anywhere in the message.
_ALONE_CHILD = _words(
    r"papa non c'e|mamma non c'e|i miei (?:genitori )?non ci sono|sono (?:da )?sol[oa] a casa|"
    r"sono a casa (?:da )?sol[oa]|dad (?:is not|isn't) (?:here|home)|mum (?:is not|isn't) "
    r"(?:here|home)|mom (?:is not|isn't) (?:here|home)|home alone|papa no esta|mama no esta|"
    r"estoy sol[oa] en casa|papa ist nicht da|mama ist nicht da|bin allein zu hause|"
    r"papa n'est pas la|maman n'est pas la|suis seul[e]? a la maison"
)
_ANY_AGE = re.compile(r"\b(\d{1,2}) (?:anni|years(?: old)?|anos|jahre|ans)\b")
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
    written = _WRITTEN_AGE_RE.search(text)
    if written and _WRITTEN_AGE.get(written.group(1), 99) <= 14:
        return True
    if _ALONE_CHILD.search(text):
        # "scrive Luca 12 anni: papà non c'è" (synthetic users 2026-11-07).
        ages = [int(a) for a in _ANY_AGE.findall(text)]
        if any(a <= 14 for a in ages):
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
        "Ich bin der Assistent der App, eine künstliche Intelligenz: keine Tierärztin und kein "
        "Tierarzt, ohne eigene Erfahrung und ohne Praxis im Hintergrund. Ich helfe Ihnen, {name} "
        "zu verstehen, warum das Tier tut, was es tut, und wie Sie den Alltag gut gestalten; ich "
        "erkläre Befunde in einfachen Worten und sage Ihnen, wann es Zeit für die Tierarztpraxis "
        "ist, ausgehend von den Positionen der tierärztlichen Fachverbände. Ich stelle keine "
        "Diagnosen und nenne keine Dosierungen: Entscheidungen über die Gesundheit von {name} "
        "trifft Ihre Praxis, ich helfe Ihnen, vorbereitet hinzugehen."
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
        "Es tut mir leid, dass es Ihnen nicht gut geht. Für die Gesundheit von Menschen bin ich "
        "aber nicht die richtige Quelle: Quokka ist für Tiere und die Menschen da, die mit ihnen "
        "leben. Für Sie: Arztpraxis oder Apotheke, und bei ernsten Beschwerden die 112. Für Ihr "
        "Tier bin ich jederzeit da."
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


def strip_invented_prices(answer: str, owner_text: str, replacement: str = "") -> str:
    """Replaces (or drops, with no replacement) every sentence that quotes a
    price the owner did not write (G: 'una visita con analisi costa tra 150 €
    e 250 €'): the owner's money question still gets an answer (third round,
    11), just not a figure."""
    owner_prices = {re.sub(r"[\s.,]", "", found.lower()) for found in _PRICE.findall(owner_text)}
    kept: list[str] = []
    for paragraph in answer.split("\n"):
        sentences = _SENTENCE_END.split(paragraph) if paragraph.strip() else [paragraph]
        kept_sentences: list[str] = []
        replaced = False
        for sentence in sentences:
            invented = any(
                re.sub(r"[\s.,]", "", found.lower()) not in owner_prices
                for found in _PRICE.findall(sentence)
            )
            if not invented:
                kept_sentences.append(sentence)
            elif replacement and not replaced:
                kept_sentences.append(replacement)
                replaced = True
        kept.append(" ".join(kept_sentences))
    cleaned = "\n".join(kept).strip()
    return cleaned or answer


# 4. A dog's antiparasitic the owner is ABOUT to put on the cat: "no, never",
# with the why; the triage stays for the cat that already got it.
PERMETHRIN_INTENT_TEXTS: dict[str, str] = {
    "it": (
        "No, mai: le pipette, i collari e gli spray antiparassitari per cani contengono "
        "spesso permetrina, che per il gatto è un veleno. Anche una sola pipetta può causare "
        "tremori, convulsioni e la morte, e non conta che sia 'avanzata' o che la dose sembri "
        "piccola. Per {name} serve un prodotto fatto per i gatti, scelto con il veterinario "
        "in base al peso. Se gliel'hai già messa, anche poca, chiama subito il veterinario o "
        "un pronto soccorso veterinario."
    ),
    "en": (
        "No, never: dog flea pipettes, collars and sprays often contain permethrin, which is "
        "a poison for cats. Even a single pipette can cause tremors, seizures and death, and "
        "it does not matter that it was 'left over' or that the dose looks small. {name} "
        "needs a product made for cats, chosen with the vet by weight. If you have already "
        "applied it, even a little, call your vet or an emergency clinic right away."
    ),
    "es": (
        "No, nunca: las pipetas, collares y sprays antiparasitarios para perros suelen "
        "contener permetrina, que para el gato es un veneno. Una sola pipeta puede causar "
        "temblores, convulsiones y la muerte, y da igual que 'sobrara' o que la dosis parezca "
        "pequeña. {name} necesita un producto hecho para gatos, elegido con el veterinario "
        "según el peso. Si ya se la has puesto, aunque sea poca, llama ahora mismo al "
        "veterinario o a urgencias veterinarias."
    ),
    "de": (
        "Nein, niemals: Spot-ons, Halsbänder und Sprays gegen Parasiten für Hunde enthalten oft "
        "Permethrin, für Katzen ein Gift. Schon eine einzige Pipette kann Zittern, Krämpfe und "
        "den Tod verursachen, egal ob sie 'übrig' war oder die Menge klein wirkt. {name} braucht "
        "ein Produkt für Katzen, mit der Tierarztpraxis nach Gewicht ausgewählt. Falls Sie es "
        "schon aufgetragen haben, auch nur wenig, rufen Sie sofort die Praxis oder einen "
        "Notdienst an."
    ),
    "fr": (
        "Non, jamais : les pipettes, colliers et sprays antiparasitaires pour chiens "
        "contiennent souvent de la perméthrine, un poison pour le chat. Une seule pipette "
        "peut provoquer tremblements, convulsions et la mort, et peu importe qu'elle soit "
        "'en trop' ou que la dose paraisse faible. {name} a besoin d'un produit pour chats, "
        "choisi avec le vétérinaire selon le poids. Si vous l'avez déjà appliquée, même un "
        "peu, appelez tout de suite votre vétérinaire ou un service d'urgences."
    ),
}


# --- third round (2026-11-06): dose changes, a hurt child, vomiting, diets, grief

_PRESCRIPTION = _words(
    r"prescritt\w*|ricetta|terapia|cura|il veterinario (?:mi )?ha detto|il veterinario (?:gli|le) "
    r"ha dato|(?:gli|le) ha dato|compress\w* al giorno|volte al giorno|"
    r"prescribed|prescription|the vet said|the vet gave|tablets? a day|times a day|"
    r"recet\w*|el veterinario (?:me )?dijo|comprimidos al dia|pastillas al dia|veces al dia|"
    r"verschrieben|rezept|der tierarzt (?:hat )?gesagt|tabletten am tag|"
    r"prescrit\w*|ordonnance|le veterinaire (?:m')?a dit|comprimes par jour"
)
_DOSE_CHANGE = _words(
    r"ne do (?:solo |soltanto )?(?:una|mezza|due|meno|di piu|di meno)|ne do (?:una|mezza)\b|"
    r"gliene do (?:una|mezza|meno|di piu)|(?:ridurr\w*|riduco|abbass\w*|dimezz\w*|raddoppi\w*|"
    r"aument\w*|diminui\w*|togli\w*|salt\w*|sospend\w*|smett\w*|interromp\w*|fermo) (?:\w+ ){0,3}"
    r"(?:la dose|le dosi|la compressa|le compresse|la terapia|la cura|il farmaco|la pastiglia|"
    r"le pastiglie|le gocce)|mi sembra (?:troppo|troppa|tanto|poco|poca)|e troppo per lui|"
    r"e troppo per lei|posso darne (?:meno|di meno|di piu|una)|posso saltar\w*|posso smetter\w*|"
    r"posso sospender\w*|posso non dargliel\w*|senza dirlo al veterinario|"
    r"(?:halve|double|reduce|lower|increase|skip|stop|cut|drop) (?:\w+ ){0,3}(?:the dose|the "
    r"dosage|the tablets?|the pills?|the medication|the medicine|a dose|it)|"
    r"give (?:him|her|it) (?:only |just )?(?:one|half|less|more)|seems (?:too much|a lot|too "
    r"little)|can i skip|can i stop|"
    r"le doy (?:solo |solamente )?(?:una|media|menos|mas)|(?:reducir|bajar|subir|aumentar|saltar|"
    r"suspender|dejar|quitar) (?:\w+ ){0,3}(?:la dosis|las pastillas|el medicamento|la "
    r"medicacion|el tratamiento)|me parece (?:mucho|demasiado|poco)|"
    r"gebe ich (?:nur )?(?:eine|eine halbe|weniger|mehr)|ich gebe (?:ihm |ihr )?(?:nur |lieber )?"
    r"(?:eine|eine halbe|weniger|mehr)|(?:halbier\w*|verdoppel\w*|reduzier\w*|"
    r"erhoh\w*|weglass\w*|absetz\w*|aufhor\w*) (?:\w+ ){0,3}(?:die dosis|die tablette|das "
    r"medikament|die medikamente)|kommt mir (?:viel|zu viel|wenig) vor|"
    r"je (?:lui )?(?:en )?donne (?:que |seulement )?(?:un|une|une demie|moins|plus)|(?:reduire|"
    r"baisser|augmenter|doubler|sauter|arreter|supprimer) (?:\w+ ){0,3}(?:la dose|les comprimes|"
    r"le medicament|le traitement)|ca me parait (?:beaucoup|trop|peu)"
)


def is_dose_change_request(message: str) -> bool:
    """ "Gli ha prescritto 2 compresse al giorno, ne do una, giusto?": the
    owner wants to change a prescribed dose on their own (less, more, skip,
    stop). A fixed answer: never a confirmation, never a number."""
    text = normalize_for_matching(message)
    return bool(_PRESCRIPTION.search(text) and _DOSE_CHANGE.search(text))


DOSE_CHANGE_TEXTS: dict[str, str] = {
    "it": (
        "Capisco il dubbio, ma la dose di un farmaco prescritto non si cambia da soli, né in "
        "meno né in più, e non si salta né si sospende senza sentire chi l'ha prescritta: il "
        "veterinario l'ha calcolata sul peso di {name}, sulla sua malattia e su come "
        "funziona quel farmaco, e dare meno (o più) può rendere la cura inutile o "
        "pericolosa, a volte senza segni visibili subito. Chiama il tuo veterinario e "
        "chiedigli proprio questo: se la dose può essere rivista. Se il dubbio nasce da "
        "qualcosa che hai notato in {name} (vomito, sonnolenza, inappetenza, altro), "
        "diglielo subito: è il motivo per riparlarne, oggi."
    ),
    "en": (
        "I understand the doubt, but the dose of a prescribed medicine is not changed on "
        "one's own, neither down nor up, and it is not skipped or stopped without asking "
        "whoever prescribed it: the vet worked it out on {name}'s weight, illness and on how "
        "that medicine works, and giving less (or more) can make the treatment useless or "
        "dangerous, sometimes with no visible sign at first. Call your vet and ask exactly "
        "this: whether the dose can be reviewed. If the doubt comes from something you "
        "noticed in {name} (vomiting, drowsiness, not eating, anything else), tell them right "
        "away: that is the right reason to talk about it, today."
    ),
    "es": (
        "Entiendo la duda, pero la dosis de un medicamento recetado no se cambia por cuenta "
        "propia, ni hacia abajo ni hacia arriba, y no se salta ni se suspende sin consultar a "
        "quien la recetó: el veterinario la calculó según el peso de {name}, su enfermedad y "
        "cómo actúa ese medicamento, y dar menos (o más) puede volver el tratamiento inútil "
        "o peligroso, a veces sin señales visibles al principio. Llama a tu veterinario y "
        "pregúntale justo esto: si la dosis se puede revisar. Si la duda nace de algo que "
        "has notado en {name} (vómitos, somnolencia, falta de apetito, otra cosa), díselo "
        "enseguida: es el motivo correcto para hablarlo, hoy."
    ),
    "de": (
        "Ich verstehe den Zweifel, aber die Dosis eines verschriebenen Medikaments ändert man "
        "nicht selbst, weder nach unten noch nach oben, und man lässt sie nicht aus oder setzt "
        "sie ab, ohne mit der Praxis zu sprechen, die sie verschrieben hat: Sie wurde nach dem "
        "Gewicht von {name}, der Erkrankung und der Wirkweise des Medikaments berechnet, und "
        "weniger (oder mehr) kann die Behandlung wirkungslos oder gefährlich machen, manchmal "
        "zunächst ohne sichtbare Zeichen. Rufen Sie Ihre Tierarztpraxis an und fragen Sie genau "
        "das: ob die Dosis überprüft werden kann. Wenn der Zweifel von etwas kommt, das Sie bei "
        "{name} bemerkt haben (Erbrechen, Müdigkeit, Appetitlosigkeit oder anderes), sagen Sie es "
        "sofort: Das ist der richtige Grund, heute darüber zu sprechen."
    ),
    "fr": (
        "Je comprends le doute, mais la dose d'un médicament prescrit ne se change pas seul, "
        "ni à la baisse ni à la hausse, et on ne la saute pas ni ne l'arrête sans en parler à "
        "la personne qui l'a prescrite : le vétérinaire l'a calculée selon le poids de "
        "{name}, sa maladie et le fonctionnement de ce médicament, et en donner moins (ou "
        "plus) peut rendre le traitement inutile ou dangereux, parfois sans signe visible au "
        "début. Appelez votre vétérinaire et posez-lui exactement cette question : la dose "
        "peut-elle être revue ? Si le doute vient de quelque chose que vous avez remarqué chez "
        "{name} (vomissements, somnolence, perte d'appétit, autre), dites-le tout de suite : "
        "c'est la bonne raison d'en reparler, aujourd'hui."
    ),
}

_INJURY = _words(
    r"mors[oa]|morsicat[oa]|mi ha morso|mi ha graffiat[oa]|graffi[oa]|sanguin\w*|sangue|ferit[oa]|"
    r"taglio|bit me|bitten|bite|bleeding|blood|scratched|wound|cut|"
    r"me mordio|mordid[oa]|me arano|sangra|sangre|herida|"
    r"gebissen|biss|blutet|blut|gekratzt|wunde|"
    r"mordu|morsure|m'a mordu|griffe|saigne|sang|blessure"
)


def is_minor_hurt(message: str) -> bool:
    """A child writing about their own bite, scratch or bleeding: a fixed,
    simple reply, no clarifying question."""
    return is_minor_writing(message) and bool(_INJURY.search(normalize_for_matching(message)))


MINOR_HURT_TEXTS: dict[str, str] = {
    "it": (
        "Prima di tutto chiama subito un adulto: la mamma, il papà o chi è in casa con te. "
        "Intanto lava bene la mano con acqua e sapone, poi premi sulla ferita con un panno "
        "pulito. Un adulto ti porterà dal medico a far vedere la mano: per un morso si fa "
        "sempre. Non è colpa tua e nemmeno del cane: stava difendendo il suo osso, i cani lo "
        "fanno quando hanno paura che glielo portino via. Quando l'adulto è con te, posso "
        "spiegare anche a lui cosa fare."
    ),
    "en": (
        "First of all call an adult right now: your mum, your dad or whoever is at home. "
        "Meanwhile wash your hand well with soap and water, then press on the wound with a "
        "clean cloth. An adult will take you to the doctor to have the hand checked: for a "
        "bite that is always done. It is not your fault and not the dog's either: it was "
        "guarding its bone, dogs do that when they are afraid it will be taken away. When the "
        "adult is with you, I can explain to them what to do too."
    ),
    "es": (
        "Antes de nada llama ahora mismo a un adulto: mamá, papá o quien esté en casa. "
        "Mientras tanto lávate bien la mano con agua y jabón y luego aprieta sobre la herida "
        "con un paño limpio. Un adulto te llevará al médico para que te mire la mano: con un "
        "mordisco se hace siempre. No es culpa tuya ni del perro: estaba defendiendo su hueso, "
        "los perros lo hacen cuando tienen miedo de que se lo quiten. Cuando el adulto esté "
        "contigo, también le puedo explicar qué hacer."
    ),
    "de": (
        "Ruf zuallererst sofort einen Erwachsenen: Mama, Papa oder wer gerade zu Hause ist. "
        "Wasch dir in der Zwischenzeit die Hand gut mit Wasser und Seife und drück dann mit "
        "einem sauberen Tuch auf die Wunde. Ein Erwachsener bringt dich zum Arzt, damit die "
        "Hand angeschaut wird: bei einem Biss macht man das immer. Es ist nicht deine Schuld "
        "und auch nicht die des Hundes: Er hat seinen Knochen verteidigt, das tun Hunde, wenn "
        "sie Angst haben, dass man ihn wegnimmt. Wenn der Erwachsene bei dir ist, kann ich "
        "auch ihm erklären, was zu tun ist."
    ),
    "fr": (
        "Avant tout, appelle tout de suite un adulte : maman, papa ou la personne qui est à la "
        "maison. En attendant, lave bien ta main à l'eau et au savon, puis appuie sur la "
        "plaie avec un linge propre. Un adulte t'emmènera chez le médecin pour montrer ta "
        "main : pour une morsure, on le fait toujours. Ce n'est pas ta faute, ni celle du "
        "chien : il protégeait son os, les chiens font ça quand ils ont peur qu'on le leur "
        "prenne. Quand l'adulte sera avec toi, je pourrai aussi lui expliquer quoi faire."
    ),
}

_VOMIT = _words(
    r"vomit\w*|rimett\w*|rigett\w*|throw\w* up|threw up|vomiting|vomited|vomit\w*|erbr\w*|"
    r"ubergeben|vomi\w*"
)
_NOT_EATING = _words(
    r"non mangia|non vuole mangiare|non tocca cibo|rifiuta il cibo|senza mangiare|non ha mangiato|"
    r"doesn't want to eat|does not want to eat|not eating|won't eat|refuses food|hasn't eaten|"
    r"no come|no quiere comer|sin comer|no ha comido|"
    r"frisst nicht|will nicht fressen|ohne zu fressen|hat nicht gefressen|"
    r"ne mange pas|ne veut pas manger|sans manger|n'a pas mange"
)
_A_DAY_OR_MORE = _words(
    r"da ieri|da ieri sera|da stanotte|da due giorni|da tre giorni|da (?:piu di )?24 ore|da giorni|"
    r"since yesterday|since last night|for (?:a|one|two|three) days?|for 24 hours|for days|"
    r"desde ayer|desde anoche|desde hace (?:un|dos|tres) dias|"
    r"seit gestern|seit gestern abend|seit (?:einem|zwei|drei) tag\w*|seit tagen|"
    r"depuis hier|depuis hier soir|depuis (?:un|deux|trois) jours?|depuis des jours"
)


def vomiting_and_not_eating_for_a_day(message: str) -> bool:
    """Vomiting plus not eating for a day or more: the visit is today, in
    every language, not 'if it goes on another 24 hours'."""
    text = normalize_for_matching(message)
    return bool(_VOMIT.search(text) and _NOT_EATING.search(text) and _A_DAY_OR_MORE.search(text))


_PLANT_DIET = _words(
    r"vegan\w*|vegetarian\w*|vegetal\w*|vegetarisch\w*|veganisch\w*|vegetalien\w*|vegetarien\w*|"
    r"senza carne|meat-free|sin carne|ohne fleisch|sans viande"
)


def is_plant_diet_for_a_carnivore(message: str, family: str) -> bool:
    """A vegan or vegetarian diet for a cat (or a ferret): the answer must
    not end by offering to plan it."""
    return family in ("cat", "other") and bool(_PLANT_DIET.search(normalize_for_matching(message)))


_DEATH = _words(
    r"e mort[oa]|e mancat[oa]|se n'e andat[oa]|l'ho pers[oa]|abbiamo pers[oa]|ci ha lasciat[oa]|"
    r"addormentat[oa] ieri|eutanasia ieri|died|passed away|we lost|i lost|put to sleep|"
    r"murio|se fue|lo perdimos|la perdimos|gestorben|eingeschlafert|verloren|"
    r"est mort|est morte|est decede|est decedee|nous avons perdu|j'ai perdu"
)
_HOPELESSNESS = _words(
    r"niente ha (?:piu )?senso|nulla ha (?:piu )?senso|non ha (?:piu )?senso (?:niente|nulla)|"
    r"nemmeno alzarmi|non riesco (?:piu )?ad alzarmi|non ce la faccio piu|non voglio (?:piu )?"
    r"vivere|vorrei morire|farla finita|non vedo (?:piu )?(?:un )?motivo|"
    r"nothing makes sense|nothing matters|can't (?:even )?get up|can't go on|don't want to live|"
    r"want to die|end it all|no point|"
    r"nada tiene sentido|no puedo (?:ni )?levantarme|no puedo mas|no quiero vivir|"
    r"nichts (?:hat|macht) (?:mehr )?sinn|kann nicht (?:mehr )?aufstehen|kann nicht mehr|will "
    r"nicht mehr leben|"
    r"rien n'a (?:plus )?de sens|je n'arrive (?:plus )?a me lever|je n'en peux plus|je ne veux "
    r"plus vivre"
)


def mentions_a_death(message: str) -> bool:
    return bool(_DEATH.search(normalize_for_matching(message)))


def expresses_hopelessness(message: str) -> bool:
    """ "Niente ha più senso, nemmeno alzarmi": taken seriously, without a
    diagnosis; a fixed opening line points to the doctor or a listening
    service, never a phone number the app cannot verify."""
    return bool(_HOPELESSNESS.search(normalize_for_matching(message)))


HOPELESSNESS_OPENING: dict[str, str] = {
    "it": (
        "Quello che scrivi lo prendo sul serio. Un dolore così forte che non fa alzare dal "
        "letto merita di essere detto a qualcuno che può starti accanto: parlane presto con "
        "il tuo medico o con un servizio di ascolto, e non restare solo con questo peso. "
    ),
    "en": (
        "I take what you write seriously. A pain so heavy that it keeps you from getting up "
        "deserves to be told to someone who can stand by you: talk soon to your doctor or to "
        "a listening service, and do not stay alone with this weight. "
    ),
    "es": (
        "Me tomo en serio lo que escribes. Un dolor tan fuerte que no te deja levantarte "
        "merece contarse a alguien que pueda acompañarte: habla pronto con tu médico o con "
        "un servicio de escucha, y no te quedes solo con este peso. "
    ),
    "de": (
        "Was Sie schreiben, nehme ich ernst. Ein Schmerz, der so schwer ist, dass er Sie nicht "
        "aufstehen lässt, gehört zu jemandem, der Ihnen beistehen kann: Sprechen Sie bald mit "
        "Ihrer Ärztin oder Ihrem Arzt oder mit einer Beratungsstelle, und bleiben Sie mit dieser "
        "Last nicht allein. "
    ),
    "fr": (
        "Je prends ce que vous écrivez au sérieux. Une douleur si lourde qu'elle empêche de se "
        "lever mérite d'être dite à quelqu'un qui peut vous accompagner : parlez-en vite à "
        "votre médecin ou à un service d'écoute, et ne restez pas seul avec ce poids. "
    ),
}

_PROCEED_ANYWAY = re.compile(
    r"[^.!?\n]*\b(?:se (?:poi |comunque )?decid\w* (?:comunque |lo stesso )?di (?:procedere|"
    r"prenderlo|prenderla|acquistarlo|comprarlo|andare avanti)|se vuoi (?:comunque )?procedere|"
    r"if you (?:still |do )?(?:decide|choose|want) to (?:proceed|go ahead|buy|get it|take it)|"
    r"si (?:aun asi |de todos modos )?decides (?:seguir|comprarlo|adoptarlo|continuar)|"
    r"wenn (?:du|sie) (?:dich|sich) (?:trotzdem |dennoch )?(?:entscheid\w*|dafur entscheid\w*)|"
    r"si vous (?:decidez|choisissez) (?:quand meme |malgre tout )?de (?:proceder|l'acheter|"
    r"le prendre|continuer))\b[^.!?\n]*[.!?]?",
    re.IGNORECASE,
)


def strip_proceed_anyway(answer: str) -> str:
    """Drops the sentence that frames a purchase from the illegal trade as
    an option ('se decidi comunque di procedere, ...')."""
    cleaned = _PROCEED_ANYWAY.sub("", normalize_for_matching(answer))
    if cleaned == normalize_for_matching(answer):
        return answer
    # Work on the original text: remove the same sentences by position.
    out = answer
    for match in list(_PROCEED_ANYWAY.finditer(normalize_for_matching(out)))[::-1]:
        out = out[: match.start()] + out[match.end() :]
    return re.sub(r"[ \t]{2,}", " ", out).strip()


PRICE_REPLACEMENT: dict[str, str] = {
    "it": (
        "Sui costi non ti do cifre, cambiano molto da struttura a struttura: chiedi un "
        "preventivo scritto prima della visita e, se è un problema, di' che lo è: molti "
        "ambulatori accettano pagamenti a rate e in molte zone ci sono associazioni che aiutano."
    ),
    "en": (
        "On costs I give no figures, they vary a lot from one clinic to another: ask for a "
        "written estimate before the visit and, if money is a problem, say so: many clinics "
        "accept payment in instalments and in many areas there are associations that help."
    ),
    "es": (
        "Sobre los costes no te doy cifras, cambian mucho de una clínica a otra: pide un "
        "presupuesto por escrito antes de la visita y, si es un problema, dilo: muchas clínicas "
        "aceptan pagos a plazos y en muchas zonas hay asociaciones que ayudan."
    ),
    "de": (
        "Zu den Kosten nenne ich keine Zahlen, sie unterscheiden sich stark von Praxis zu Praxis: "
        "Bitten Sie vor dem Termin um einen schriftlichen Kostenvoranschlag und sagen Sie es, "
        "wenn das Geld knapp ist: Viele Praxen bieten Ratenzahlung an, und vielerorts helfen "
        "Tierschutzvereine."
    ),
    "fr": (
        "Sur les coûts je ne donne pas de chiffres, ils varient beaucoup d'une clinique à "
        "l'autre : demandez un devis écrit avant la visite et, si c'est un problème, dites-le : "
        "beaucoup de cliniques acceptent un paiement échelonné et, dans bien des régions, des "
        "associations peuvent aider."
    ),
}


# --- fourth round (2026-11-06): costs of care, a child never alone

_COST_WORDS = _words(
    r"quanto costa\w*|quanto costera|quanto si paga|quanto spendo|quanto viene|cost[oi]|prezz[oi]|"
    r"spes[ae]|tariff\w*|soldi|economic\w*|permettermel[oa]|preventivo|"
    r"how much (?:does|do|will|is|are)|costs?|price|prices|expensive|afford\w*|money|"
    r"cuanto cuesta\w*|cuanto vale|precio\w*|coste\w*|costo\w*|dinero|"
    r"wie viel kostet|was kostet|kosten|preis\w*|teuer|geld|"
    r"combien coute\w*|combien ca coute|prix|couts?|cher|argent"
)
_CARE_WORDS = _words(
    r"visit[ae]|controllo|cur[ae]|terapi[ae]|analisi|esam[ei]|prelievo|intervento|operazion\w*|"
    r"sterilizz\w*|castrazion\w*|vaccin\w*|richiam\w*|farmac\w*|medicin\w*|ricovero|radiografi\w*|"
    r"ecografi\w*|dentist\w*|pulizia dei denti|veterinari\w*|clinica|ambulatorio|"
    r"visit|check-?up|treatment|therapy|tests?|blood ?work|surgery|operation|neuter\w*|spay\w*|"
    r"vaccin\w*|booster|medication|medicine|hospitali[sz]\w*|x-?rays?|ultrasound|dental|vet|"
    r"veterinarian|clinic|"
    r"consulta|revision|tratamiento|analisis|pruebas|cirugia|operacion|esteriliz\w*|castra\w*|"
    r"vacuna\w*|medicament\w*|hospitali\w*|radiografi\w*|ecografi\w*|veterinari\w*|clinica|"
    r"untersuchung|kontrolle|behandlung|therapie|blutbild|bluttest|operation|kastration|"
    r"sterilisation|impf\w*|medikament\w*|rontgen|ultraschall|tierarzt\w*|tierklinik|praxis|"
    r"visite|consultation|controle|traitement|analyses?|prise de sang|chirurgie|operation|"
    r"sterilisation|castration|vaccin\w*|rappel|medicament\w*|hospitalisation|radio\w*|"
    r"echographie|veterinaire|clinique"
)


def asks_care_costs(owner_text: str) -> bool:
    """The owner asks what a visit, a treatment or a test costs (or says
    money is a problem for them): the invented figure is then replaced by
    the sentence on estimates and instalments; elsewhere it is just dropped."""
    text = normalize_for_matching(owner_text)
    return bool(_COST_WORDS.search(text) and _CARE_WORDS.search(text))


# A small child and the animal (fourth round, 2): the safety sentence is
# written before the model's text, deterministically.
CHILD_NEVER_ALONE: dict[str, str] = {
    "it": (
        "Prima di tutto: un bambino piccolo non resta mai da solo con l'animale, nemmeno "
        "per un momento, e tirare la coda, prendere per il collo o abbracciare stretto non si "
        "fa mai, neanche per gioco: un adulto accanto serve a fermare il gesto, non a renderlo "
        "accettabile. "
    ),
    "en": (
        "First of all: a small child is never left alone with the animal, not even for a "
        "moment, and pulling the tail, grabbing the neck or hugging tight is never done, not "
        "even in play: an adult nearby is there to stop the gesture, not to make it "
        "acceptable. "
    ),
    "es": (
        "Antes de nada: un niño pequeño nunca se queda solo con el animal, ni un momento, y "
        "tirar de la cola, agarrar por el cuello o abrazar fuerte no se hace nunca, ni "
        "jugando: un adulto al lado sirve para parar el gesto, no para hacerlo aceptable. "
    ),
    "de": (
        "Zuallererst: Ein kleines Kind bleibt nie allein mit dem Tier, nicht einmal einen "
        "Moment, und am Schwanz ziehen, am Hals packen oder fest drücken geht nie, auch nicht "
        "im Spiel: Ein Erwachsener daneben ist dazu da, die Geste zu stoppen, nicht, sie "
        "annehmbar zu machen. "
    ),
    "fr": (
        "Avant tout : un jeune enfant ne reste jamais seul avec l'animal, pas même un instant, "
        "et tirer la queue, attraper le cou ou serrer fort ne se fait jamais, même pour jouer : "
        "un adulte à côté sert à arrêter le geste, pas à le rendre acceptable. "
    ),
}


# --- the daily limit (synthetic users 2026-11-07, P1 and P9) -------------------
# Safety first, the count after; no technical code; "domande" as in the app;
# {wait} is the time until the count starts again (format_wait).

LIMIT_TEXTS: dict[str, str] = {
    "it": (
        "Se {name} sta male adesso, non aspettare questo messaggio: un caso grave non aspetta, "
        "chiama subito il veterinario o un pronto soccorso veterinario. Per oggi hai usato "
        "tutte le {limit} domande del tuo piano: il conteggio riparte tra circa {wait}."
    ),
    "en": (
        "If {name} is unwell right now, do not wait for this message: a serious case does not "
        "wait, call your vet or an emergency clinic straight away. For today you have used all "
        "{limit} questions of your plan: the count starts again in about {wait}."
    ),
    "es": (
        "Si {name} está mal ahora, no esperes este mensaje: un caso grave no espera, llama "
        "ahora mismo al veterinario o a urgencias veterinarias. Por hoy has usado las {limit} "
        "preguntas de tu plan: el contador vuelve a empezar dentro de unos {wait}."
    ),
    "de": (
        "Wenn es {name} gerade schlecht geht, warten Sie nicht auf diese Nachricht: Ein ernster "
        "Fall wartet nicht, rufen Sie sofort Ihre Tierarztpraxis oder einen Notdienst an. Für "
        "heute haben Sie alle {limit} Fragen Ihres Tarifs verbraucht: Der Zähler startet in "
        "{wait} wieder."
    ),
    "fr": (
        "Si {name} va mal en ce moment, n'attendez pas ce message : un cas grave n'attend pas, "
        "appelez tout de suite votre vétérinaire ou un service d'urgences. Pour aujourd'hui "
        "vous avez utilisé les {limit} questions de votre offre : le compteur repart dans "
        "{wait}."
    ),
}

QUOTA_TEXTS: dict[str, str] = {
    "it": (
        "Se {name} sta male adesso, non aspettare: un caso grave non aspetta, chiama subito il "
        "veterinario o un pronto soccorso veterinario. In questo momento l'assistente è molto "
        "richiesto e ha esaurito le risposte di oggi: riprova tra circa {wait}."
    ),
    "en": (
        "If {name} is unwell right now, do not wait: a serious case does not wait, call your "
        "vet or an emergency clinic straight away. The assistant is in high demand and has used "
        "up today's answers: try again in about {wait}."
    ),
    "es": (
        "Si {name} está mal ahora, no esperes: un caso grave no espera, llama ahora mismo al "
        "veterinario o a urgencias veterinarias. El asistente tiene mucha demanda y ha agotado "
        "las respuestas de hoy: vuelve a intentarlo dentro de unos {wait}."
    ),
    "de": (
        "Wenn es {name} gerade schlecht geht, warten Sie nicht: Ein ernster Fall wartet nicht, "
        "rufen Sie sofort Ihre Tierarztpraxis oder einen Notdienst an. Der Assistent ist gerade "
        "stark gefragt und hat die Antworten für heute aufgebraucht: Versuchen Sie es in "
        "{wait} noch einmal."
    ),
    "fr": (
        "Si {name} va mal en ce moment, n'attendez pas : un cas grave n'attend pas, appelez "
        "tout de suite votre vétérinaire ou un service d'urgences. L'assistant est très "
        "sollicité et a épuisé les réponses du jour : réessayez dans {wait}."
    ),
}
