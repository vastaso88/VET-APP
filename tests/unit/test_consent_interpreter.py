from packages.core.application.services.consent_interpreter import ConsentInterpreter


def test_interprets_short_affirmative_replies() -> None:
    interpreter = ConsentInterpreter()

    assert interpreter.interpret("Sì") is True
    assert interpreter.interpret("si, grazie") is True
    assert interpreter.interpret("Ok") is True
    assert interpreter.interpret("Certo, vai pure") is True


def test_interprets_short_negative_replies() -> None:
    interpreter = ConsentInterpreter()

    assert interpreter.interpret("No") is False
    assert interpreter.interpret("no grazie") is False
    assert interpreter.interpret("Preferisco di no") is False


def test_does_not_false_positive_on_words_containing_no() -> None:
    interpreter = ConsentInterpreter()

    # "Nome", "nostro" etc. contain "no" as a substring — must not be read
    # as a decline just because of that.
    assert interpreter.interpret("Nome del referto? Non lo ricordo bene") is None
    assert interpreter.interpret("Il nostro veterinario ne ha parlato ieri") is None


def test_unclear_reply_returns_none() -> None:
    interpreter = ConsentInterpreter()

    assert interpreter.interpret("Boh, non saprei cosa dirti") is None
    assert interpreter.interpret("") is None
    assert interpreter.interpret("   ") is None
