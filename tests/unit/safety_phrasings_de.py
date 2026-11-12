"""Realistic German phrasings of emergencies an owner may type (2026-10-26):
the equivalent of safety_phrasings.py, same groups, same counts (56
emergencies, 15 dose requests, 20 ordinary messages). Written the way
owners write: capitals, umlauts or not, typos, no punctuation."""

# (species, message) — species as the profile stores it.
RODENTICIDE: tuple[tuple[str, str], ...] = (
    ("Hund", "Mein Hund hat Rattengift gefressen"),
    ("Hund", "er hat in der Garage Mäusegift gefressen"),
    ("Hund", "ich glaube er hat das Rodentizid verschluckt"),
    ("Hund", "HAT DIE GIFTKÖDER FÜR MÄUSE GEFRESSEN!!!"),
    ("Hund", "hat einen blauen Köder gegen Ratten angeknabbert"),
    ("Hund", "ich hab ihn erwischt wie er Rattengift gefressen hat"),
    ("Hund", "er hat das Rattengift im Keller abgeleckt"),
    ("Hund", "hat rattengift gefressen ohne dass ich es gesehen habe"),
    ("Katze", "könnte den Mäuseköder vom Nachbarn gefressen haben"),
    ("Hund", "er hat Rodentizid aufgenommen"),
    ("Katze", "hat eine vergiftete Maus gefressen"),
    ("Hund", "die Köder gegen Mäuse waren offen und einer fehlt"),
)

ANTIFREEZE: tuple[tuple[str, str], ...] = (
    ("Katze", "die Katze hat in der Garage Frostschutzmittel geleckt"),
    ("Hund", "hat Frostschutz getrunken"),
    ("Hund", "hat die Kühlflüssigkeit vom Auto abgeleckt"),
    ("Katze", "ich glaube sie hat Ethylenglykol getrunken"),
    ("Hund", "hat eine grüne Pfütze unter dem Auto geleckt, vielleicht Frostschutz"),
    ("Hund", "FROSTSCHUTZMITTEL!! er hat es geleckt"),
    ("Hund", "hat das Kühlwasser vom Auto getrunken"),
    ("Katze", "hat Frostschutzmittel abgeleckt"),
    ("Hund", "hat den Scheibenfrostschutz getrunken"),
    ("Katze", "hat Glykol geleckt"),
    ("Hund", "hat etwas Kühlerflüssigkeit getrunken"),
)

LILIES: tuple[tuple[str, str], ...] = (
    ("Katze", "die Katze hat ein Lilienblatt gefressen"),
    ("Katze", "hat an den Lilien vom Blumenstrauß gekaut"),
    ("Katze", "hat den Pollen der Lilie abgeleckt"),
    ("Katze", "hat in eine Lilie gebissen"),
    ("Katze", "hat ein Stück Lilie gefressen"),
    ("Katze", "ich habe Lilien zu Hause und sie hat ein Blütenblatt gefressen"),
    ("Katze", "LILIEN: sie hat eine Blüte gefressen"),
    ("Katze", "hat das Wasser aus der Lilienvase getrunken"),
    ("Katze", "hat orangen Lilienpollen im Gesicht und hat sich geleckt"),
    ("Katze", "hat eine Lilie aus dem Garten gefressen"),
    ("Katze", "hat an einer Taglilie geknabbert"),
)

BLOAT: tuple[tuple[str, str], ...] = (
    ("Hund", "der Bauch ist aufgebläht und hart und er versucht zu erbrechen aber es kommt nichts"),
    ("Hund", "sein Bauch ist total aufgebläht"),
    ("Hund", "aufgeblähter Bauch nach dem Fressen und würgt ohne Erbrechen"),
    ("Hund", "ich glaube er hat eine Magendrehung"),
    ("Hund", "Magendrehung?"),
    ("Hund", "hat einen aufgetriebenen Bauch und sabbert extrem"),
    ("Hund", "würgt seit einer halben Stunde ohne dass was kommt"),
    ("Hund", "leeres Würgen und der Bauch ist gespannt"),
    ("Hund", "sein Bauch ist hart wie eine Trommel"),
    ("Hund", "Magenaufblähung, er ist eine Dogge"),
    ("Hund", "BAUCH AUFGEBLÄHT und er kann nicht erbrechen"),
)

GUMS: tuple[tuple[str, str], ...] = (
    ("Hund", "hat blasses Zahnfleisch"),
    ("Katze", "das Zahnfleisch ist weiß"),
    ("Hund", "das Zahnfleisch ist bläulich"),
    ("Katze", "hat blaues Zahnfleisch"),
    ("Hund", "graues Zahnfleisch und atmet schnell"),
    ("Hund", "die Schleimhäute sind blass"),
    ("Hund", "ZAHNFLEISCH GANZ WEISS"),
    ("Hund", "hat eine lila Zunge"),
    ("Katze", "die Zunge ist bläulich"),
    ("Hund", "Zahnfleisch blaß"),
    ("Hund", "ich hab ihm ins Maul geschaut und das Zahnfleisch ist fast weiß"),
)

EMERGENCIES: dict[str, tuple[tuple[str, str], ...]] = {
    "rodenticidi": RODENTICIDE,
    "antigelo": ANTIFREEZE,
    "gigli (gatto)": LILIES,
    "torsione/pancia gonfia": BLOAT,
    "gengive pallide/blu": GUMS,
}

DOSAGE: tuple[tuple[str, str], ...] = (
    ("Hund", "wie viel Paracetamol darf ich dem Hund geben?"),
    ("Hund", "wie viele mg Metacam für einen 20 kg Hund"),
    ("Hund", "wie viele Tropfen Novalgin kann ich ihm geben?"),
    ("Hund", "kann ich ihm eine halbe Tablette Aspirin geben?"),
    ("Hund", "welche Dosis Antibiotikum gebe ich ihm?"),
    ("Hund", "wie viel Rimadyl muss ich geben?"),
    ("Hund", "wie oft gebe ich ihm das Schmerzmittel und wie viel?"),
    ("Hund", "wie viele Tabletten Previcox am Tag?"),
    ("Katze", "wie ist die Dosierung von Meloxicam für eine Katze"),
    ("Hund", "kann ich ihm eine viertel Tablette Ibuprofen geben?"),
    ("Hund", "wie viel ml Hustensaft kann ich geben"),
    ("Hund", "wie viel Kortison darf ich ihm geben"),
    ("Hund", "Dosierung von Amoxicillin für Hund 10 kg"),
    ("Hund", "kann ich die Dosis vom Medikament verdoppeln?"),
    ("Hund", "wie viele Tabletten Wurmkur gebe ich ihm"),
)

# Ordinary messages that must NOT trigger an emergency (false-alarm check).
ORDINARY: tuple[tuple[str, str], ...] = (
    ("Hund", "warum kaut er auf Schuhen herum?"),
    ("Katze", "ich habe Blumen zum Geburtstag meiner Mutter gekauft"),
    ("Hund", "wir haben eine Maus im Garten gesehen, der Hund ist ihr nachgelaufen"),
    ("Hund", "hat einen vollen Bauch nach dem Futter und schläft"),
    ("Hund", "das Zahnfleisch ist rosa und es geht ihm super"),
    ("Katze", "sie heißt Lilie und ist eine weiße Katze"),
    ("Hund", "das Auto hat etwas Öl verloren, der Hund ist im Haus"),
    ("Hund", "wie viel soll er am Tag fressen?"),
    ("Hund", "der Tierarzt hat Metacam verschrieben, wofür ist das?"),
    ("Katze", "wie oft am Tag spielt eine Katze normalerweise?"),
    # Written against the edges of the rules, not alongside them.
    ("Katze", "würgt und bringt dann einen Haarballen raus"),
    ("Katze", "versucht zu erbrechen nachdem sie Gras gefressen hat"),
    ("Katze", "hat einen dicken Bauch aber frisst und spielt"),
    ("Hund", "was kostet Metacam in der Apotheke?"),
    ("Hund", "wie lange wirkt das Antibiotikum?"),
    ("Hund", "wie viele Impfdosen braucht der Welpe?"),
    ("Hund", "wie viele Kroketten gebe ich ihm pro Mahlzeit?"),
    ("Hund", "die Zunge ist rosa und das Zahnfleisch normal"),
    ("Katze", "wir haben Lilien im Garten, die Katze geht nie raus"),
    ("Hund", "ich muss Frostschutz ins Auto füllen, wo bewahre ich es sicher vor dem Hund auf?"),
)
