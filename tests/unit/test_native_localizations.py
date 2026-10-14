import re
from pathlib import Path
from xml.etree import ElementTree

import pytest

RESOURCES = Path(__file__).resolve().parents[2] / "apps/mobile_app/android/app/src/main/res"


def _messages(folder: str) -> dict[str, str]:
    root = ElementTree.parse(RESOURCES / folder / "strings.xml").getroot()
    return {node.attrib["name"]: node.text or "" for node in root.findall("string")}


@pytest.mark.parametrize("language", ["it", "en", "es", "fr"])
def test_android_strings_have_complete_keys_and_format_tokens(language: str) -> None:
    source = _messages("values")
    translated = _messages(f"values-{language}")
    assert set(translated) == set(source)
    for key, message in translated.items():
        assert message.strip(), key
        assert re.findall(r"%(?:\d+\$)?[ds]|%%", message) == re.findall(
            r"%(?:\d+\$)?[ds]|%%", source[key]
        ), key
