"""The rule-based anonymizer on realistic Italian veterinary text: it must
remove what identifies a person and leave everything clinical intact."""

import pytest

from packages.core.application.ports.pii_anonymizer import PiiAnonymizationRequest
from packages.infrastructure.privacy.rule_based_pii_anonymizer import RuleBasedPiiAnonymizer


def _anonymize(text: str, names: list[str] | None = None) -> str:
    return (
        RuleBasedPiiAnonymizer()
        .anonymize(PiiAnonymizationRequest(text=text, known_person_names=names or []))
        .anonymized_text
    )


REPORT = """Clinica Veterinaria Esempio S.r.l. - P.IVA 01234567890
Via Esempio 12, 00000 Esempio (EE) - Tel. 02 12345678 - info@clinica-esempio.example
www.clinica-esempio.example

Referto esami ematochimici del 12/09/2026
Proprietario: Mario Rossi - C.F. TSTTST00A00X000X - cell. 333 1234567
Paziente: REX, cane maschio, Labrador, nato il 03/03/2019, peso 30,5 kg
Microchip: 380260101234567

Ematocrito: 38 % (rif. 37 - 55)
Creatinina: 2,4 mg/dL (rif. 0,5 - 1,5) ALTO
Piastrine: 350.000 /uL (rif. 200.000 - 500.000)
Glucosio: 95 mg/dL (rif. 70 - 120)

Terapia: amoxicillina 250 mg per via orale 2 volte al giorno per 7 giorni.
Conclusioni: controllo della funzionalità renale tra 30 giorni.
Medico veterinario: Dott.ssa Laura Bianchi
Pagamento: IBAN IT00 X000 0000 0000 0000 0123 456
"""


def test_a_realistic_report_loses_every_personal_detail() -> None:
    anonymized = _anonymize(REPORT)

    for personal in (
        "01234567890",
        "Via Esempio",
        "00000",
        "02 12345678",
        "info@clinica-esempio.example",
        "www.clinica-esempio.example",
        "Mario Rossi",
        "TSTTST00A00X000X",
        "333 1234567",
        "Laura Bianchi",
        "IT00 X000",
    ):
        assert personal not in anonymized, personal
    for placeholder in (
        "[PARTITA_IVA]",
        "[INDIRIZZO]",
        "[TELEFONO]",
        "[EMAIL]",
        "[URL]",
        "[NOME]",
        "[CODICE_FISCALE]",
        "[IBAN]",
    ):
        assert placeholder in anonymized, placeholder


def test_a_realistic_report_keeps_every_clinical_detail() -> None:
    anonymized = _anonymize(REPORT)

    for clinical in (
        "Referto esami ematochimici del 12/09/2026",
        "Proprietario:",
        "Paziente: REX, cane maschio, Labrador, nato il 03/03/2019, peso 30,5 kg",
        "Microchip: 380260101234567",
        "Ematocrito: 38 % (rif. 37 - 55)",
        "Creatinina: 2,4 mg/dL (rif. 0,5 - 1,5) ALTO",
        "Piastrine: 350.000 /uL (rif. 200.000 - 500.000)",
        "Glucosio: 95 mg/dL (rif. 70 - 120)",
        "amoxicillina 250 mg per via orale 2 volte al giorno per 7 giorni.",
        "controllo della funzionalità renale tra 30 giorni.",
        "Medico veterinario: Dott.ssa [NOME]",
    ):
        assert clinical in anonymized, clinical


@pytest.mark.parametrize(
    "text",
    [
        # dosing and routes of administration
        "Dare 0,5 ml per via orale 2 volte al giorno per 10 giorni",
        "Meloxicam 0.1 mg/kg per via sottocutanea 1 volta al giorno",
        "Somministrare 1/2 compressa da 50 mg ogni 12 ore",
        "Terapia in corso da 3 giorni, antibiotico a largo spettro 2 volte al dì",
        "Nel corso di 2 settimane ha perso peso",
        "Per via del caldo da 2 giorni beve di più",
        "È andato via da 2 giorni e non torna",
        # dates and times
        "Vaccinato il 01/02/2026, richiamo il 01.02.2027 alle 15:30",
        "Nato il 3-3-2019",
        # weights, lab values, counts
        "Pesa 17,8 kg, l'anno scorso 16.250 g",
        "Globuli rossi 6.500.000 /uL, piastrine 350 000 /uL",
        "Temperatura 38,5 °C, frequenza cardiaca 120 bpm",
        "Acquario da 60 litri con 12 pesci, pH 7,2",
        # microchip, in the forms owners and clinics write it
        "Microchip 380260101234567",
        "Chip n. 380 260 101 234 567",
        "microchip 941000012345678 applicato nel 2020",
        # ordinary sentences with capitalised words
        "Il cane di Marta gioca con Luna al parco",
    ],
)
def test_clinical_and_everyday_text_is_left_untouched(text: str) -> None:
    assert _anonymize(text) == text


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("scrivimi a mario.rossi+vet@example.com grazie", "scrivimi a [EMAIL] grazie"),
        ("chiamami al 3331234567", "chiamami al [TELEFONO]"),
        ("chiamami al +39 333 123 4567 dopo le 18", "chiamami al [TELEFONO] dopo le 18"),
        ("il mio numero è 0039 347-1234567", "il mio numero è [TELEFONO]"),
        ("lo studio risponde allo 06 1234567", "lo studio risponde allo [TELEFONO]"),
        ("fisso 0331/123456", "fisso [TELEFONO]"),
        ("CF: tsttst00a00x000x", "CF: [CODICE_FISCALE]"),
        ("P.IVA IT01234567890", "P.IVA [PARTITA_IVA]"),
        ("bonifico su IT00X0000000000000000123456", "bonifico su [IBAN]"),
        ("guarda https://example.org/cane?id=3 e dimmi", "guarda [URL] e dimmi"),
        ("l'ho letto su example.com/thread/12", "l'ho letto su [URL]"),
        ("abito in Via Roma 12", "abito in [INDIRIZZO]"),
        ("abito in via dei Mille, n. 5/b a Torino", "abito in [INDIRIZZO] a Torino"),
        ("la clinica è in Corso Esempio 150, 00000 Esempio", "la clinica è in [INDIRIZZO]"),
        ("siamo in Piazza San Marco 3", "siamo in [INDIRIZZO]"),
        ("ci vediamo in via XX Settembre 40", "ci vediamo in [INDIRIZZO]"),
        ("visita dal Dott. Paolo Neri ieri", "visita dal Dott. [NOME] ieri"),
        ("Cliente: Anna De Luca", "Cliente: [NOME]"),
    ],
)
def test_each_kind_of_personal_data_is_replaced_by_its_placeholder(
    text: str, expected: str
) -> None:
    assert _anonymize(text) == expected


def test_the_known_owner_name_is_replaced_wherever_it_appears() -> None:
    anonymized = _anonymize(
        "Sono Maria Rossi, la veterinaria ha scritto 'sig.ra ROSSI' sul referto di Milo. "
        "Mi chiamo Maria.",
        names=["Maria Rossi"],
    )

    assert "Maria" not in anonymized
    assert "Rossi" not in anonymized
    assert "ROSSI" not in anonymized
    assert anonymized.count("[NOME]") == 3
    assert "referto di Milo" in anonymized


def test_a_known_name_is_matched_as_a_whole_word_only() -> None:
    # "Rosa" must not be cut out of "rosata", nor "Leo" out of "leone".
    anonymized = _anonymize(
        "La mucosa è rosata e il leone di peluche è il suo gioco.", names=["Rosa Leo"]
    )

    assert anonymized == "La mucosa è rosata e il leone di peluche è il suo gioco."


def test_very_short_or_generic_name_parts_are_ignored() -> None:
    anonymized = _anonymize("Il referto della clinica è di ieri.", names=["Li Della Valle"])

    assert "della clinica" in anonymized
    assert "di ieri" in anonymized


def test_an_unlabelled_name_is_not_recognised() -> None:
    # Documented limit: no name recognition. Kept as a test so the limit
    # stays a known, visible fact rather than a surprise.
    assert _anonymize("Ieri Giovanni ha portato Rex dal vet") == (
        "Ieri Giovanni ha portato Rex dal vet"
    )


def test_result_reports_what_was_found() -> None:
    result = RuleBasedPiiAnonymizer().anonymize(
        PiiAnonymizationRequest(text="mail a@b.example, tel 3331234567, microchip 380260101234567")
    )

    assert result.redaction_count == 2
    assert result.entity_types_found == ["EMAIL", "TELEFONO"]
