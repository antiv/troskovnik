"""What's New text per language, matched to the locales a store listing has.

play_promote.py and asc_submit.py take the notes keyed by language — en, sr,
de — or by full locale — es-419, en-GB — from --notes LANG=TEXT (repeatable)
and/or --notes-file notes.json ({"en": "...", "de": "..."}; --notes wins on a
key both give). The stores name the same language differently (Play it-IT, App
Store it; Play es-419, App Store es-MX), so each script reads the locales the
app's listing actually has and asks match() for each one.

A store locale gets, in this order: the note for exactly that locale; the note
for its language (a bare `es`, or any other `es-*` note); the note for its
stand-in (the App Store has no Serbian, so a Croatian listing takes `sr`); and
otherwise the English note, reported as a fallback so a dry run shows it.
"""

import json

STAND_INS = {"hr": "sr"}


def load(pairs, path, fail):
    notes = {}
    if path:
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, ValueError) as error:
            fail(f"cannot read --notes-file {path}: {error}")
        if not isinstance(data, dict) or not all(isinstance(v, str) and v.strip() for v in data.values()):
            fail(f"--notes-file {path} must be a JSON object of language: non-empty text")
        notes.update({k.lower(): v for k, v in data.items()})
    for pair in pairs or []:
        key, sep, text = pair.partition("=")
        if not sep or not key or not text.strip():
            fail(f"--notes expects LANG=TEXT, got: {pair}")
        notes[key.lower()] = text
    return notes


def _language(key):
    return key.split("-")[0]


def match(notes, locale):
    """(text, source) for a store locale — source names the note used — or (None, None)."""
    wanted = locale.lower()
    if wanted in notes:
        return notes[wanted], wanted
    language = _language(wanted)
    for candidate in [language] + ([STAND_INS[language]] if language in STAND_INS else []):
        if candidate in notes:
            return notes[candidate], candidate
        for key, text in notes.items():
            if _language(key) == candidate:
                return text, key
    for key, text in notes.items():
        if _language(key) == "en":
            return text, f"{key}, fallback"
    return None, None


# Play wants a region on these languages; the rest go as the bare code (sr, hr, sl)
PLAY_REGIONS = {"en": "en-US", "de": "de-DE", "fr": "fr-FR", "es": "es-ES", "it": "it-IT",
                "pt": "pt-PT", "nl": "nl-NL", "pl": "pl-PL", "ru": "ru-RU", "tr": "tr-TR"}


def play_language(key):
    """Play's language code for a note key: de → de-DE, es-419 and sr as they are."""
    if "-" in key:
        language, region = key.split("-", 1)
        return f"{language}-{region.upper()}" if region.isalpha() and len(region) == 2 else key
    return PLAY_REGIONS.get(key, key)


def preview(text, width=50):
    text = " ".join(text.split())
    return text if len(text) <= width else text[:width] + "…"
