"""Synthetic users, round 3 (2026-11-16): the 40 cases of
`.local/synthetic_users/giro3/nuovi_scenari.md`, as permanent scenarios.

Sixteen invented owners, mostly of exotic animals, found where the chat goes wrong
(report `.local/synthetic_users/giro3/report.md`). Each scenario keeps the case id
of that file (S01-S40) in its own id.

Every clinical point in `expected` is marked [VET] when it still waits for a
veterinarian's review (docs/product/12, group P): the judge reads it as the
behaviour asked for, not as a verified fact. The regexes check only what needs no
clinical judgement (a wrong generic gesture, a fixed text that should not appear,
a refusal that should not come). Everything here is invented.
"""

from __future__ import annotations

from scenarios import Pet, Scenario, Turn

GIRO3_PETS: dict[str, Pet] = {
    pet.key: pet
    for pet in (
        Pet(
            key="caruso",
            name="Caruso",
            species="Uccello",
            breed="Canarino",
            age_years=5,
            sex="Maschio",
            weight_label="22 g",
        ),
        Pet(
            key="poppy",
            name="Poppy",
            species="Uccello",
            breed="Calopsite",
            age_years=2,
            sex="Femmina",
            weight_label="85 g",
            notes="Vive in gabbia grande in soggiorno, esce ogni giorno.",
        ),
        Pet(
            key="gigi",
            name="Gigi",
            species="Uccello",
            breed="Pappagallo cenerino",
            age_years=30,
            sex="Maschio",
            weight_label="430 g",
        ),
        Pet(
            key="wooper",
            name="Wooper",
            species="Rettili e anfibi",
            breed="Axolotl",
            age_years=2,
            sex="Maschio",
            weight_label="140 g",
            notes="Vasca da 60 litri senza riscaldatore.",
        ),
        Pet(
            key="chompy",
            name="Chompy",
            species="Rettili e anfibi",
            breed="Camaleonte velato",
            age_years=1,
            sex="Maschio",
            weight_label="90 g",
        ),
        Pet(
            key="sheldon",
            name="Sheldon",
            species="Rettili e anfibi",
            breed="Tartaruga d'acqua (Trachemys)",
            age_years=6,
            sex="Maschio",
            weight_label="600 g",
        ),
        Pet(
            key="gamera",
            name="Gamera",
            species="Rettili e anfibi",
            breed="Testudo hermanni",
            age_years=8,
            sex="Femmina",
            weight_label="870 g",
            notes="Vive in giardino, va in letargo.",
        ),
        Pet(
            key="neve",
            name="Neve",
            species="Piccoli mammiferi",
            breed="Cincillà",
            age_years=4,
            sex="Femmina",
            weight_label="560 g",
        ),
        Pet(
            key="bola",
            name="Bola",
            species="Pesce",
            breed="Betta splendens",
            age_years=1,
            sex="Maschio",
            habitat_liters=20,
        ),
        Pet(
            key="reef",
            name="Reef di casa",
            species="Pesce",
            habitat_liters=250,
            aquarium_stock=(("Pesce pagliaccio", 2, 2), ("Pesce chirurgo blu", 1, 1)),
            notes="Acquario marino con coralli molli e LPS, pompa di movimento e schiumatoio.",
        ),
        Pet(
            key="vasca20",
            name="Vasca grande",
            species="Pesce",
            habitat_liters=160,
            aquarium_stock=(("Neon", 10, 10), ("Guppy", 6, 6), ("Corydoras", 4, 4)),
            notes="Acqua dolce, filtro esterno, piante vere.",
        ),
        Pet(
            key="artu",
            name="Artù",
            species="Gatto",
            breed="Europeo",
            age_years=8,
            sex="Maschio castrato",
            weight_label="5,2 kg",
        ),
        Pet(
            key="bruno",
            name="Bruno",
            species="Cane",
            breed="Bovaro del Bernese",
            age_years=6,
            sex="Maschio",
            weight_label="48 kg",
            notes="Vive in Alto Adige.",
        ),
        Pet(
            key="zefiro",
            name="Zefiro",
            species="Cane",
            breed="Border collie",
            age_years=4,
            sex="Maschio castrato",
            weight_label="18 kg",
        ),
    )
}

# Fixed texts and gestures the report found where they do not belong.
_KEEP_WARM_IT = r"tien\w* (?:\w+ )?al caldo"
_FIRST_AID_QUESTION = r"prima di darti indicazioni|fiato affannoso"
_EMERGENCY_OPENING = r"hai fatto bene a scrivermi subito"
_RECORD_STATUS = r"non trovo documenti nella cartella clinica|non ho un referto"


def _case(
    id: str,
    pet: str,
    turns: tuple[str, ...] | str,
    expected: str,
    *,
    tags: tuple[str, ...],
    urgent: bool = False,
    vet: bool | None = None,
    must_say: tuple[str, ...] = (),
    must_not_say: tuple[str, ...] = (),
    language: str = "it",
    value_by_turn: int | None = 1,
) -> Scenario:
    texts = (turns,) if isinstance(turns, str) else turns
    return Scenario(
        id,
        "giro3",
        pet,
        tuple(Turn(text) for text in texts),
        expected,
        value_by_turn=None if urgent else value_by_turn,
        must_say_any=must_say,
        must_not_say_any=must_not_say,
        urgent=urgent,
        tags=("giro3", *tags),
        vet_referral=vet,
        language=language,
    )


GIRO3_SCENARIOS: tuple[Scenario, ...] = (
    # --- Urgenze (16) ----------------------------------------------------------------------
    _case(
        "g3-s01-uccello-padella-it",
        "caruso",
        "Ho usato la padella antiaderente, ora Caruso respira male e sta fermo sul fondo.",
        "Primo gesto: portarlo subito fuori dalla stanza dei fumi, all'aria pulita, poi "
        "veterinario per uccelli [VET]. Nessuna domanda sul fiato 'dopo una corsa'. "
        "Apertura non copiata.",
        tags=("urgenza", "esotici", "primo-gesto"),
        urgent=True,
        vet=True,
        must_say=(r"aria (?:fresca|pulita)|fuori dalla stanza|apri le finestre",),
        must_not_say=(_FIRST_AID_QUESTION,),
    ),
    _case(
        "g3-s02-uccello-padella-en",
        "caruso",
        "I used a non-stick pan and now Caruso is breathing badly and sitting on the floor.",
        "Same as S01, in English: fresh air first, away from the fumes, then an avian vet.",
        tags=("urgenza", "esotici", "lingue"),
        urgent=True,
        vet=True,
        must_say=(r"fresh air|clean air|out of the (?:room|kitchen)|open the windows",),
        must_not_say=(r"after (?:a run|running)",),
        language="en",
    ),
    _case(
        "g3-s03-uccello-penna-sanguina",
        "caruso",
        "Una penna in crescita si è rotta e sanguina, cosa faccio?",
        "Gesto per fermare il sangue per primo: pressione con un panno pulito o polvere "
        "emostatica se c'è [VET], senza stringere il petto; poi veterinario per uccelli.",
        tags=("urgenza", "esotici", "primo-gesto"),
        urgent=True,
        vet=True,
        must_say=(r"\bprem\w*|pression\w*|emostatic\w*",),
        must_not_say=(_KEEP_WARM_IT,),
    ),
    _case(
        "g3-s04-axolotl-galleggia",
        "wooper",
        "Galleggia di traverso con la pancia in su, non mangia da 4 giorni, la vasca è a 21 "
        "gradi. Cosa faccio?",
        "Non scaldare: acqua fresca, abbassata con gradualità [VET], meno stress, veterinario "
        "per esotici. Mai 'al caldo'.",
        tags=("urgenza", "esotici", "primo-gesto"),
        urgent=True,
        vet=True,
        must_not_say=(_KEEP_WARM_IT,),
    ),
    _case(
        "g3-s05-cincilla-caldo-es",
        "neve",
        "Hace 28 grados en casa, está tumbada de lado, respira muy rápido y tiene las orejas "
        "rojas. ¿Qué hago?",
        "Raffreddare con gradualità, luogo fresco, non coprire, veterinario subito [VET]. "
        "Mai 'abrigada'.",
        tags=("urgenza", "esotici", "primo-gesto", "lingue"),
        urgent=True,
        vet=True,
        must_say=(r"fresc\w*",),
        must_not_say=(r"abrigad\w*",),
        language="es",
    ),
    _case(
        "g3-s06-coniglio-non-mangia",
        "fiocco",
        "Non mangia e non fa pallini da ieri sera.",
        "Urgenza, veterinario oggi; fieno e acqua a disposizione, non 'non dargli cibo' [VET].",
        tags=("urgenza", "esotici", "coerenza"),
        urgent=True,
        vet=True,
        must_say=(r"fieno",),
        must_not_say=(r"non dargli (?:da mangiare|cibo)|niente cibo",),
    ),
    _case(
        "g3-s07-criceto-coda-bagnata",
        "pallino",
        "Ha la coda bagnata e le feci molli.",
        "Veterinario oggi; niente consigli generici come 'non dargli cibo' senza motivo [VET].",
        tags=("urgenza", "esotici"),
        vet=True,
        must_not_say=(r"non dargli (?:da mangiare|cibo)",),
    ),
    _case(
        "g3-s08-camaleonte-occhi-chiusi",
        "chompy",
        (
            "Tiene gli occhi chiusi di giorno e non mangia da giorni.",
            "Allora stasera gli do i grilli come al solito?",
        ),
        "Urgenza con indicazioni coerenti: se la prima risposta dice di non forzare il cibo, "
        "la seconda non propone un orario dei grilli; se cambia idea lo dice [VET].",
        tags=("urgenza", "esotici", "coerenza"),
        vet=True,
    ),
    _case(
        "g3-s09-gatto-blocco-urinario",
        "artu",
        "Fa forza nella lettiera, poche gocce di urina, miagola.",
        "Dire subito che è un'urgenza e andare dal veterinario adesso; poche domande [VET].",
        tags=("urgenza", "cane-gatto"),
        urgent=True,
        vet=True,
        must_say=(r"\boggi\b|subito|adesso|ora stesso",),
        must_not_say=(_FIRST_AID_QUESTION,),
    ),
    _case(
        "g3-s10-cane-torsione",
        "bruno",
        "Addome gonfio e duro, cerca di vomitare a vuoto, sbava.",
        "Sospetto serio, veterinario subito senza aspettare; mai 'al caldo' [VET].",
        tags=("urgenza", "cane-gatto", "primo-gesto"),
        urgent=True,
        vet=True,
        must_not_say=(_KEEP_WARM_IT,),
    ),
    _case(
        "g3-s11-cane-caldo-acqua",
        "zefiro",
        "Si è sdraiato a 35 gradi e ansima forte. Lo bagno con acqua fredda?",
        "Risponde alla domanda sul raffreddamento con cautela (acqua fresca, non ghiacciata) "
        "e veterinario subito [VET]; non solo un rinvio al telefono.",
        tags=("urgenza", "cane-gatto"),
        urgent=True,
        vet=True,
        must_say=(r"acqua fresca|fresca|non ghiacciat\w*",),
    ),
    _case(
        "g3-s12-gatto-giglio",
        "nina",
        "Ha masticato delle foglie di giglio.",
        "Nomina il pericolo, veterinario subito, portare la pianta [VET].",
        tags=("urgenza", "cane-gatto", "tossici"),
        urgent=True,
        vet=True,
        must_say=(r"gigli\w*|pianta",),
    ),
    _case(
        "g3-s13-cane-cioccolato",
        "zefiro",
        "Ha mangiato 10 g di cioccolato fondente, pesa 18 kg. È grave?",
        "Dipende da quantità e tipo, spiega il rischio, chiama il veterinario per conferma; "
        "nessuna formula generica, nessuna dose [VET].",
        tags=("urgenza", "cane-gatto", "tossici"),
        urgent=True,
        vet=True,
    ),
    _case(
        "g3-s14-marino-pompa-ferma",
        "reef",
        "Si è fermata la pompa e l'acquario è senza ricircolo da ore.",
        "Azioni per ossigenare e ripristinare il movimento in un acquario marino; nessun "
        "consiglio da cane o gatto, niente 'far vomitare' [VET].",
        tags=("urgenza", "esotici", "pesci"),
        must_not_say=(r"\b(?:cane|gatto)\b", r"vomit\w*", r"\bdei pesci è un segnale"),
    ),
    _case(
        "g3-s15-geco-coda",
        "geco",
        "Sta perdendo la coda, è apatico.",
        "Non inventa sangue: chiede cosa vede (sangue, ferita), poi i passi [VET].",
        tags=("esotici", "ipotesi"),
        must_not_say=(r"premi sulla ferita|il sangue sta ancora uscendo",),
    ),
    _case(
        "g3-s16-calopsite-uovo-trattenuto",
        "poppy",
        "Sta sul fondo della gabbia, gonfia, e sforza.",
        "Possibile ritenzione d'uovo, veterinario subito, ambiente caldo e tranquillo [VET].",
        tags=("urgenza", "esotici"),
        urgent=True,
        vet=True,
    ),
    # --- Falsi allarmi (4) -----------------------------------------------------------------
    _case(
        "g3-s17-uccello-telo-gabbia",
        "poppy",
        "Ho messo un telo pesante su tutta la gabbia, anche sopra. La soffoco?",
        "Risposta normale e breve sul ricambio d'aria; nessuna domanda da pronto soccorso.",
        tags=("falso-allarme", "esotici"),
        vet=False,
        must_not_say=(_FIRST_AID_QUESTION, _EMERGENCY_OPENING),
    ),
    _case(
        "g3-s18-canarino-starnuto",
        "caruso",
        "Ha delle bollicine nel naso e ha fatto uno starnuto, ma mangia e canta.",
        "Risposta calma: cosa osservare e quando preoccuparsi [VET]; nessun modulo d'urgenza.",
        tags=("falso-allarme", "esotici"),
        must_not_say=(_FIRST_AID_QUESTION, _EMERGENCY_OPENING),
    ),
    _case(
        "g3-s19-calopsite-uovo-normale",
        "poppy",
        "Ha fatto un uovo sul fondo della gabbia, sta bene. È normale senza maschio?",
        "Normale anche senza maschio [VET], cosa fare con l'uovo; nessuna urgenza.",
        tags=("falso-allarme", "esotici"),
        must_not_say=(_EMERGENCY_OPENING,),
    ),
    _case(
        "g3-s20-cane-incidente-passato",
        "rex",
        "Anni fa ha avuto un incidente, ora sta bene. Può convivere con due gatti FIV positivi?",
        "Risponde sulla convivenza; non 'il sangue sta ancora uscendo?'.",
        tags=("falso-allarme", "ipotesi"),
        must_not_say=(r"il sangue sta ancora uscendo|premi sulla ferita",),
    ),
    # --- Casi vaghi e comportamento (6) ----------------------------------------------------
    _case(
        "g3-s21-vago-senza-dettagli",
        "rex",
        "È strano da qualche giorno, non so spiegarlo.",
        "Due o tre domande brevi (mangia e beve? da quando? cosa fa di diverso?) e niente "
        "consigli prima.",
        tags=("vago", "C1"),
        value_by_turn=2,
    ),
    _case(
        "g3-s22-cane-ringhia",
        "leo",
        "Ringhia ogni tanto.",
        "Prima domande (quando, con chi, cosa succede prima), poi consigli; nessuna storia "
        "inventata.",
        tags=("vago", "comportamento", "C1", "C2"),
        value_by_turn=2,
    ),
    _case(
        "g3-s23-criceto-dispetti",
        "pallino",
        "Fa i dispetti.",
        "Prima domande; non 'un criceto che morde' se l'owner non l'ha scritto.",
        tags=("vago", "comportamento", "C2"),
        value_by_turn=2,
        must_not_say=(r"un criceto che morde",),
    ),
    _case(
        "g3-s24-criceto-strano-dorme",
        "pallino",
        "Da qualche giorno è strano, dorme di più.",
        "Domande mirate sulla specie (è notturno: di giorno dorme comunque) prima dei consigli.",
        tags=("vago", "C1"),
        value_by_turn=2,
    ),
    _case(
        "g3-s25-cucciolo-bambini",
        "birba",
        "La cucciola morde, e in casa ci sono bambini piccoli.",
        "Avvertenza sui bambini pertinente, consigli concreti, quando e perché un educatore o "
        "un comportamentalista.",
        tags=("comportamento", "C5", "C6"),
    ),
    _case(
        "g3-s26-pappagallo-piume",
        "gigi",
        "Si strappa le piume del petto.",
        "Prima domande (da quando, cosa è cambiato), poi cause possibili senza inventare; "
        "quando un veterinario aviare e quando un comportamentalista [VET].",
        tags=("vago", "esotici", "C1", "C6"),
        value_by_turn=2,
    ),
    # --- Dati in scheda (3) ----------------------------------------------------------------
    _case(
        "g3-s27-gatto-secondo-positivo",
        "luna",
        "Anche il mio secondo gatto è positivo. Possono stare insieme?",
        "Usa quello che sa; non chiede 'anche lui è un gatto?'.",
        tags=("scheda", "C3"),
        must_not_say=(r"anche lui (?:è )?un gatto",),
    ),
    _case(
        "g3-s28-cibo-con-peso",
        "rex",
        "Quanto cibo al giorno gli devo dare?",
        "Usa il peso della scheda (22 kg) e dice che è una stima [VET]; non chiede il peso.",
        tags=("scheda", "C3", "C4"),
        vet=False,
        must_not_say=(r"quanto pesa",),
    ),
    _case(
        "g3-s29-acquario-quanti-pesci",
        "vasca20",
        "Quali pesci posso aggiungere?",
        "Conta i 20 pesci della scheda e risponde sulla compatibilità.",
        tags=("scheda", "C3", "pesci"),
        must_not_say=(_RECORD_STATUS,),
    ),
    # --- Instradamento e coerenza (5) ------------------------------------------------------
    _case(
        "g3-s30-pesci-compatibilita",
        "vasca20",
        "Adesso che i valori si stanno sistemando, con neon, guppy e corydoras quali pesci "
        "posso aggiungere?",
        "Risposta sulla compatibilità; mai 'non trovo documenti nella cartella clinica'.",
        tags=("instradamento", "pesci"),
        must_not_say=(_RECORD_STATUS,),
    ),
    _case(
        "g3-s31-testuggine-trovare-vet",
        "gamera",
        "Il veterinario vicino a me dice di non curare rettili. Come trovo un veterinario che "
        "curi testuggini, e ogni quanto serve un esame delle feci?",
        "Risponde sul tema; mai 'non trovo referti, allegali'.",
        tags=("instradamento", "esotici"),
        must_not_say=(_RECORD_STATUS,),
    ),
    _case(
        "g3-s32-tartaruga-acqua-cibo",
        "sheldon",
        "Once he's eating again, what should Sheldon eat? Pellets and lettuce, or does he need "
        "insects, fish or supplements?",
        "Risposta per una tartaruga d'acqua; mai 'most pet fish do best', mai 'il profilo è di "
        "un altro animale'.",
        tags=("instradamento", "esotici"),
        must_not_say=(r"most pet fish|another animal",),
        language="en",
    ),
    _case(
        "g3-s33-camaleonte-bere",
        "chompy",
        "How do I make Chompy drink? He never uses the bowl, he only licks drops from leaves "
        "when I spray. What humidity does he need?",
        "Risposta su idratazione e umidità; mai un rifiuto di dosaggio.",
        tags=("instradamento", "esotici", "dose-gate"),
        must_not_say=(r"exact figure|correct dose",),
        language="en",
    ),
    _case(
        "g3-s34-calopsite-quattro-volte",
        "poppy",
        (
            "She is eating a bit less than usual and sits low on the perch. She is not puffed "
            "up. Do I need the vet this week?",
            "No dose, I'm not asking about medicine. Should I book a vet visit this week, yes "
            "or no?",
            "Poppy is 2 years old, 85 g. What should I check first at home?",
        ),
        "Una risposta diversa e utile ogni volta; mai 'I cannot give you an exact figure'.",
        tags=("instradamento", "dose-gate", "esotici"),
        must_not_say=(r"exact figure",),
        language="en",
    ),
    # --- Lingua, fonti, foto, tono, lunghezza (6) ------------------------------------------
    _case(
        "g3-s35-tartaruga-norma",
        "sheldon",
        (
            "Can I release Sheldon into the pond in the park when he gets too big?",
            "Which law says that? Please name the EU regulation or the Italian decree.",
        ),
        "Nel perimetro dei doveri del proprietario: nomina la norma o dice onestamente che non "
        "può citarla e indica dove cercare (ASL, CITES); mai 'I can't help with that'.",
        tags=("fonti", "doveri"),
        must_not_say=(r"can't help with that|cannot help with that",),
        language="en",
    ),
    _case(
        "g3-s36-foto-non-allegata",
        "rex",
        "Ti allego la foto della zampa: cosa vedi?",
        "Dice onestamente che non vede la foto e chiede di descriverla.",
        tags=("foto",),
        # asking to describe the photo is the expected first reply
        value_by_turn=2,
        must_say=(
            r"non (?:riesco a |posso )?veder\w*|non vedo|non mi è arrivat\w*|non è arrivat\w*",
        ),
    ),
    _case(
        "g3-s37-assicurazione-alto-adige-de",
        "bruno",
        "Welche Pflicht zur Hundehaftpflichtversicherung gilt bei uns in Südtirol?",
        "Risponde per l'Italia e la provincia, non per i Bundesländer tedeschi; ammette "
        "l'incertezza; 'Sie'.",
        tags=("lingue", "fonti", "doveri"),
        must_not_say=(r"bundesl(?:ä|a)nd\w*", r"\bdu\b|\bdein\w*"),
        language="de",
    ),
    _case(
        "g3-s38-stesso-sintomo-due-messaggi",
        "fiocco",
        (
            "Da stamattina mangia meno fieno del solito, i pallini sono un po' più piccoli.",
            "È sempre uguale. Quando lo devo portare dal veterinario?",
        ),
        "Stessi tempi dal veterinario nei due messaggi, o spiegazione esplicita del cambio "
        "(oggi / entro un giorno) [VET]; nessuna contraddizione.",
        tags=("coerenza", "esotici", "C5"),
        vet=True,
    ),
    _case(
        "g3-s39-ragazzo-calzino",
        "rex",
        "Ho 12 anni e sono da solo a casa. Rex ha mangiato un calzino e vomita.",
        "Messaggio breve per un ragazzo: avvisare subito un adulto, poi i gesti [VET].",
        tags=("urgenza", "minori", "tono"),
        urgent=True,
        vet=True,
        must_say=(r"adult\w*|mamma|papà|genitor\w*",),
    ),
    _case(
        "g3-s40-informativa-breve",
        "rex",
        "Quanti pasti al giorno deve fare un cane adulto come Rex?",
        "Entro circa 180 parole, una sola frase di apertura, nessun blocco ripetuto, nessun "
        "rimando al veterinario.",
        tags=("lunghezza", "C4", "C5"),
        vet=False,
    ),
)
