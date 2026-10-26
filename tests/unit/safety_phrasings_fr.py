"""Realistic French phrasings of emergencies an owner may type (2026-10-26):
the equivalent of safety_phrasings.py, same groups, same counts (56
emergencies, 15 dose requests, 20 ordinary messages). Written the way
owners write: capitals, accents or not, typos, no punctuation."""

# (species, message) — species as the profile stores it.
RODENTICIDE: tuple[tuple[str, str], ...] = (
    ("Chien", "Mon chien a mangé de la mort-aux-rats"),
    ("Chien", "il a mangé du poison pour les rats dans le garage"),
    ("Chien", "je crois qu'il a avalé du raticide"),
    ("Chien", "IL A MANGÉ LES APPÂTS POUR LES SOURIS !!!"),
    ("Chien", "il a mordillé un bloc bleu contre les rats"),
    ("Chien", "je l'ai trouvé en train de manger du poison pour rats"),
    ("Chien", "il a léché le raticide que j'avais mis à la cave"),
    ("Chien", "il a mange de la mort aux rats"),
    ("Chat", "il a peut-être mangé l'appât pour les souris du voisin"),
    ("Chien", "il a ingéré du rodenticide"),
    ("Chat", "il a mangé une souris empoisonnée"),
    ("Chien", "les appâts anti-rats étaient ouverts et il en manque un"),
)

ANTIFREEZE: tuple[tuple[str, str], ...] = (
    ("Chat", "le chat a léché de l'antigel dans le garage"),
    ("Chien", "il a bu de l'antigel"),
    ("Chien", "il a léché le liquide de refroidissement de la voiture"),
    ("Chat", "je crois qu'il a bu de l'éthylène glycol"),
    ("Chien", "il a léché une flaque verte sous la voiture, peut-être de l'antigel"),
    ("Chien", "ANTIGEL !! il l'a léché"),
    ("Chien", "il a bu le liquide du radiateur"),
    ("Chat", "il a léché de l'anti-gel"),
    ("Chien", "il a bu du lave-glace antigel"),
    ("Chat", "il a léché du glycol"),
    ("Chien", "il a bu un peu de liquide antigel"),
)

LILIES: tuple[tuple[str, str], ...] = (
    ("Chat", "le chat a mangé une feuille de lys"),
    ("Chat", "il a mâché les lis du bouquet"),
    ("Chat", "il a léché le pollen du lilium"),
    ("Chat", "il a mordu un lilium"),
    ("Chat", "il a mangé un bout de lys"),
    ("Chat", "j'ai des lys à la maison et il a mangé un pétale"),
    ("Chat", "LYS : il a mangé une fleur"),
    ("Chat", "il a bu l'eau du vase des lys"),
    ("Chat", "il a le museau plein de pollen orange des lys"),
    ("Chat", "il a mangé un lys de la maison"),
    ("Chat", "il a mâchouillé une hémérocalle du jardin"),
)

BLOAT: tuple[tuple[str, str], ...] = (
    ("Chien", "le ventre est gonflé et dur et il essaie de vomir mais rien ne sort"),
    ("Chien", "il a le ventre super gonflé"),
    ("Chien", "ventre gonflé après le repas et des haut-le-cœur à vide"),
    ("Chien", "je crois qu'il fait une torsion de l'estomac"),
    ("Chien", "torsion d'estomac ?"),
    ("Chien", "il a l'abdomen gonflé et bave énormément"),
    ("Chien", "il essaie de vomir à vide depuis une demi-heure"),
    ("Chien", "des haut-le-cœur sans vomir et le ventre tendu"),
    ("Chien", "il a le ventre dur comme un tambour"),
    ("Chien", "dilatation de l'estomac, c'est un dogue"),
    ("Chien", "VENTRE GONFLÉ et il n'arrive pas à vomir"),
)

GUMS: tuple[tuple[str, str], ...] = (
    ("Chien", "il a les gencives pâles"),
    ("Chat", "les gencives sont blanches"),
    ("Chien", "les gencives sont bleuâtres"),
    ("Chat", "il a les gencives bleues"),
    ("Chien", "gencives grises et il respire vite"),
    ("Chien", "les muqueuses sont pâles"),
    ("Chien", "GENCIVES TOUTES BLANCHES"),
    ("Chien", "il a la langue violette"),
    ("Chat", "la langue est bleuâtre"),
    ("Chien", "gencives pales et il est tout mou"),
    ("Chien", "je lui ai regardé les gencives et elles sont presque blanches"),
)

EMERGENCIES: dict[str, tuple[tuple[str, str], ...]] = {
    "rodenticidi": RODENTICIDE,
    "antigelo": ANTIFREEZE,
    "gigli (gatto)": LILIES,
    "torsione/pancia gonfia": BLOAT,
    "gengive pallide/blu": GUMS,
}

DOSAGE: tuple[tuple[str, str], ...] = (
    ("Chien", "combien de Doliprane je peux donner au chien ?"),
    ("Chien", "combien de mg de Metacam pour un chien de 20 kg"),
    ("Chien", "combien de gouttes de Dafalgan je peux lui donner ?"),
    ("Chien", "je peux lui donner un demi-comprimé d'aspirine ?"),
    ("Chien", "quelle dose d'antibiotique je lui donne ?"),
    ("Chien", "combien de Rimadyl je dois donner ?"),
    ("Chien", "tous les combien je lui donne l'antidouleur et combien ?"),
    ("Chien", "combien de comprimés de Previcox par jour ?"),
    ("Chat", "quelle est la posologie du méloxicam pour un chat"),
    ("Chien", "je peux lui donner un quart de comprimé d'Advil ?"),
    ("Chien", "combien de ml de sirop pour la toux je peux donner"),
    ("Chien", "combien de cortisone je peux lui donner"),
    ("Chien", "posologie de l'amoxicilline pour chien de 10 kg"),
    ("Chien", "je peux doubler la dose du médicament ?"),
    ("Chien", "combien de comprimés de vermifuge je lui donne"),
)

# Ordinary messages that must NOT trigger an emergency (false-alarm check).
ORDINARY: tuple[tuple[str, str], ...] = (
    ("Chien", "pourquoi il mâche les chaussures ?"),
    ("Chat", "j'ai acheté des fleurs pour l'anniversaire de ma mère"),
    ("Chien", "on a vu une souris dans le jardin, le chien lui courait après"),
    ("Chien", "il a le ventre plein après la gamelle et il dort"),
    ("Chien", "les gencives sont roses et il va très bien"),
    ("Chat", "il s'appelle Lys, c'est un chat blanc"),
    ("Chien", "la voiture a perdu un peu d'huile, le chien est à la maison"),
    ("Chien", "combien il doit manger par jour ?"),
    ("Chien", "le vétérinaire lui a prescrit du Metacam, ça sert à quoi ?"),
    ("Chat", "combien de fois par jour joue un chat normalement ?"),
    # Written against the edges of the rules, not alongside them.
    ("Chat", "il a des haut-le-cœur et puis il recrache une boule de poils"),
    ("Chat", "il essaie de vomir après avoir mangé de l'herbe"),
    ("Chat", "il a le ventre gonflé mais il mange et il joue"),
    ("Chien", "combien coûte le Metacam en pharmacie ?"),
    ("Chien", "combien de temps dure l'effet de l'antibiotique ?"),
    ("Chien", "combien de doses de vaccin doit faire le chiot ?"),
    ("Chien", "combien de croquettes je lui donne par repas ?"),
    ("Chien", "la langue est rose et les gencives normales"),
    ("Chat", "on a des lys dans le jardin, le chat ne sort jamais"),
    ("Chien", "je dois mettre de l'antigel dans la voiture, où je le range loin du chien ?"),
)
