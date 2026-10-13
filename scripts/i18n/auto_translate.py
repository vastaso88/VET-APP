"""Incremental DeepL drafts for Flutter, backend and Android; never publishes."""

from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import json
import os
import re
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from xml.etree import ElementTree as ET
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path("docs/i18n/source_manifest.json")
ARB = Path("apps/mobile_app/lib/l10n")
BACKEND = Path("packages/core/domain/localization.py")
NATIVE = Path("apps/mobile_app/android/app/src/main/res")
LANGUAGES = ("en", "es")


def digest(value: object) -> str:
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, ensure_ascii=False).encode()
    ).hexdigest()


def protected_xml(message: str) -> tuple[str, list[str]]:
    """Preserve ICU grammar, Python placeholders, Android formats and separators."""
    tokens: list[str] = []

    def protect(value: str) -> str:
        tokens.append(value)
        return f'<x id="{len(tokens) - 1}">{escape(value)}</x>'

    def closing(text: str, start: int) -> int:
        depth = 0
        for index in range(start, len(text)):
            depth += (text[index] == "{") - (text[index] == "}")
            if depth == 0:
                return index
        raise ValueError("Unbalanced ICU braces")

    def literal(text: str) -> str:
        result: list[str] = []
        position = 0
        for match in re.finditer(r"%(?:\d+\$)?[ds]|%%|\||#|\\['\"n]", text):
            result.extend((escape(text[position : match.start()]), protect(match[0])))
            position = match.end()
        result.append(escape(text[position:]))
        return "".join(result)

    def parse(text: str) -> str:
        result: list[str] = []
        position = 0
        while position < len(text):
            start = text.find("{", position)
            if start < 0:
                result.append(literal(text[position:]))
                break
            result.append(literal(text[position:start]))
            end = closing(text, start)
            content = text[start + 1 : end]
            header = re.match(
                r"\s*\w+\s*,\s*(plural|selectordinal|select)\s*,\s*(?:offset:\d+\s*)?", content
            )
            if header is None:
                if "{" in content:
                    raise ValueError("Unsupported ICU argument")
                result.append(protect(text[start : end + 1]))
            else:
                result.append(protect("{" + header[0]))
                cursor = header.end()
                while cursor < len(content):
                    selector = re.match(r"\s*(?:=\d+|\w+)\s*\{", content[cursor:])
                    if selector is None:
                        if content[cursor:].strip():
                            raise ValueError("Unsupported ICU selector")
                        result.append(protect(content[cursor:]))
                        break
                    body_start = cursor + selector.end() - 1
                    body_end = closing(content, body_start)
                    result.extend(
                        (
                            protect(selector[0]),
                            parse(content[body_start + 1 : body_end]),
                            protect("}"),
                        )
                    )
                    cursor = body_end + 1
                result.append(protect("}"))
            position = end + 1
        return "".join(result)

    return "<text>" + parse(message) + "</text>", tokens


def restore_xml(value: str, tokens: list[str]) -> str:
    root = ET.fromstring(value)
    if root.tag != "text" or len(root) != len(tokens):
        raise ValueError("Translator changed protected message structure")
    result = [root.text or ""]
    for index, node in enumerate(root):
        if (
            node.tag != "x"
            or node.attrib != {"id": str(index)}
            or node.text != tokens[index]
            or len(node)
        ):
            raise ValueError("Translator changed protected placeholders or ICU grammar")
        result.extend((tokens[index], node.tail or ""))
    return "".join(result)


def deepl(message: str, language: str) -> str:
    key = os.environ.get("DEEPL_API_KEY", "")
    if not key:
        raise ValueError("Configure DEEPL_API_KEY to generate translation drafts")
    endpoint = "https://api-free.deepl.com" if key.endswith(":fx") else "https://api.deepl.com"
    xml, tokens = protected_xml(message)
    body: dict[str, Any] = {
        "text": [xml],
        "source_lang": "IT",
        "target_lang": "EN-GB" if language == "en" else "ES",
        "tag_handling": "xml",
        "ignore_tags": ["x"],
        "preserve_formatting": True,
        "context": (
            "Veterinary companion app. Clear, empathetic UI. "
            "Preserve medical meaning and negations."
        ),
    }
    glossary = os.environ.get(f"DEEPL_GLOSSARY_{language.upper()}")
    if glossary:
        body["glossary_id"] = glossary
    request = Request(
        endpoint + "/v2/translate",
        data=json.dumps(body).encode(),
        headers={
            "Authorization": "DeepL-Auth-Key " + key,
            "Content-Type": "application/json",
        },
    )
    try:
        with urlopen(request, timeout=45) as response:
            data = json.load(response)
    except (HTTPError, URLError) as error:
        code = error.code if isinstance(error, HTTPError) else "network"
        raise ValueError(f"DeepL request failed ({code}); no credentials logged") from None
    result = restore_xml(data["translations"][0]["text"], tokens)
    if not result.strip():
        raise ValueError("Translator returned an empty message")
    return result


class Catalogs:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.arbs = {
            lang: json.loads((root / ARB / f"app_{lang}.arb").read_text(encoding="utf-8"))
            for lang in ("it", *LANGUAGES)
        }
        self.backend_text = (root / BACKEND).read_text(encoding="utf-8")
        tree = ast.parse(self.backend_text)
        self.backend_node = next(
            node.value
            for node in tree.body
            if isinstance(node, ast.AnnAssign)
            and isinstance(node.target, ast.Name)
            and node.target.id == "_MESSAGES"
        )
        assert self.backend_node is not None
        self.backend: dict[str, dict[str, str]] = ast.literal_eval(self.backend_node)
        self.native = {
            lang: ET.parse(
                root / NATIVE / ("values" if lang == "it" else f"values-{lang}") / "strings.xml"
            )
            for lang in ("it", *LANGUAGES)
        }
        self.entries: dict[str, dict[str, str]] = {}
        self.sources: dict[str, str] = {}
        for key, value in self.arbs["it"].items():
            if not key.startswith("@"):
                name = "ui:" + key
                self.entries[name] = {
                    lang: self.arbs[lang].get(key, "") for lang in ("it", *LANGUAGES)
                }
                self.sources[name] = digest([value, self.arbs["it"].get("@" + key)])
        for key, values in self.backend.items():
            self.entries["backend:" + key] = values.copy()
        for element in self.native["it"].getroot().findall("string"):
            key = element.attrib["name"]
            self.entries["android:" + key] = {
                lang: next(
                    (
                        node.text or ""
                        for node in tree.getroot().findall("string")
                        if node.attrib["name"] == key
                    ),
                    "",
                )
                for lang, tree in self.native.items()
            }
        for name, values in self.entries.items():
            self.sources.setdefault(name, digest(values["it"]))

    def snapshot(self) -> dict[str, Any]:
        return {
            name: {
                "source": self.sources[name],
                "targets": {lang: digest(values.get(lang, "")) for lang in LANGUAGES},
            }
            for name, values in self.entries.items()
        }

    def save(self, destination: Path) -> None:
        for name, values in self.entries.items():
            domain, key = name.split(":", 1)
            for lang in LANGUAGES:
                if domain == "ui":
                    self.arbs[lang][key] = values[lang]
                    if "@" + key in self.arbs["it"]:
                        self.arbs[lang]["@" + key] = copy.deepcopy(self.arbs["it"]["@" + key])
                elif domain == "backend":
                    self.backend[key][lang] = values[lang]
                else:
                    tree = self.native[lang]
                    node = next(
                        (
                            node
                            for node in tree.getroot().findall("string")
                            if node.attrib["name"] == key
                        ),
                        None,
                    )
                    if node is None:
                        node = ET.SubElement(tree.getroot(), "string", name=key)
                    node.text = values[lang]
        for lang in LANGUAGES:
            write_json(destination / ARB / f"app_{lang}.arb", self.arbs[lang])
            path = destination / NATIVE / f"values-{lang}" / "strings.xml"
            path.parent.mkdir(parents=True, exist_ok=True)
            ET.indent(self.native[lang], space="    ")
            self.native[lang].write(path, encoding="utf-8", xml_declaration=True)
        backend_node = self.backend_node
        assert backend_node is not None
        assert backend_node.end_lineno is not None and backend_node.end_col_offset is not None
        lines = self.backend_text.encode().splitlines(keepends=True)
        start = (
            sum(len(line) for line in lines[: backend_node.lineno - 1]) + backend_node.col_offset
        )
        end = (
            sum(len(line) for line in lines[: backend_node.end_lineno - 1])
            + backend_node.end_col_offset
        )
        value = json.dumps(self.backend, ensure_ascii=False, indent=4).encode()
        path = destination / BACKEND
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(
            self.backend_text.encode()[:start] + value + self.backend_text.encode()[end:]
        )


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def pending(catalogs: Catalogs, manifest: dict[str, Any]) -> list[tuple[str, str]]:
    return [
        (name, lang)
        for name, values in catalogs.entries.items()
        for lang in LANGUAGES
        if not values.get(lang, "").strip()
        or manifest.get(name, {}).get("source") != catalogs.sources[name]
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("check", "acknowledge", "draft"))
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--max-messages", type=int, default=100)
    args = parser.parse_args()
    catalogs = Catalogs(args.root)
    path = args.root / MANIFEST
    manifest = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    changes = pending(catalogs, manifest)
    if args.mode == "check":
        for name, language in changes:
            print(f"Translation needs update/review: {name} -> {language}")
        return int(bool(changes))
    if args.mode == "acknowledge":
        if any(
            not values.get(lang, "").strip()
            for values in catalogs.entries.values()
            for lang in LANGUAGES
        ):
            raise ValueError("Cannot acknowledge missing translations")
        write_json(path, catalogs.snapshot())
        return 0
    if args.output is None or args.output.resolve() == args.root.resolve():
        raise ValueError("Draft output must be separate from the working repository")
    if len(changes) > args.max_messages:
        raise ValueError(
            f"{len(changes)} messages exceed cost limit {args.max_messages}; "
            "review before raising it"
        )
    report: list[str] = []
    for name, language in changes:
        values = catalogs.entries[name]
        old_target = manifest.get(name, {}).get("targets", {}).get(language)
        if values.get(language) and (
            name not in manifest or (old_target and digest(values[language]) != old_target)
        ):
            report.append(f"MANUAL REVIEW (translation already edited): {name} -> {language}")
            continue
        values[language] = deepl(values["it"], language)
        if name.startswith("android:"):
            values[language] = re.sub(r"(?<!\\)(['\"])", r"\\\1", values[language])
        report.append(f"MACHINE DRAFT - HUMAN REVIEW REQUIRED: {name} -> {language}")
    if changes:
        catalogs.save(args.output)
        write_json(args.output / MANIFEST, catalogs.snapshot())
        (args.output / "TRANSLATION_REVIEW.txt").write_text(
            "\n".join(report) + "\n", encoding="utf-8"
        )
    print(f"Prepared {len(changes)} translation updates; no files published or merged.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
