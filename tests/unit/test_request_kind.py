import pytest

from packages.core.domain.conversation.request_kind import (
    RequestKind,
    asks_to_stop_questions,
    classify_request,
    consecutive_question_turns,
    is_question_only,
    looks_like_document,
    may_ask_before_answering,
)

QUESTION = "Capisco. Da quanto tempo lo vedi così? Mangia e beve normalmente?"
ANSWER = (
    "Un cane un po' mogio per un giorno, che però mangia e beve, di solito non è "
    "niente di serio: può essere stanchezza o caldo. Tienilo d'occhio oggi e domani."
)


@pytest.mark.parametrize(
    "message",
    [
        "Mi spieghi il referto degli esami del sangue?",
        "spiegami il referto",
        "spiegami l'esame delle urine",
        "Mi spieghi l'ecografia?",
        "cosa dice l'emocromo? devo preoccuparmi?",
        "ho caricato l'esame delle feci, me lo spieghi?",
        "Gli esami sono a posto?",
        "Cosa significa che la creatinina è alta?",
        "il veterinario mi ha detto creatinina 2,4 e urea 80, cosa vuol dire?",
        "non c'entrano i sintomi, voglio solo capire cosa c'è scritto nel referto",
    ],
)
def test_asking_to_explain_a_document_or_a_value_is_a_report_request(message: str) -> None:
    assert classify_request(message) is RequestKind.REPORT


@pytest.mark.parametrize(
    "message",
    [
        "cosa vuol dire ipoecogeno?",
        "cos'è la giardia?",
        "quante volte al giorno deve mangiare?",
        "può mangiare la lattuga?",
        "ogni quanto devo cambiare l'acqua?",
        "ogni quanto va fatto il controllo del sangue?",
        "come gli insegno a non tirare al guinzaglio?",
        "quando deve fare i vaccini?",
        "quanti anni ha e quanto pesa?",
        "cosa sai di Micia?",
        "il nodulo alla milza è un tumore?",
        "con questi valori quanto le resta da vivere?",
    ],
)
def test_an_explicit_self_contained_question_is_answered_directly(message: str) -> None:
    assert classify_request(message) is RequestKind.DIRECT


@pytest.mark.parametrize(
    "message",
    [
        "Toby è mogio",
        "mangia un po' meno da ieri, per il resto mi sembra normale",
        "da due giorni zoppica dalla zampa posteriore",
        "si gratta spesso le orecchie da una settimana",
        "è normale che vomiti dopo mangiato?",
        "ha fatto l'esame delle urine ieri e adesso vomita",
        "c'è sangue nelle urine",
    ],
)
def test_something_wrong_with_the_animal_is_a_symptom_report(message: str) -> None:
    assert classify_request(message) is RequestKind.SYMPTOM


def test_a_file_attached_to_the_message_is_the_subject() -> None:
    assert classify_request("cosa dice?", has_attachment=True) is RequestKind.REPORT
    assert classify_request("ecco", has_attachment=True) is RequestKind.REPORT
    # A symptom described alongside a file stays a symptom report.
    assert classify_request("vomita da ieri", has_attachment=True) is RequestKind.SYMPTOM


def test_a_photo_of_the_animal_is_not_a_document() -> None:
    assert looks_like_document("Referto esami ematochimici. Creatinina 3,1 mg/dL (rif. 0,8-2,0)")
    assert not looks_like_document("Un cane sdraiato sul divano, pelo lucido, occhi aperti")


@pytest.mark.parametrize(
    "message",
    [
        "non c'entrano i sintomi",
        "voglio solo capire il referto",
        "non saprei dire altro",
        "non lo so",
        "rispondi e basta",
        "te l'ho già detto",
    ],
)
def test_the_owner_can_stop_the_questions(message: str) -> None:
    assert asks_to_stop_questions(message)


def test_an_ordinary_reply_does_not_stop_the_questions() -> None:
    assert not asks_to_stop_questions("da ieri sera, e non sta bene")
    assert not asks_to_stop_questions("sì mangia normalmente")


def test_a_reply_of_questions_only_is_recognised() -> None:
    assert is_question_only(QUESTION)
    assert not is_question_only(ANSWER)
    # A real answer closing with one optional question is not "only questions".
    assert not is_question_only(ANSWER * 4 + " Vuoi che ti spieghi anche cosa osservare?")


def test_question_turns_are_counted_from_the_most_recent_reply() -> None:
    assert consecutive_question_turns([]) == 0
    assert consecutive_question_turns([QUESTION]) == 1
    assert consecutive_question_turns([ANSWER, QUESTION, QUESTION]) == 2
    assert consecutive_question_turns([QUESTION, QUESTION, ANSWER]) == 0


def test_questions_before_an_answer_are_only_for_symptoms_and_only_twice_in_a_row() -> None:
    def may_ask(kind: RequestKind, turns: int = 0, stop: bool = False) -> bool:
        return may_ask_before_answering(kind, question_turns_in_a_row=turns, owner_said_stop=stop)

    assert may_ask(RequestKind.SYMPTOM)
    assert may_ask(RequestKind.SYMPTOM, turns=1)
    assert not may_ask(RequestKind.SYMPTOM, turns=2)
    assert not may_ask(RequestKind.SYMPTOM, stop=True)
    assert not may_ask(RequestKind.REPORT)
    assert not may_ask(RequestKind.DIRECT)
