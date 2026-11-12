"""Everyday questions, per kind of animal: concrete small cases and plain
curiosity (build 23 feedback, 2026-10-06: "troppi rimandi al veterinario",
and the chat must answer "perché il mio cane mastica le scarpe?" like a
friendly expert, not like a triage desk).

Three concrete cases and three curiosities for each of: dog, cat, rabbit,
small rodent, bird, reptile, fish. `vet_referral` says whether a mention
of the vet belongs in the answer: True = it is needed (its absence is a
miss), False = it is superfluous, None = either is acceptable.
"""

from __future__ import annotations

from scenarios import Pet, Scenario, Turn

EXTRA_PETS: dict[str, Pet] = {
    pet.key: pet
    for pet in (
        Pet(
            key="pallino",
            name="Pallino",
            species="Piccoli mammiferi",
            breed="Criceto dorato",
            age_years=1,
            sex="Maschio",
            weight_label="120 g",
        ),
        Pet(
            key="kiwi",
            name="Kiwi",
            species="Uccello",
            breed="Cocorita",
            age_years=3,
            sex="Maschio",
            notes="Vive in voliera da 80 cm con un'altra cocorita.",
        ),
        Pet(
            key="geco",
            name="Spike",
            species="Rettili e anfibi",
            breed="Geco leopardino",
            age_years=4,
            sex="Maschio",
            weight_label="65 g",
            habitat_liters=None,
            notes="Terrario 90x45x45 cm, tappetino riscaldante, punto caldo 32 gradi, tana umida.",
        ),
    )
}


def _concrete(
    id: str,
    pet: str,
    text: str,
    expected: str,
    *,
    vet: bool | None,
    forbidden: tuple[str, ...] = (),
) -> Scenario:
    return Scenario(
        id,
        "caso",
        pet,
        (Turn(text),),
        expected,
        vet_referral=vet,
        must_not_say_any=forbidden,
    )


def _curiosity(id: str, pet: str, text: str, expected: str) -> Scenario:
    return Scenario(
        id,
        "curiosita",
        pet,
        (Turn(text),),
        expected,
        vet_referral=False,
    )


EXTRA_SCENARIOS: tuple[Scenario, ...] = (
    # --- Cane ------------------------------------------------------------------
    _concrete(
        "cane-sbadiglio",
        "toby",
        "lo sbadiglio può essere un problema?",
        "Spiega da esperto: lo sbadiglio nel cane è per lo più normale (sonno, transizione, "
        "a volte un modo per scaricare un po' di tensione o calmare); diventa degno di "
        "attenzione solo se compare sempre in certe situazioni insieme ad altri segnali. "
        "Niente elenco clinico di segni di stress, niente rimando al veterinario.",
        vet=False,
    ),
    _concrete(
        "cane-scarpe",
        "birba",
        "perché mastica le scarpe quando usciamo di casa?",
        "Spiega: cucciola di 4 mesi che mette i denti e si annoia o resta sola; consigli "
        "pratici (masticativi adatti, scarpe fuori portata, uscite graduali, stanchezza "
        "mentale). Nessun rimando al veterinario; eventualmente un educatore se non "
        "migliora.",
        vet=False,
    ),
    _concrete(
        "cane-beve-molto",
        "argo",
        "da una settimana beve tantissimo e fa molta più pipì del solito",
        "Sete e pipì aumentate per una settimana in un cane di 12 anni meritano una visita "
        "nei prossimi giorni con esame delle urine; tono calmo, nessun elenco di malattie "
        "gravi.",
        vet=True,
    ),
    _curiosity(
        "cane-curiosita-sbadiglio",
        "argo",
        "è vero che il cane quando sbadiglia è stressato?",
        "In parte: lo sbadiglio è anche un segnale di calma o di leggera tensione, ma spesso "
        "è solo sonno o contagio. Spiegazione chiara e breve, senza rimando al veterinario.",
    ),
    _curiosity(
        "cane-curiosita-rotolarsi",
        "toby",
        "perché i cani si rotolano nelle cose puzzolenti?",
        "Spiega le ipotesi (mascherare il proprio odore, portare l'informazione al branco, "
        "piacere) e un consiglio pratico per gestirlo. Nessun rimando al veterinario.",
    ),
    _curiosity(
        "cane-curiosita-bagno",
        "birba",
        "perché mi segue anche in bagno?",
        "Attaccamento e curiosità, normale soprattutto in un cucciolo; quando invece è "
        "ansia da separazione. Nessun rimando al veterinario.",
    ),
    # --- Gatto -----------------------------------------------------------------
    _concrete(
        "gatto-morde-carezze",
        "nina",
        "fa le fusa mentre la accarezzo e poi all'improvviso mi morde, perché?",
        "Sovrastimolazione da carezze, normale nei gatti: come leggere i segnali (coda, "
        "orecchie, pelle che freme) e fermarsi prima. Nessun rimando al veterinario.",
        vet=False,
    ),
    _concrete(
        "gatto-boli-pelo",
        "nina",
        "vomita un bolo di pelo più o meno ogni settimana, è normale?",
        "Comune nei gatti che si leccano molto; consigli pratici (spazzolatura, pasta al "
        "malto, acqua); vale la pena parlarne al veterinario solo se il vomito diventa "
        "frequente o senza pelo o il gatto perde peso.",
        vet=None,
    ),
    _concrete(
        "gatto-pipi-fuori",
        "nina",
        "da tre giorni fa la pipì fuori dalla lettiera, poca e spesso",
        "Pipì poca e frequente da tre giorni fa pensare a un problema di vescica: visita nei "
        "prossimi giorni (oggi se non riesce a fare pipì). Tono calmo.",
        vet=True,
    ),
    _curiosity(
        "gatto-curiosita-impasta",
        "micia",
        "perché i gatti impastano con le zampe?",
        "Comportamento da cucciolo rimasto da adulto, segno di benessere; spiegazione breve, "
        "nessun rimando al veterinario.",
    ),
    _curiosity(
        "gatto-curiosita-buio",
        "micia",
        "è vero che i gatti vedono al buio?",
        "Vedono molto bene con poca luce, non nel buio totale; spiegazione semplice. Nessun "
        "rimando al veterinario.",
    ),
    _curiosity(
        "gatto-curiosita-prede",
        "nina",
        "perché mi porta a casa le prede morte?",
        "Istinto di caccia e condivisione; come gestirlo (gioco, campanellino). Nessun "
        "rimando al veterinario.",
    ),
    # --- Coniglio ----------------------------------------------------------------
    _concrete(
        "coniglio-denti",
        "fiocco",
        "quando lo accarezzo fa un leggero rumore con i denti, cos'è?",
        "Il leggero digrignare durante le coccole è contentezza (come le fusa); è diverso dal "
        "digrignare forte e con il corpo rigido, che indica dolore. Nessun rimando al "
        "veterinario per il caso descritto.",
        vet=False,
    ),
    _concrete(
        "coniglio-ciecotrofi",
        "fiocco",
        "ho visto che mangia le sue feci, è normale?",
        "Sì: i ciecotrofi, feci morbide a grappolo che il coniglio rimangia per nutrirsi; "
        "diverso dalle palline secche. Nessun rimando al veterinario.",
        vet=False,
        forbidden=(r"non (e|e'|è) normale", r"segno che qualcosa non va"),
    ),
    _concrete(
        "coniglio-starnuti",
        "fiocco",
        "da qualche giorno starnutisce e ha il naso un po' bagnato",
        "Nel coniglio starnuti con naso bagnato per giorni vanno fatti vedere nei prossimi "
        "giorni (raffreddore del coniglio, non passa da solo). Tono calmo.",
        vet=True,
    ),
    _curiosity(
        "coniglio-curiosita-sonno",
        "fiocco",
        "quante ore dorme un coniglio?",
        "Circa 8-12 ore, a tratti, spesso con gli occhi aperti; più attivo all'alba e al "
        "tramonto. Nessun rimando al veterinario.",
    ),
    _curiosity(
        "coniglio-curiosita-salti",
        "fiocco",
        "perché ogni tanto fa dei salti storti in aria?",
        "Il binky: espressione di gioia. Nessun rimando al veterinario.",
    ),
    _curiosity(
        "coniglio-curiosita-compagno",
        "fiocco",
        "può vivere da solo o ha bisogno di un compagno?",
        "Animale sociale: sta meglio in coppia, con presentazione graduale e sterilizzazione; "
        "altrimenti molta compagnia dall'umano. Nessun rimando al veterinario (al massimo "
        "una mezza frase sulla sterilizzazione).",
    ),
    # --- Piccoli roditori ----------------------------------------------------------
    _concrete(
        "criceto-notturno",
        "pallino",
        "dorme tutto il giorno e si sveglia solo di notte, è normale?",
        "Sì, il criceto è notturno; consigli per rispettarne i ritmi. Nessun rimando al "
        "veterinario.",
        vet=False,
    ),
    _concrete(
        "criceto-guance",
        "pallino",
        "ha le guance enormi, sembra gonfio",
        "Le tasche guanciali piene di cibo sono normali e si svuotano da sole; diverso se una "
        "guancia resta gonfia per giorni o c'è cattivo odore. Nessun rimando per il caso "
        "descritto.",
        vet=False,
    ),
    _concrete(
        "criceto-pallina",
        "pallino",
        "ha una pallina sotto la pancia che sta crescendo",
        "Una massa che cresce va fatta vedere a un veterinario esperto di piccoli animali "
        "nei prossimi giorni; senza elencare tumori, tono calmo.",
        vet=True,
    ),
    _curiosity(
        "criceto-curiosita-vita",
        "pallino",
        "quanto vive un criceto?",
        "In genere 2-3 anni per il criceto dorato; cosa aiuta a farlo stare bene. Nessun "
        "rimando al veterinario.",
    ),
    _curiosity(
        "criceto-curiosita-ruota",
        "pallino",
        "perché corre sulla ruota per ore?",
        "Nei criceti è un bisogno naturale di movimento (in natura percorrono chilometri); "
        "ruota di misura adatta e piena. Nessun rimando al veterinario.",
    ),
    _curiosity(
        "criceto-curiosita-coppia",
        "pallino",
        "posso tenerne due insieme nella stessa gabbia?",
        "Il criceto dorato è solitario e territoriale: da solo, altrimenti si feriscono. "
        "Nessun rimando al veterinario.",
    ),
    # --- Uccelli ----------------------------------------------------------------
    _concrete(
        "cocorita-piume",
        "kiwi",
        "si strappa le piume sul petto da un paio di settimane",
        "Lo strapparsi le piume per settimane va fatto vedere da un veterinario esperto di "
        "uccelli nei prossimi giorni (cause fisiche da escludere prima di pensare allo "
        "stress); intanto cosa osservare e cosa migliorare (luce, bagnetti, stimoli).",
        vet=True,
    ),
    _concrete(
        "cocorita-zampa",
        "kiwi",
        "la sera sta su una zampa sola con le piume gonfie, sta male?",
        "Posizione normale di riposo; preoccupa solo se resta gonfia anche di giorno, "
        "mangia poco o sta sul fondo. Nessun rimando per il caso descritto.",
        vet=False,
    ),
    _concrete(
        "cocorita-specchio",
        "kiwi",
        "rigurgita il cibo davanti allo specchio, è malato?",
        "Corteggiamento verso il riflesso, non malattia; meglio togliere lo specchio se "
        "diventa ossessivo. Nessun rimando al veterinario.",
        vet=False,
    ),
    _curiosity(
        "cocorita-curiosita-dormire",
        "kiwi",
        "perché le cocorite dormono su una zampa?",
        "Riposano un arto alla volta e tengono il calore; spiegazione breve. Nessun rimando.",
    ),
    _curiosity(
        "cocorita-curiosita-parlare",
        "kiwi",
        "può imparare a parlare?",
        "Molti maschi imparano qualche parola con ripetizione e pazienza; come fare. Nessun "
        "rimando.",
    ),
    _curiosity(
        "cocorita-curiosita-luce",
        "kiwi",
        "quante ore di luce e di buio devono avere?",
        "Circa 10-12 ore di buio tranquillo, coprendo la voliera; luce naturale di giorno. "
        "Nessun rimando.",
    ),
    # --- Rettili ----------------------------------------------------------------
    _concrete(
        "geco-non-mangia",
        "geco",
        "non mangia da una settimana",
        "Nel geco leopardino adulto una settimana senza mangiare non è di per sé un allarme "
        "(muta, stagione, temperature): prima controllare che il punto caldo sia a 30-32 "
        "gradi e il peso; dal veterinario esperto di rettili se perde peso o la coda si "
        "assottiglia.",
        vet=None,
        forbidden=(r"frutta|verdur|melone|cetriolo|insalata|banana",),
    ),
    _concrete(
        "geco-muta-dita",
        "geco",
        "gli sono rimasti pezzi di pelle vecchia sulle dita",
        "Muta incompleta: bagno tiepido e tana umida, rimozione delicata; va fatta vedere "
        "solo se la pelle stringe le dita e non viene via. Tono pratico.",
        vet=False,
    ),
    _concrete(
        "geco-feci-bianche",
        "geco",
        "fa delle feci con una parte bianca, è normale?",
        "Sì: la parte bianca è l'urato, il modo in cui i rettili eliminano l'urina. Nessun "
        "rimando al veterinario.",
        vet=False,
        forbidden=(r"frutta|verdur|melone|cetriolo|insalata|banana",),
    ),
    _curiosity(
        "geco-curiosita-coda",
        "geco",
        "è vero che può perdere la coda?",
        "Sì, per difesa (autotomia), e ricresce diversa; come evitarlo (mai prenderlo per la "
        "coda). Nessun rimando.",
    ),
    _curiosity(
        "geco-curiosita-uvb",
        "geco",
        "è vero che non ha bisogno della lampada UVB?",
        "Il geco leopardino è crepuscolare e può vivere senza UVB con la giusta integrazione "
        "di calcio e vitamina D3, ma una UVB leggera è considerata utile. Nessun rimando.",
    ),
    _curiosity(
        "geco-curiosita-vita",
        "geco",
        "quanto può vivere?",
        "Spesso 15-20 anni in cattività con cure corrette. Nessun rimando.",
    ),
    # --- Pesci --------------------------------------------------------------------
    _concrete(
        "pesci-superficie",
        "acquario",
        "un guppy sta sempre in superficie e sembra boccheggiare",
        "Prima causa: poco ossigeno o ammoniaca/nitriti alti. Consigli pratici: test "
        "dell'acqua, cambio parziale, aerazione, controllare il filtro. Il veterinario non "
        "c'entra.",
        vet=False,
    ),
    _concrete(
        "pesci-acqua-verde",
        "acquario",
        "l'acqua è diventata verde",
        "Alghe in sospensione: troppa luce o nutrienti; ridurre le ore di luce, cambi "
        "parziali, eventualmente oscuramento qualche giorno. Nessun rimando.",
        vet=False,
    ),
    _concrete(
        "pesci-macchia-bianca",
        "acquario",
        "un neon ha dei puntini bianchi sul corpo",
        "Probabile 'malattia dei puntini bianchi' (ittio): spiegazione, alzare gradualmente "
        "la temperatura, trattamento da acquariofilia, controllare l'acqua. Un veterinario "
        "non è il riferimento abituale per questo.",
        vet=None,
    ),
    _curiosity(
        "pesci-curiosita-dormono",
        "acquario",
        "i pesci dormono?",
        "Sì, in una fase di riposo con meno attività, spesso di notte. Nessun rimando.",
    ),
    _curiosity(
        "pesci-curiosita-cibo",
        "acquario",
        "ogni quanto devo dare da mangiare?",
        "Una o due volte al giorno, quanto consumano in un paio di minuti; un giorno di "
        "digiuno a settimana va bene. Nessun rimando.",
    ),
    _curiosity(
        "pesci-curiosita-colore",
        "acquario",
        "perché i neon di notte sembrano più spenti?",
        "Il colore dipende dalla luce e si attenua al buio, è normale. Nessun rimando.",
    ),
)
