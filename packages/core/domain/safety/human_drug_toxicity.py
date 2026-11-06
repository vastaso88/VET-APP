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
_NOTES: list[tuple[re.Pattern[str], frozenset[str], dict[str, str]]] = [
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
