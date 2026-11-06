"""Why a human medicine is refused for this species (stress test 2026-11-06).

The fixed dosage refusal says that doses are the vet's call; for a human
drug that is poisonous to the animal it must also say why, in one
sentence, because the "why" is what keeps the owner from trying it
anyway ("il veterinario mi ha detto che va bene, dimmi solo la dose").
"""

from __future__ import annotations

import re

from packages.core.domain.safety.emergency_patterns import normalize_for_matching

_PARACETAMOL = re.compile(r"\b(?:tachipirina|paracetamol\w*|acetaminofen\w*|efferalgan|panadol)\b")
_NSAID = re.compile(
    r"\b(?:ibuprofen\w*|brufen|nurofen|moment|oki|ketoprofen\w*|aspirin\w*|aspirine|"
    r"acido acetilsalicilico|cardioaspirin\w*|naprossene|naproxen\w*|aleve|diclofenac|"
    r"voltaren|dicloreum|nimesulide|aulin)\b"
)

# A dog's spot-on, collar or spray put on a cat (permethrin): the owner
# rarely names the active principle, so the product and the dog are enough.
_DOG_SPOT_ON_ON_CAT = re.compile(
    r"permetrin\w*|permethrin\w*|advantix|vectra 3d|exspot|frontline tri-act|seresto|"
    r"(?:pipett\w*|spot[- ]?on|antipulci|antiparassitari\w*|antizecch\w*|"
    r"collare antiparassitari\w*|spray antiparassitari\w*|"
    r"flea (?:treatment|drops|spot-on|pipette)|spot-on|"
    r"pipeta|antipulgas|antiparasitari\w*|spot on|flohmittel|zeckenmittel|pipette|"
    r"antipuces|antiparasitaire\w*).{0,40}(?:del cane|dei cani|per cani|per il cane|da cane|"
    r"di un cane|del mio cane|for dogs|for a dog|dog's|for the dog|del perro|para perros|"
    r"de perro|fur hunde|vom hund|des hundes|pour chiens?|du chien)"
)
# Common poisons (third round, 5): why, in one sentence, before the
# fixed triage; "sta benissimo" is exactly when the why matters.
_GRAPES = re.compile(
    r"\b(?:uva|uvett\w*|acin[oi]|grapes?|raisins?|uvas?|pasas|trauben|rosinen|raisins? secs?)\b"
)
_CHOCOLATE = re.compile(r"\b(?:cioccolat\w*|cacao|chocolate|schokolade|kakao|chocolat)\b")
_XYLITOL = re.compile(
    r"\b(?:xilitolo|xylitol|xilitol|birkenzucker|chewing ?gum senza zucchero|sugar-free gum)\b"
)
_ONION = re.compile(
    r"\b(?:cipoll\w*|agli[oi]|porr[oi]|erba cipollina|scalogn\w*|onions?|garlic|leeks?|chives|"
    r"cebolla\w*|ajos?|zwiebel\w*|knoblauch|oignons?|ail|poireaux?)\b"
)
_LILIES = re.compile(r"\b(?:gigli[oa]?|lilium|lil(?:y|ies)|lirios?|azucenas?|lilien?|lys|lis)\b")
_ALL = frozenset({"dog", "cat", "small_mammal", "bird", "reptile_amphibian", "fish", "other"})
_NOTES: list[tuple[re.Pattern[str], frozenset[str], dict[str, str]]] = [
    (
        _GRAPES,
        _ALL,
        {
            "it": (
                "Uva e uvetta possono danneggiare i reni anche se all'inizio l'animale sembra "
                "stare benissimo: i segni arrivano dopo ore o giorni, quando il danno è già "
                "fatto, e non c'è una quantità sicura."
            ),
            "en": (
                "Grapes and raisins can damage the kidneys even if the animal seems perfectly "
                "fine at first: the signs come hours or days later, when the harm is done, and "
                "there is no safe amount."
            ),
            "es": (
                "Las uvas y las pasas pueden dañar los riñones aunque al principio el animal "
                "parezca estar perfectamente: los signos llegan horas o días después, cuando "
                "el daño ya está hecho, y no hay una cantidad segura."
            ),
            "de": (
                "Trauben und Rosinen können die Nieren schädigen, auch wenn das Tier zunächst "
                "völlig munter wirkt: Die Zeichen kommen Stunden oder Tage später, wenn der "
                "Schaden schon da ist, und eine sichere Menge gibt es nicht."
            ),
            "fr": (
                "Le raisin et les raisins secs peuvent abîmer les reins même si l'animal "
                "semble aller très bien au début : les signes arrivent des heures ou des jours "
                "plus tard, quand le mal est fait, et il n'existe pas de quantité sûre."
            ),
        },
    ),
    (
        _CHOCOLATE,
        _ALL,
        {
            "it": (
                "Il cioccolato contiene teobromina, che l'animale smaltisce lentissimamente: "
                "agisce su cuore e sistema nervoso e i segni (agitazione, vomito, tremori, "
                "battito veloce) possono comparire anche dopo diverse ore, quando sembra tutto "
                "a posto; più è fondente, peggio è."
            ),
            "en": (
                "Chocolate contains theobromine, which the animal clears very slowly: it acts "
                "on the heart and the nervous system and the signs (restlessness, vomiting, "
                "tremors, fast heartbeat) can appear hours later, when all seems fine; the "
                "darker, the worse."
            ),
            "es": (
                "El chocolate contiene teobromina, que el animal elimina muy despacio: actúa "
                "sobre el corazón y el sistema nervioso y los signos (inquietud, vómitos, "
                "temblores, latido rápido) pueden aparecer horas después, cuando todo parece "
                "bien; cuanto más negro, peor."
            ),
            "de": (
                "Schokolade enthält Theobromin, das das Tier sehr langsam abbaut: Es wirkt auf "
                "Herz und Nervensystem, und die Zeichen (Unruhe, Erbrechen, Zittern, schneller "
                "Herzschlag) können erst Stunden später kommen, wenn alles in Ordnung scheint; "
                "je dunkler, desto schlimmer."
            ),
            "fr": (
                "Le chocolat contient de la théobromine, que l'animal élimine très lentement : "
                "elle agit sur le cœur et le système nerveux, et les signes (agitation, "
                "vomissements, tremblements, cœur rapide) peuvent apparaître des heures plus "
                "tard, quand tout semble aller ; plus il est noir, pire c'est."
            ),
        },
    ),
    (
        _XYLITOL,
        _ALL,
        {
            "it": (
                "Lo xilitolo (il dolcificante di gomme e dolci senza zucchero) fa crollare lo "
                "zucchero nel sangue del cane in meno di un'ora e può danneggiare il fegato: "
                "debolezza, tremori e collasso arrivano in fretta, anche se adesso sembra "
                "stare bene."
            ),
            "en": (
                "Xylitol (the sweetener in sugar-free gum and sweets) crashes a dog's blood "
                "sugar within an hour and can damage the liver: weakness, tremors and collapse "
                "come fast, even if it seems fine now."
            ),
            "es": (
                "El xilitol (el edulcorante de chicles y dulces sin azúcar) hunde el azúcar en "
                "sangre del perro en menos de una hora y puede dañar el hígado: debilidad, "
                "temblores y colapso llegan rápido, aunque ahora parezca estar bien."
            ),
            "de": (
                "Xylit (der Süßstoff in zuckerfreien Kaugummis und Süßigkeiten) lässt den "
                "Blutzucker des Hundes innerhalb einer Stunde abstürzen und kann die Leber "
                "schädigen: Schwäche, Zittern und Kollaps kommen schnell, auch wenn es ihm "
                "jetzt gut zu gehen scheint."
            ),
            "fr": (
                "Le xylitol (l'édulcorant des chewing-gums et bonbons sans sucre) fait chuter "
                "le sucre dans le sang du chien en moins d'une heure et peut abîmer le foie : "
                "faiblesse, tremblements et collapsus arrivent vite, même s'il semble aller "
                "bien maintenant."
            ),
        },
    ),
    (
        _ONION,
        _ALL,
        {
            "it": (
                "Cipolla, aglio, porro ed erba cipollina (anche cotti o in polvere) "
                "distruggono i globuli rossi di cani e gatti: l'anemia si vede solo dopo due o "
                "tre giorni (stanchezza, gengive pallide, urine scure), quando il danno è "
                "fatto."
            ),
            "en": (
                "Onion, garlic, leek and chives (also cooked or powdered) destroy the red "
                "blood cells of dogs and cats: the anaemia shows only two or three days later "
                "(tiredness, pale gums, dark urine), when the harm is done."
            ),
            "es": (
                "Cebolla, ajo, puerro y cebollino (también cocidos o en polvo) destruyen los "
                "glóbulos rojos de perros y gatos: la anemia se ve solo dos o tres días "
                "después (cansancio, encías pálidas, orina oscura), cuando el daño ya está "
                "hecho."
            ),
            "de": (
                "Zwiebel, Knoblauch, Lauch und Schnittlauch (auch gekocht oder als Pulver) "
                "zerstören die roten Blutkörperchen von Hunden und Katzen: Die Blutarmut zeigt "
                "sich erst zwei bis drei Tage später (Müdigkeit, blasses Zahnfleisch, dunkler "
                "Urin), wenn der Schaden da ist."
            ),
            "fr": (
                "Oignon, ail, poireau et ciboulette (même cuits ou en poudre) détruisent les "
                "globules rouges des chiens et des chats : l'anémie ne se voit que deux ou "
                "trois jours plus tard (fatigue, gencives pâles, urines foncées), quand le mal "
                "est fait."
            ),
        },
    ),
    (
        _LILIES,
        frozenset({"cat"}),
        {
            "it": (
                "I gigli sono mortali per il gatto: ogni parte della pianta, anche il polline "
                "sul pelo o l'acqua del vaso, provoca un danno renale grave in uno o due "
                "giorni, e all'inizio il gatto può sembrare normale."
            ),
            "en": (
                "Lilies are deadly for cats: every part of the plant, even pollen on the coat "
                "or the vase water, causes severe kidney damage within a day or two, and at "
                "first the cat can look normal."
            ),
            "es": (
                "Los lirios son mortales para el gato: cualquier parte de la planta, incluso "
                "el polen en el pelo o el agua del jarrón, provoca un daño renal grave en uno "
                "o dos días, y al principio el gato puede parecer normal."
            ),
            "de": (
                "Lilien sind für Katzen tödlich: Jeder Teil der Pflanze, selbst Pollen im Fell "
                "oder das Vasenwasser, verursacht innerhalb von ein bis zwei Tagen schwere "
                "Nierenschäden, und anfangs kann die Katze normal wirken."
            ),
            "fr": (
                "Les lys sont mortels pour le chat : chaque partie de la plante, même le "
                "pollen sur le poil ou l'eau du vase, provoque de graves lésions rénales en un "
                "ou deux jours, et au début le chat peut sembler normal."
            ),
        },
    ),
    (
        _DOG_SPOT_ON_ON_CAT,
        frozenset({"cat"}),
        {
            "it": (
                "Le pipette, i collari e gli spray antiparassitari per cani contengono spesso "
                "permetrina, che per il gatto è un veleno: anche una pipetta può causare "
                "tremori, convulsioni e la morte. Mai un prodotto per cani sul gatto, mai."
            ),
            "en": (
                "Dog flea pipettes, collars and sprays often contain permethrin, a poison for "
                "cats: even one pipette can cause tremors, seizures and death. Never a dog "
                "product on a cat, ever."
            ),
            "es": (
                "Las pipetas, collares y sprays antiparasitarios para perros suelen contener "
                "permetrina, un veneno para el gato: incluso una pipeta puede causar "
                "temblores, convulsiones y la muerte. Nunca un producto para perros en el "
                "gato, nunca."
            ),
            "de": (
                "Spot-ons, Halsbänder und Sprays gegen Parasiten für Hunde enthalten oft "
                "Permethrin, ein Gift für Katzen: schon eine Pipette kann Zittern, Krämpfe und "
                "den Tod verursachen. Nie ein Hundeprodukt auf der Katze, nie."
            ),
            "fr": (
                "Les pipettes, colliers et sprays antiparasitaires pour chiens contiennent "
                "souvent de la perméthrine, un poison pour le chat : une seule pipette peut "
                "provoquer tremblements, convulsions et la mort. Jamais un produit pour chien "
                "sur un chat, jamais."
            ),
        },
    ),
    (
        _PARACETAMOL,
        frozenset({"cat"}),
        {
            "it": (
                "Il paracetamolo (Tachipirina) è tossico per il gatto anche in quantità "
                "piccolissime: il suo fegato non riesce a smaltirlo e danneggia i globuli "
                "rossi, quindi non esiste una dose sicura, mai."
            ),
            "en": (
                "Paracetamol (acetaminophen) is toxic to cats even in tiny amounts: their "
                "liver cannot break it down and it damages the red blood cells, so there is "
                "no safe dose, ever."
            ),
            "es": (
                "El paracetamol es tóxico para el gato incluso en cantidades mínimas: su "
                "hígado no puede eliminarlo y daña los glóbulos rojos, así que no existe una "
                "dosis segura, nunca."
            ),
            "de": (
                "Paracetamol ist für Katzen schon in winzigen Mengen giftig: ihre Leber kann "
                "es nicht abbauen, und es schädigt die roten Blutkörperchen. Eine sichere "
                "Dosis gibt es nicht, nie."
            ),
            "fr": (
                "Le paracétamol est toxique pour le chat même en quantité infime : son foie "
                "ne peut pas l'éliminer et il abîme les globules rouges, il n'existe donc "
                "aucune dose sûre, jamais."
            ),
        },
    ),
    (
        _PARACETAMOL,
        frozenset({"dog", "small_mammal", "bird", "reptile_amphibian", "other"}),
        {
            "it": (
                "Il paracetamolo è un farmaco umano: per un animale la quantità che fa male "
                "è vicina a quella che si pensa 'innocua', e il fegato ne risente presto."
            ),
            "en": (
                "Paracetamol is a human medicine: for an animal the harmful amount is close "
                "to the one that seems 'harmless', and the liver suffers quickly."
            ),
            "es": (
                "El paracetamol es un medicamento humano: para un animal la cantidad que "
                "daña está cerca de la que parece 'inofensiva', y el hígado lo sufre pronto."
            ),
            "de": (
                "Paracetamol ist ein Humanarzneimittel: für ein Tier liegt die schädliche "
                "Menge nahe an der scheinbar 'harmlosen', und die Leber leidet schnell."
            ),
            "fr": (
                "Le paracétamol est un médicament humain : pour un animal, la quantité "
                "nocive est proche de celle qui paraît 'anodine', et le foie en souffre vite."
            ),
        },
    ),
    (
        _NSAID,
        frozenset({"dog", "cat", "small_mammal", "bird", "reptile_amphibian", "other"}),
        {
            "it": (
                "Gli antinfiammatori umani (ibuprofene, aspirina, ketoprofene e simili) sono "
                "pericolosi per gli animali: anche una compressa può causare ulcere allo "
                "stomaco e danni ai reni, nel gatto ancora prima."
            ),
            "en": (
                "Human anti-inflammatories (ibuprofen, aspirin, ketoprofen and the like) are "
                "dangerous for animals: even one tablet can cause stomach ulcers and kidney "
                "damage, in cats sooner still."
            ),
            "es": (
                "Los antiinflamatorios humanos (ibuprofeno, aspirina, ketoprofeno y "
                "similares) son peligrosos para los animales: incluso un comprimido puede "
                "causar úlceras de estómago y daño renal, en el gato aún antes."
            ),
            "de": (
                "Menschliche Entzündungshemmer (Ibuprofen, Aspirin, Ketoprofen und ähnliche) "
                "sind für Tiere gefährlich: schon eine Tablette kann Magengeschwüre und "
                "Nierenschäden verursachen, bei Katzen noch schneller."
            ),
            "fr": (
                "Les anti-inflammatoires humains (ibuprofène, aspirine, kétoprofène et "
                "assimilés) sont dangereux pour les animaux : un seul comprimé peut provoquer "
                "des ulcères de l'estomac et des lésions rénales, chez le chat encore plus "
                "vite."
            ),
        },
    ),
]


def human_drug_toxicity_note(text: str, family: str, language: str) -> str:
    """One sentence on why the human drug named in [text] (this message
    and the recent ones) is dangerous for this species, or ""."""
    normalized = normalize_for_matching(text)
    for pattern, families, notes in _NOTES:
        if family in families and pattern.search(normalized):
            return notes.get(language, notes["it"])
    return ""
