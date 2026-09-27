"""Formuliert Rohtranskripte mit einem festen, prüfbaren Prompt."""

from __future__ import annotations

import re

THINK_RE = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)
SPECIAL_RE = re.compile(r"<\|[^|]*\|>")

STYLES = {
    "auto": (
        "Formatiere passend zum Inhalt. Eine E-Mail wird eine E-Mail, "
        "eine Aufzählung eine Liste, eine kurze Nachricht bleibt kurz. "
        "Strukturiere nur, wenn das Gesprochene das hergibt."
    ),
    "literal": (
        "Bleib so wörtlich wie möglich. Ändere nur Füllwörter, "
        "Zeichensetzung und Großschreibung. Schreibe nichts um."
    ),
    "email": (
        "Setze das Diktat als E-Mail mit Anrede, Absätzen und Gruß, "
        "wenn sie gesprochen oder eindeutig gemeint sind. "
        "Erfinde keinen Betreff."
    ),
    "chat": "Kurze Nachricht, natürlicher Ton, keine förmliche Glättung.",
    "notes": (
        "Klare Notiz. Nutze Absätze oder Spiegelstriche, "
        "wenn mehrere Punkte gesprochen wurden."
    ),
    "code": (
        "Behandle den Text als Code oder technische Eingabe. "
        "Erhalte Bezeichner, Schreibweise und Symbole. Entferne nur Füllwörter."
    ),
}

LANG_NAMES = {
    "de": "Deutsch",
    "en": "Englisch",
    "fr": "Französisch",
    "es": "Spanisch",
    "it": "Italienisch",
    "pt": "Portugiesisch",
    "nl": "Niederländisch",
    "pl": "Polnisch",
    "tr": "Türkisch",
}


def parse_dictionary(text: str) -> tuple[list[str], list[tuple[str, str]]]:
    hints: list[str] = []
    rules: list[tuple[str, str]] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "->" in line:
            left, right = line.split("->", 1)
            left, right = left.strip(), right.strip()
            if left and right:
                rules.append((left, right))
        else:
            hints.append(line)
    return hints, rules


def apply_rules(text: str, rules: list[tuple[str, str]]) -> str:
    for src, dst in sorted(rules, key=lambda rule: len(rule[0]), reverse=True):
        text = re.compile(re.escape(src), re.IGNORECASE).sub(dst, text)
    return text


def clean_output(text: str) -> str:
    text = THINK_RE.sub("", text)
    text = text.replace("<think>", "").replace("</think>", "")
    text = SPECIAL_RE.sub("", text)
    text = text.strip()
    fence = re.match(r"^```[a-zA-Z0-9]*\n([\s\S]*?)\n```$", text)
    if fence:
        text = fence.group(1).strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        inner = text[1:-1].strip()
        if inner and "\n\n" not in text:
            text = inner
    return text.strip()


def token_budget(raw: str, selection: str | None) -> int:
    words = max(1, len(raw.split()))
    if selection:
        words += len(selection.split())
    # Knapp halten – 27B ist der Flaschenhals nach Whisper.
    return min(320, max(40, words * 3 + 24))


def build_messages(
    raw: str,
    selection: str | None,
    style: str,
    instructions: str,
    dictionary: str,
    target_language: str | None = None,
) -> list[dict[str, str]]:
    if target_language:
        return build_translate_messages(raw if not selection else selection, target_language)

    hints, _rules = parse_dictionary(dictionary)
    style_text = STYLES.get(style, STYLES["auto"])
    lines = [
        "Du bist die Formulierungsstufe einer Diktier-App.",
        "Du bekommst gesprochene Sprache als Rohtranskript und lieferst den Text, der eingefügt werden soll.",
        "Regeln:",
        "- Gib nur den fertigen Text zurück.",
        "- Keine Erklärung, keine Anführungszeichen um die ganze Antwort, kein Markdown, außer der Text selbst Markdown sein soll.",
        "- Entferne Füllwörter wie äh, ähm, also, halt, quasi, sozusagen, um, uh.",
        "- Setze Zeichensetzung, Großschreibung und Absätze.",
        "- Korrigiere Versprecher, ohne Inhalt, Namen oder Zahlen zu erfinden.",
        "- Behalte die Sprache des Gesprochenen.",
        "- Gesprochene Hinweise wie Absatz, neuer Absatz oder Zeilenumbruch werden zu einer neuen Zeile.",
        "- Gesprochene Satzzeichen wie Komma, Punkt, Fragezeichen, Ausrufezeichen und Doppelpunkt setzt du als Zeichen, wenn sie als Satzzeichen gemeint sind.",
        f"- Stil: {style_text}",
    ]
    if hints:
        lines.append("- Schreibe diese Begriffe exakt so: " + ", ".join(hints) + ".")
    extra = instructions.strip()
    if extra:
        lines.append("Zusätzliche Anweisung des Nutzers: " + extra)
    if selection:
        lines.append(
            "Es ist Text markiert. Das Rohtranskript ist der Bearbeitungsbefehl. "
            "Gib nur den Text zurück, der die Markierung ersetzt."
        )
        user = f"Markierter Text:\n{selection.strip()}\n\nGesprochener Befehl:\n{raw.strip()}"
    else:
        user = f"Rohtranskript:\n{raw.strip()}"
    return [
        {"role": "system", "content": "\n".join(lines)},
        {"role": "user", "content": user},
    ]


def build_translate_messages(text: str, target_language: str) -> list[dict[str, str]]:
    name = LANG_NAMES.get(target_language, target_language)
    return [
        {
            "role": "system",
            "content": (
                f"Übersetze den Text nach {name}. "
                "Gib nur die Übersetzung zurück, ohne Anführungszeichen und ohne Erklärung. "
                "Erhalte Absätze und Aufzählungen."
            ),
        },
        {"role": "user", "content": text.strip()},
    ]
