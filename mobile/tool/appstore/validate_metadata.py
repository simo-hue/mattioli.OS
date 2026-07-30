#!/usr/bin/env python3
"""Preflight gate for App Store metadata. Run before `fastlane deliver`.

This exists because iOS 1.1.2 was rejected twice under Guideline 3.1.2(c) for a
missing Terms of Use (EULA) link, and both times the breakage was invisible
until Apple found it. On 2026-07-30 the LIVE German and French listings had no
Terms link and no Privacy link -- five localisations had been truncated at the
4000-character ceiling, and the legal block sat at the end of the file where
truncation hits first.

Nothing in the pipeline noticed. This script is what notices.

It checks the shipped tree (mobile/metadata), not the source bodies, because
the shipped tree is what `deliver` uploads -- including any file someone edited
by hand after the build.

Exit codes:
    0  everything passes
    1  at least one blocking problem
    2  the tree or config could not be read
"""

from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOBILE_ROOT = os.path.dirname(os.path.dirname(HERE))
METADATA_DIR = os.path.join(MOBILE_ROOT, "metadata")
CONFIG_PATH = os.path.join(HERE, "locales.json")

# App Store Connect field ceilings.
LIMITS = {
    "name.txt": 30,
    "subtitle.txt": 30,
    "keywords.txt": 100,
    "promotional_text.txt": 170,
    "description.txt": 4000,
    "release_notes.txt": 4000,
}

# Required in every localisation, non-empty.
REQUIRED = ("name.txt", "description.txt", "keywords.txt", "privacy_url.txt", "support_url.txt")

# Guideline 3.1.2: an app offering auto-renewable subscriptions must carry
# functional links to the privacy policy and the Terms of Use (EULA). These
# substrings must survive into every shipped description.
EULA_MARKER = "apple.com/legal/internet-services/itunes/dev/stdeula/"
PRIVACY_MARKER = "simo-hue.github.io/evolve/"

# Directories under metadata/ that are not localisations.
NON_LOCALE_ENTRIES = {"review_information"}


def read(path: str) -> str:
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def check_locale(locale: str, directory: str) -> list[str]:
    problems: list[str] = []

    for filename in REQUIRED:
        path = os.path.join(directory, filename)
        if not os.path.exists(path):
            problems.append(f"missing {filename}")
        elif not read(path).strip():
            problems.append(f"{filename} is empty")

    for filename, limit in LIMITS.items():
        path = os.path.join(directory, filename)
        if not os.path.exists(path):
            continue
        length = len(read(path).strip())
        if length > limit:
            problems.append(f"{filename} is {length} chars, over the {limit} limit")

    description_path = os.path.join(directory, "description.txt")
    if os.path.exists(description_path):
        description = read(description_path)
        stripped = description.strip()

        if EULA_MARKER not in description:
            problems.append("description is missing the Terms of Use (EULA) link — Guideline 3.1.2(c)")
        if PRIVACY_MARKER not in description:
            problems.append("description is missing the privacy policy link — Guideline 3.1.2")

        # The exact signature of the failure that shipped: a machine truncated
        # the text and left an ellipsis where the legal block used to be.
        if stripped.endswith("...") or stripped.endswith("…"):
            problems.append("description ends in an ellipsis — it was truncated")

        # A URL cut mid-string still contains the marker's prefix but is dead.
        # Catch the shape rather than trying to fetch every link.
        for line in stripped.splitlines():
            candidate = line.strip()
            if "http" in candidate and (candidate.endswith("..") or candidate.endswith("…")):
                problems.append(f"truncated URL: {candidate[-60:]}")

    return problems


def main() -> int:
    if not os.path.isdir(METADATA_DIR):
        print(f"metadata directory not found: {METADATA_DIR}", file=sys.stderr)
        return 2

    try:
        with open(CONFIG_PATH, encoding="utf-8") as handle:
            configured = set(json.load(handle)["locales"])
    except (OSError, ValueError, KeyError) as error:
        print(f"could not read {CONFIG_PATH}: {error}", file=sys.stderr)
        return 2

    on_disk = {
        entry
        for entry in os.listdir(METADATA_DIR)
        if os.path.isdir(os.path.join(METADATA_DIR, entry)) and entry not in NON_LOCALE_ENTRIES
    }

    failures: dict[str, list[str]] = {}

    # A locale present on disk but absent from locales.json would ship without a
    # composed legal block, which is precisely how this went wrong before.
    for locale in sorted(on_disk - configured):
        failures[locale] = ["present in metadata/ but not in tool/appstore/locales.json"]

    for locale in sorted(configured - on_disk):
        failures[locale] = ["configured in locales.json but has no metadata/ directory"]

    for locale in sorted(on_disk & configured):
        problems = check_locale(locale, os.path.join(METADATA_DIR, locale))
        if problems:
            failures[locale] = problems

    checked = len(on_disk & configured)
    if not failures:
        print(f"App Store metadata OK — {checked} localisations, all with functional EULA and privacy links.")
        return 0

    print(f"App Store metadata FAILED — {len(failures)} of {checked} localisations have problems:\n", file=sys.stderr)
    for locale, problems in failures.items():
        print(f"  {locale}", file=sys.stderr)
        for problem in problems:
            print(f"    - {problem}", file=sys.stderr)
    print(
        "\nDo not run `fastlane deliver` until this passes. "
        "Guideline 3.1.2(c) rejected this app twice for exactly these defects.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
