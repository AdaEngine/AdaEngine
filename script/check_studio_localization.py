"""Validate Studio's English/Russian catalogs and explicit Swift message keys."""

import json
from pathlib import Path
import re
import sys


SOURCE = Path(__file__).resolve().parents[1] / "Editor/Sources/AdaEditor"
CATALOGS = SOURCE / "Assets/Localization"
PLACEHOLDER = re.compile(r"\{\d+\}")


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate translation key: " + key)
        result[key] = value
    return result


def swift_message(source, start):
    """Read a Swift literal, replacing balanced interpolations with {n}."""
    cursor = start + 1
    result = ""
    argument = 0
    while cursor < len(source):
        character = source[cursor]
        if character == '"':
            return cursor + 1, result
        if source.startswith("\\(", cursor):
            depth = 1
            cursor += 2
            while depth and cursor < len(source):
                if source[cursor] == '"':
                    cursor, _ = swift_message(source, cursor)
                    continue
                if source[cursor] == "(":
                    depth += 1
                elif source[cursor] == ")":
                    depth -= 1
                cursor += 1
            result += "{" + str(argument) + "}"
            argument += 1
            continue
        if character == "\\":
            cursor += 1
            character = source[cursor]
            if character == "u" and source[cursor + 1] == "{":
                end = source.index("}", cursor + 2)
                result += chr(int(source[cursor + 2:end], 16))
                cursor = end + 1
                continue
            character = {"n": "\n", "r": "\r", "t": "\t"}.get(character, character)
        result += character
        cursor += 1
    raise ValueError("Unterminated localized Swift literal")


def main():
    catalogs = {
        language: json.loads((CATALOGS / (language + ".json")).read_text(encoding="utf-8"), object_pairs_hook=unique_object)
        for language in ("en", "ru")
    }
    english, russian = catalogs["en"], catalogs["ru"]
    errors = []
    for language, strings in catalogs.items():
        if strings.keys() != english.keys():
            errors.append(language + ": catalog keys differ from English")
        for key, value in strings.items():
            if not isinstance(value, str) or not value.strip():
                errors.append(language + ": empty or invalid translation: " + key)
            elif sorted(PLACEHOLDER.findall(key)) != sorted(PLACEHOLDER.findall(value)):
                errors.append(language + ": interpolation mismatch: " + key)

    for path in SOURCE.rglob("*.swift"):
        source = path.read_text(encoding="utf-8")
        for match in re.finditer(r'\bL10n\.(?:text|tr)\(\s*(")', source):
            _, key = swift_message(source, match.start(1))
            if key not in english or key not in russian:
                line = source.count("\n", 0, match.start()) + 1
                errors.append(str(path.relative_to(SOURCE)) + ":" + str(line) + ": missing translation: " + key)
    if errors:
        print("\n".join(errors))
        return 1
    print("Studio localization OK: " + str(len(english)) + " messages in English and Russian; placeholders and explicit keys match.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
