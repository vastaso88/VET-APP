from packages.core.application.services.safety_gate import SafetyGate


def test_safety_gate_flags_red_flag_keywords() -> None:
    gate = SafetyGate()

    flags = gate.evaluate("Il cane ha avuto un collasso improvviso")

    assert flags


def test_safety_gate_is_case_insensitive() -> None:
    gate = SafetyGate()

    flags = gate.evaluate("IL GATTO NON RESPIRA BENE")

    assert flags


def test_safety_gate_returns_empty_list_for_ordinary_messages() -> None:
    gate = SafetyGate()

    flags = gate.evaluate("Il mio cane mangia poco da stamattina")

    assert flags == []


def test_safety_gate_flags_blood_in_vomit_or_stool() -> None:
    # Real-world finding: an owner reporting "vomito con sangue" (blood in
    # vomit) is a genuine red flag that the previous keyword list ("emorrag",
    # "sanguina") didn't catch at all.
    gate = SafetyGate()

    assert gate.evaluate("Ha avuto un episodio di vomito con sangue ieri sera")
    assert gate.evaluate("Ho notato sangue nelle feci stamattina")


def test_safety_gate_does_not_flag_routine_bloodwork_mentions() -> None:
    # The bare word "sangue" is deliberately NOT a keyword on its own: it
    # would also match calm, already-reassuring statements about normal
    # bloodwork, wrongly escalating them into urgent triage.
    gate = SafetyGate()

    flags = gate.evaluate(
        "Abbiamo fatto le analisi del sangue e sono tutte nella norma, nessun problema"
    )

    assert flags == []


def test_flags_anorexia_and_no_stool_for_small_mammals_but_not_dogs() -> None:
    # Real-world finding: a rabbit/guinea pig not eating and not producing
    # stool for a day is a genuine emergency (GI stasis) — but the same
    # phrase for a dog is ordinarily just something to monitor, so it must
    # not be flagged as urgent for the "dog" family.
    gate = SafetyGate()
    message = "Il mio coniglio non mangia da un giorno e non fa la cacca"

    assert gate.evaluate(message, species="Piccoli mammiferi")
    assert gate.evaluate(message, species="small_mammal")
    assert gate.evaluate(message, species="dog") == []


def test_flags_reptile_prolapse_but_not_ordinary_lethargy() -> None:
    # Prolapse is an unambiguous reptile emergency. Ordinary lethargy is
    # deliberately NOT flagged: it can be normal (brumation, shedding, a
    # cold enclosure), and treating it as urgent would manufacture anxiety
    # over normal physiology.
    gate = SafetyGate()

    assert gate.evaluate("Ha un prolasso evidente", species="Rettili e anfibi")
    assert gate.evaluate("È molto letargico da qualche giorno", species="Rettili e anfibi") == []


def test_flags_bird_unable_to_perch() -> None:
    gate = SafetyGate()

    assert gate.evaluate(
        "Non riesce a stare sul trespolo e sta fermo", species="Uccello"
    )


def test_universal_red_flags_still_apply_to_every_species() -> None:
    gate = SafetyGate()

    for species in ("dog", "Piccoli mammiferi", "Rettili e anfibi", "Uccello", "Pesce"):
        assert gate.evaluate("Ha avuto delle convulsioni", species=species)


def test_flags_dog_only_flea_treatment_given_to_a_cat() -> None:
    # Real-world finding: "ho messo una goccia di advantix al mio gatto"
    # (a dog-only permethrin spot-on, genuinely lethal to cats even in
    # small amounts) was treated as a routine question. Advantix is not
    # dangerous for dogs — it's formulated for them — so it must not be
    # flagged for that species.
    gate = SafetyGate()

    assert gate.evaluate("Ho messo una goccia di advantix al mio gatto", species="Gatto")
    assert gate.evaluate("Quante gocce di advantix devo dare al mio gatto?", species="cat")
    assert gate.evaluate("Uso l'advantix sul mio cane ogni mese", species="dog") == []


def test_flags_paracetamol_brand_name_for_cats() -> None:
    # Real-world finding: owners commonly say the Italian brand name
    # ("Tachipirina") rather than the generic name — a check that only
    # recognized "paracetamolo" would miss this extremely common phrasing.
    gate = SafetyGate()

    assert gate.evaluate(
        "Vorrei dare la tachipirina al mio gatto che ha la febbre", species="Gatto"
    )


def test_flags_common_italian_nsaid_brand_names_for_both_cats_and_dogs() -> None:
    # Real-world finding (round 2): Italian owners reach for the brand
    # name on whatever is in the medicine cabinet, not just paracetamol —
    # the same gap exists for every common human NSAID/analgesic brand.
    gate = SafetyGate()

    for species in ("Gatto", "Cane"):
        assert gate.evaluate("Posso dare del brufen al mio animale?", species=species)
        assert gate.evaluate("Gli ho dato una bustina di oki ieri sera", species=species)
        assert gate.evaluate("Ha preso dell'aspirina per errore", species=species)
        assert gate.evaluate(
            "Gli ho messo un po' di voltaren sulla zampa che zoppica", species=species
        )


def test_flags_other_permethrin_dog_spot_ons_given_to_cats() -> None:
    # Advantix isn't the only dog-only permethrin product on the Italian
    # market — Vectra 3D and Exspot are others an owner might have on hand.
    gate = SafetyGate()

    assert gate.evaluate("Ho usato il vectra sul mio gatto per sbaglio", species="Gatto")
    assert gate.evaluate("Posso usare l'exspot del cane anche sul gatto?", species="cat")


def test_flags_nsaids_and_dangerous_antibiotics_for_small_mammals() -> None:
    # Real-world finding (round 3, stress test): medication-safety
    # coverage stopped at cat/dog, so "posso dare l'aspirina al mio
    # coniglio?" raised no flag at all. Rabbits/guinea pigs/chinchillas
    # also have a distinct, more severe risk from certain oral
    # antibiotics (fatal enterotoxemia) that cats/dogs don't share.
    gate = SafetyGate()

    assert gate.evaluate(
        "Posso dare un po' di aspirina al mio coniglio?", species="Piccoli mammiferi"
    )
    assert gate.evaluate(
        "Gli ho dato dell'amoxicillina che avevo in casa", species="small_mammal"
    )


def test_flags_permethrin_spot_ons_for_birds_too() -> None:
    gate = SafetyGate()

    assert gate.evaluate("Ho messo dell'advantix del cane anche sul canarino", species="Uccello")


def test_does_not_flag_a_legitimate_vet_prescribed_medication() -> None:
    # Real-world finding (round 3): a genuinely vet-prescribed, properly
    # dosed medication (Rimadyl/carprofen, a real canine NSAID) must not
    # trigger a false alarm — the danger is specifically unsupervised
    # human OTC medication, not veterinary medicine itself.
    gate = SafetyGate()

    flags = gate.evaluate(
        "Il veterinario mi ha prescritto del Rimadyl dopo l'operazione", species="Cane"
    )

    assert flags == []


def test_does_not_flag_moment_due_to_common_word_collision() -> None:
    # "Moment" (a very common ibuprofen brand) is deliberately NOT in the
    # keyword list: as a bare substring it collides with "momento"/"al
    # momento", extremely common phrasing that must never trigger a false
    # poisoning alarm. This test guards against it being re-added later.
    gate = SafetyGate()

    flags = gate.evaluate(
        "Al momento non ha altri sintomi, sta tranquillo", species="Gatto"
    )

    assert flags == []
