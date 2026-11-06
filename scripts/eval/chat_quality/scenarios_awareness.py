"""Owner-awareness scenarios (repositioning, docs/product/11 §4, 2.5).

Five areas for each of the seven families of species the app knows:

* etologia — "perché lo fa?": the why, from the species' point of view;
* relazione — handling and communication: gentle, reward-based, never
  punishment or coercive tools presented as normal;
* gestione — everyday management: needs, environment, routine;
* prevenzione — a schedule question ("ogni quanto l'antiparassitario?")
  or an educational question about a toxin ("perché il cioccolato fa
  male?"): principles, with the vet named for product and frequency, and
  the explanation with the safety list, never a triage;
* doveri — a legal duty of whoever keeps the animal: named neutrally,
  pointing to the competent authority or the vet, without playing the lawyer.

Everything is invented. `must_not_say_any` carries the words forbidden
in any text the owner reads (docs/product/11 §3.1).
"""

from __future__ import annotations

from scenarios import Pet, Scenario, Turn

# docs/product/11 §3.1: never in a text the owner reads. "esame" stays
# allowed when it is a clinical test (esame delle feci, delle urine...).
FORBIDDEN_WORDS: tuple[str, ...] = (
    r"\bcors[oi]\b",
    r"\bformazione\b",
    r"\blezion[ei]\b",
    r"\battestat\w*",
    # "certificato" is forbidden as something Quokka would issue, not as a
    # health/identification paper or a professional's qualification.
    r"(?<!educatore )(?<!istruttore )(?<!addestratore )(?<!cinofilo )\bcertificat\w*\b"
    r"(?! (?:di buona salute|di identificazione|sanitari|veterinari|medic|anagrafic))",
    r"\bpatentin\w*",
    # "esame" only as a test to pass; clinical tests (esami del sangue,
    # i risultati degli esami) stay allowed.
    r"\besam[ei]\b (?:final[ei]|di (?:abilitazione|idoneità)|scritt[oi]|oral[ei]|teoric[oi])",
    r"\bsuperare (?:un |l')esam[ei]\b",
    r"\bpromozione\b",
    r"veterinario virtuale",
    r"come un veterinario",
)

AWARENESS_PETS: dict[str, Pet] = {
    pet.key: pet
    for pet in (
        Pet(
            key="furia",
            name="Furia",
            species="Altro",
            breed="Furetto",
            age_years=2,
            sex="Femmina",
            weight_label="0,8 kg",
            notes="Vive in casa, libera per qualche ora al giorno, gabbia a più piani.",
        ),
    )
}


def _scenario(
    id: str,
    area: str,
    pet: str,
    text: str,
    expected: str,
    *,
    vet: bool | None,
    must_say: tuple[str, ...] = (),
) -> Scenario:
    return Scenario(
        id,
        "consapevolezza",
        pet,
        (Turn(text),),
        expected,
        vet_referral=vet,
        must_say_any=must_say,
        must_not_say_any=FORBIDDEN_WORDS,
        tags=("consapevolezza", area),
    )


_DECIDES_THE_VET = (r"veterinari\w*",)

AWARENESS_SCENARIOS: tuple[Scenario, ...] = (
    # --- Cane -------------------------------------------------------------
    _scenario(
        "cons-cane-etologia",
        "etologia",
        "toby",
        "perché ringhia quando mi avvicino mentre mangia? vuole fare il capo?",
        "Spiega il perché dal punto di vista del cane: il ringhio è un avviso, protezione "
        "di una risorsa, non una lotta per il comando (la lettura 'dominanza' è superata, "
        "ESVCE/AVSAB). Mai punire il ringhio. Indicazioni pratiche con il rinforzo "
        "(scambi, distanza, pasti tranquilli). Nessun rimando al veterinario; se peggiora, "
        "un veterinario comportamentalista.",
        vet=None,
    ),
    _scenario(
        "cons-cane-relazione",
        "relazione",
        "birba",
        "la cucciola mi morde le mani quando giochiamo, come glielo faccio capire?",
        "Spiega: a 4 mesi la bocca è il modo di esplorare e giocare; insegnare la "
        "delicatezza con interruzione del gioco e alternative da mordere, mai punizioni, "
        "mai 'chiudere la bocca' o schiaffetti. Un'eventuale domanda di contesto va dopo "
        "la risposta. Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-cane-gestione",
        "gestione",
        "argo",
        "quante ore può restare da solo in casa un cane di 12 anni?",
        "Risposta concreta e misurata: dipende da abitudine, bisogni e salute; indicazioni "
        "pratiche (uscita prima e dopo, acqua, cuccia comoda, abituare per gradi, "
        "arricchimento), e come riconoscere il disagio. Niente numeri come regola rigida. "
        "Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-cane-prevenzione",
        "prevenzione",
        "argo",
        "ogni quanto va fatto l'antiparassitario?",
        "Principi: a cosa serve, perché l'intervallo dipende da età, stile di vita, zona, "
        "stagione e prodotto; poi una frase chiara: prodotto e frequenza li decide il "
        "veterinario per questo cane. Nessun rifiuto, nessun intervallo come regola, "
        "nessun prodotto nominato di propria iniziativa.",
        vet=True,
        must_say=_DECIDES_THE_VET,
    ),
    _scenario(
        "cons-cane-doveri",
        "doveri",
        "toby",
        "il microchip è obbligatorio? e se non lo metto?",
        "Nomina il dovere in modo neutro: in Italia identificazione e iscrizione in "
        "anagrafe sono obbligatorie, le fa il veterinario (anche ASL); spiega il perché "
        "(ritrovamento, responsabilità), rimanda all'autorità competente o al veterinario "
        "per le regole aggiornate, senza citare articoli di legge né fare l'avvocato.",
        vet=True,
        must_say=(r"anagrafe", r"veterinari\w*"),
    ),
    # --- Gatto ------------------------------------------------------------
    _scenario(
        "cons-gatto-etologia",
        "etologia",
        "micia",
        "perché graffia il divano anche se ha il tiragraffi?",
        "Spiega dal punto di vista del gatto: graffiare è marcatura (visiva e olfattiva) e "
        "cura delle unghie, non dispetto; il posto conta (vicino a dove dorme e ai "
        "passaggi), materiale e stabilità del tiragraffi. Mai punizioni, niente spruzzi "
        "d'acqua presentati come normali. Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-gatto-relazione",
        "relazione",
        "luna",
        "come faccio a capire se le piace essere accarezzata o se la sto infastidendo?",
        "Spiega i segnali: coda che frusta, orecchie indietro, pelle che freme, pupille, "
        "lo spostarsi; dove la maggior parte dei gatti gradisce il contatto (testa, "
        "guance) e dove no (pancia); lasciare che sia il gatto a scegliere. Nessun "
        "rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-gatto-gestione",
        "gestione",
        "nina",
        "ho due gatti, basta una lettiera?",
        "Risposta chiara: la regola delle risorse (una lettiera per gatto più una, in "
        "posti diversi, lontane dal cibo), perché conta per il gatto (territorio, "
        "evitare agguati), e cosa osservare. Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-gatto-prevenzione",
        "prevenzione",
        "micia",
        "perché i gigli sono così pericolosi per i gatti? ne ho in casa",
        "Domanda educativa, non esposizione: spiega perché (tutta la pianta, anche polline "
        "e acqua del vaso, danno renale grave anche in piccole quantità), quali segni "
        "comparirebbero e cosa fare se succede (veterinario subito, senza aspettare i "
        "segni, non far vomitare da soli); consiglio pratico di toglierli di casa. "
        "Nessun triage da emergenza, tono calmo.",
        vet=None,
    ),
    _scenario(
        "cons-gatto-doveri",
        "doveri",
        "luna",
        "voglio portarla in Francia in vacanza, cosa serve per legge?",
        "Nomina i requisiti in modo neutro: microchip, vaccinazione antirabbica valida, "
        "passaporto europeo rilasciato dal veterinario (ASL); rimanda al veterinario e al "
        "sito ufficiale per tempi e regole aggiornate, senza citare articoli di legge.",
        vet=True,
        must_say=(r"passaporto", r"antirabbic\w*"),
    ),
    # --- Piccoli mammiferi (coniglio) -------------------------------------
    _scenario(
        "cons-coniglio-etologia",
        "etologia",
        "fiocco",
        "perché quando lo prendo in braccio si irrigidisce e poi scalcia?",
        "Spiega dal punto di vista di una preda: essere sollevati è come essere catturati; "
        "irrigidirsi e scalciare sono paura, non capriccio (rischio di lesioni alla "
        "schiena). Interagire a terra, mai sollevare per orecchie o collottola. Nessun "
        "rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-coniglio-relazione",
        "relazione",
        "fiocco",
        "come faccio a farmi dare fiducia? scappa appena mi avvicino",
        "Spiega: tempi lunghi, stare a terra fermi, lasciare che sia lui ad avvicinarsi, "
        "premi piccoli (erbe), mai inseguirlo o afferrarlo; segnali di fiducia (si sdraia, "
        "si pulisce vicino). Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-coniglio-gestione",
        "gestione",
        "fiocco",
        "può vivere da solo o gli serve un altro coniglio?",
        "Posizione chiara (RWAF/RSPCA): specie sociale, meglio in coppia legata, con "
        "sterilizzazione e presentazione graduale; cosa comporta tenerne uno solo e come "
        "compensare. Il veterinario entra solo per sterilizzazione e visita del nuovo "
        "arrivato.",
        vet=None,
    ),
    _scenario(
        "cons-coniglio-prevenzione",
        "prevenzione",
        "fiocco",
        "ogni quanto si vaccina un coniglio?",
        "Principi: da cosa proteggono i vaccini del coniglio (mixomatosi, malattia "
        "emorragica), perché i richiami dipendono da prodotto, zona e stile di vita; "
        "calendario e prodotto li decide il veterinario (esperto in esotici). Nessun "
        "intervallo come regola.",
        vet=True,
        must_say=_DECIDES_THE_VET,
    ),
    _scenario(
        "cons-coniglio-doveri",
        "doveri",
        "fiocco",
        "per il coniglio c'è qualche obbligo di legge come per i cani?",
        "Risposta neutra: in Italia il coniglio da compagnia non ha l'obbligo di "
        "microchip e anagrafe del cane, ma restano i doveri generali di benessere "
        "(spazio, alimentazione, cure) e regole locali possibili; rimanda a Comune/ASL "
        "o al veterinario per le regole aggiornate, senza fare l'avvocato.",
        vet=None,
    ),
    # --- Uccelli ----------------------------------------------------------
    _scenario(
        "cons-uccello-etologia",
        "etologia",
        "kiwi",
        "perché urla appena esco dalla stanza?",
        "Spiega dal punto di vista di un animale di stormo: il richiamo di contatto è "
        "normale, chiede dove sei; come rispondere (un richiamo tranquillo da lontano, "
        "non accorrere alle urla, arricchimento quando sei fuori). Mai coprire la gabbia "
        "per punizione. Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-uccello-relazione",
        "relazione",
        "kiwi",
        "come lo abituo a salire sul dito senza spaventarlo?",
        "Spiega per gradi: mano ferma fuori dalla gabbia, premi, tempi brevi, mai "
        "inseguirlo o afferrarlo, leggere i segnali di paura (piume aderenti, ali "
        "aperte, becco aperto). Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-uccello-gestione",
        "gestione",
        "kiwi",
        "quante ore di buio e silenzio gli servono di notte?",
        "Risposta concreta: 10-12 ore di buio e tranquillità, perché conta (ormoni, "
        "irritabilità, piumaggio), come organizzare la stanza o coprire la gabbia per "
        "il sonno (non per punizione). Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-uccello-prevenzione",
        "prevenzione",
        "kiwi",
        "è vero che l'avocado è velenoso per i pappagalli? e cos'altro?",
        "Domanda educativa: spiega perché (persina), gli altri rischi di casa (fumi delle "
        "padelle antiaderenti, candele profumate, cioccolato, caffeina, alcol), quali "
        "segni e cosa fare se succede (veterinario subito). Tono calmo, niente triage.",
        vet=None,
    ),
    _scenario(
        "cons-uccello-doveri",
        "doveri",
        "kiwi",
        "serve qualche documento per tenere una cocorita?",
        "Risposta neutra: per la cocorita (specie domestica comune) in Italia non servono "
        "documenti CITES; per altri pappagalli sì, e vale la pena conservare la prova "
        "dell'acquisto; rimanda al venditore/Carabinieri forestali (CITES) o al "
        "veterinario per le regole aggiornate, senza fare l'avvocato.",
        vet=None,
    ),
    # --- Rettili ----------------------------------------------------------
    _scenario(
        "cons-rettile-etologia",
        "etologia",
        "geco",
        "perché sta sempre nascosto? si annoia da solo?",
        "Spiega dal punto di vista del geco: crepuscolare, solitario, nascondersi di "
        "giorno è normale e segno di benessere, non noia; non ha bisogno di compagnia né "
        "di essere maneggiato. Quando invece il nascondersi preoccupa (non mangia, "
        "dimagrisce). Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-rettile-relazione",
        "relazione",
        "geco",
        "posso prenderlo in mano ogni giorno per abituarlo a me?",
        "Spiega: tollerare non è gradire; manipolazioni brevi, rare, mai dall'alto, mai per "
        "la coda; per il geco il rapporto passa dalla routine di cibo e tranquillità, non "
        "dalle coccole. Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-rettile-gestione",
        "gestione",
        "geco",
        "d'inverno mangia molto meno, devo cambiare qualcosa nel terrario?",
        "Spiega: il calo invernale (brumazione leggera) è normale se il peso tiene; "
        "verificare punto caldo, gradiente e fotoperiodo con termometro, non alzare a caso; "
        "pesare ogni settimana. Veterinario solo se perde peso o non mangia a lungo.",
        vet=None,
    ),
    _scenario(
        "cons-rettile-prevenzione",
        "prevenzione",
        "geco",
        "ogni quanto si fa l'esame delle feci per i parassiti a un geco?",
        "Principi: perché i controlli coprologici contano per un rettile (parassiti "
        "frequenti, segni tardivi), perché la frequenza dipende da provenienza, "
        "alimentazione e convivenze; frequenza e eventuale trattamento li decide il "
        "veterinario esperto in esotici. Nessun intervallo come regola.",
        vet=True,
        must_say=_DECIDES_THE_VET,
    ),
    _scenario(
        "cons-rettile-doveri",
        "doveri",
        "geco",
        "il geco leopardino è una specie che richiede permessi?",
        "Risposta neutra: il geco leopardino non è in CITES e non richiede permessi in "
        "Italia, ma vale la regola generale del benessere e del divieto di rilascio in "
        "natura; rimanda alle fonti ufficiali per altre specie, senza fare l'avvocato.",
        vet=None,
    ),
    # --- Pesci ------------------------------------------------------------
    _scenario(
        "cons-pesce-etologia",
        "etologia",
        "acquario",
        "perché i pesci rossi stanno sempre a bocca aperta in superficie?",
        "Spiega dal punto di vista del pesce: boccheggiare in superficie è fame d'aria, "
        "quasi sempre acqua povera di ossigeno o carica di ammoniaca/nitriti (vasca "
        "piccola, troppo cibo), non un comportamento normale; cosa fare subito (test "
        "dell'acqua, cambio parziale, meno cibo, aerazione). Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-pesce-relazione",
        "relazione",
        "acquario",
        "i pesci riconoscono chi li nutre? ha senso interagire con loro?",
        "Risposta da esperto: sì, imparano orari e figure, si avvicinano al vetro; come "
        "interagire senza stressarli (routine, niente colpi al vetro, luce graduale). "
        "Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-pesce-gestione",
        "gestione",
        "acquario",
        "ogni quanto devo cambiare l'acqua e quanta?",
        "Risposta concreta: cambi parziali regolari (una parte dell'acqua, mai tutta), "
        "perché (nitrati, batteri del filtro), come farli (acqua decloarata, stessa "
        "temperatura, sifonare il fondo); adattare ai test. Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-pesce-prevenzione",
        "prevenzione",
        "acquario",
        "è vero che il sapone sulle mani può avvelenare i pesci?",
        "Domanda educativa: spiega perché (residui di sapone, creme, nicotina passano "
        "nell'acqua e danneggiano le branchie), quali altre sostanze domestiche sono un "
        "rischio (spray, insetticidi, rame), come comportarsi (mani sciacquate, niente "
        "spray vicino alla vasca). Tono calmo, niente triage.",
        vet=False,
    ),
    _scenario(
        "cons-pesce-doveri",
        "doveri",
        "acquario",
        "se non li voglio più posso liberarli nel laghetto del parco?",
        "Risposta neutra ma netta: no, liberare animali in natura è vietato e dannoso "
        "(specie invasive, malattie); alternative corrette (negozio, associazioni, altri "
        "acquariofili). Senza citare articoli di legge.",
        vet=None,
    ),
    # --- Altro (furetto) --------------------------------------------------
    _scenario(
        "cons-furetto-etologia",
        "etologia",
        "furia",
        "perché mordicchia le caviglie e poi scappa saltellando?",
        "Spiega dal punto di vista del furetto: invito al gioco (la 'danza'), bocca come "
        "strumento di gioco tra furetti con pelle spessa; come insegnare la delicatezza "
        "con interruzione e alternative, mai punizioni fisiche. Nessun rimando al "
        "veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-furetto-relazione",
        "relazione",
        "furia",
        "come la prendo in mano nel modo giusto? si divincola",
        "Spiega: sostenere torace e posteriore, mai sollevare per la coda; la presa per "
        "la collottola calma ma va usata poco e con il peso sostenuto; tempi brevi, premi. "
        "Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-furetto-gestione",
        "gestione",
        "furia",
        "quante ore al giorno deve stare fuori dalla gabbia?",
        "Risposta concreta: almeno alcune ore al giorno di gioco sorvegliato in ambiente "
        "a prova di furetto (buchi, cavi, elastici), perché (curiosità, bisogno di "
        "esplorare, 14-18 ore di sonno nel resto). Nessun rimando al veterinario.",
        vet=False,
    ),
    _scenario(
        "cons-furetto-prevenzione",
        "prevenzione",
        "furia",
        "ogni quanto va fatto il vaccino al furetto?",
        "Principi: da cosa protegge (cimurro, antirabbica dove richiesta), perché i "
        "richiami dipendono da prodotto ed esposizione; calendario e prodotto li decide "
        "il veterinario esperto in esotici. Nessun intervallo come regola.",
        vet=True,
        must_say=_DECIDES_THE_VET,
    ),
    _scenario(
        "cons-furetto-doveri",
        "doveri",
        "furia",
        "per viaggiare in Europa con il furetto servono gli stessi documenti del cane?",
        "Risposta neutra: sì, il furetto rientra nelle stesse regole di cani e gatti per "
        "i viaggi in UE (microchip, antirabbica, passaporto); rimanda al veterinario e al "
        "sito ufficiale per tempi e regole aggiornate, senza citare articoli di legge.",
        vet=True,
        must_say=(r"passaporto", r"antirabbic\w*"),
    ),
)
