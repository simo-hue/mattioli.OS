#!/usr/bin/env python3
"""Assemble the App Store metadata whose correctness Apple checks.

That means the localised description (body + legal block) and the two URL
fields that must agree with it: privacy_url.txt and support_url.txt. They are
built together deliberately -- a description that links the German privacy
page while App Store Connect's Privacy Policy field points at the Italian one
is the kind of drift nobody notices until a reviewer does.


Why this script exists
----------------------
iOS 1.1.2 was rejected twice under Guideline 3.1.2(c) for a missing Terms of
Use (EULA) link. The cause was mechanical, not editorial:

  1. The legal block lived at the END of every description.
  2. Descriptions were machine-translated as ONE string, links included.
  3. Nothing enforced App Store Connect's 4000-character ceiling.

Translation expands text. German, Greek and French ran past 4000 characters,
something truncated them to fit, and because the legal block was last it was
the first thing amputated. On 2026-07-30 the live German and French listings
had no Terms link and no Privacy link at all -- verified against
`itunes.apple.com/lookup`, which returned a 3861-character German description
ending in a literal "....".

The fix is structural, and it is the whole point of this file:

  * The body is translated. The legal block is NOT -- it is composed here,
    after translation, from `locales.json` labels and hardcoded URLs. A
    translator can never mangle a URL it never sees.
  * The legal block is appended last but budgeted first. Each locale's body is
    capped at 4000 minus the block that locale actually emits, so the block
    always fits -- rather than the block being whatever survives.
  * Over-budget bodies are a hard error. They are never silently trimmed --
    silent trimming is the bug this replaces.

Usage:
    python3 tool/appstore/build_metadata.py              # build all locales
    python3 tool/appstore/build_metadata.py de-DE fr-FR  # build a subset
"""

from __future__ import annotations

import json
import os
import sys

# App Store Connect's hard ceiling for the Description field.
ASC_DESCRIPTION_LIMIT = 4000

# Characters the assembled file spends on structure: the blank line separating
# body from legal block, and the trailing newline.
SEPARATOR_COST = len("\n\n") + len("\n")

SITE_BASE = "https://simo-hue.github.io/evolve/"

# Apple's standard Terms of Use. Deliberately NOT our own terms.html: naming our
# Terms of Service as the EULA would oblige it to carry Apple's minimum terms,
# including the clause making Apple a third-party beneficiary, and it carries
# none of them. Apple hosts and localises this page itself.
APPLE_EULA_URL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

HERE = os.path.dirname(os.path.abspath(__file__))
MOBILE_ROOT = os.path.dirname(os.path.dirname(HERE))
CONFIG_PATH = os.path.join(HERE, "locales.json")

# The single source of truth for what ships to the App Store. There used to be
# a second tree at mobile/ios/fastlane/metadata holding a different generation
# of copy; the two drifted, copy was moved between them by hand, and that hand
# copying is what truncated the legal block. Do not reintroduce a second tree.
METADATA_DIR = os.path.join(MOBILE_ROOT, "metadata")

# Translated bodies, one file per locale, WITHOUT the legal block. This is what
# a human or a translator edits.
BODIES_DIR = os.path.join(MOBILE_ROOT, "metadata_src", "descriptions")


def privacy_url(site: str) -> str:
    """The privacy policy for a site language directory.

    `site` is "" for locales we do not publish, which resolves to the Italian
    root. That root URL must never move: builds already on the App Store
    hardcode it.
    """
    return f"{SITE_BASE}{site + '/' if site else ''}privacy.html"


def support_url(site: str) -> str:
    """The support page for a site language directory.

    Deliberately support.html and not the site root: Guideline 1.5 fired once
    already because the only support contact anywhere on the site was buried
    inside the Italian privacy page. Half the locales still pointed at the
    homepage, which is not a support page.
    """
    return f"{SITE_BASE}{site + '/' if site else ''}support.html"


def legal_block(cfg: dict) -> str:
    """The mandatory Guideline 3.1.2 links, composed rather than translated."""
    return (
        f"{cfg['terms']}: {APPLE_EULA_URL}\n"
        f"{cfg['privacy']}: {privacy_url(cfg['site'])}"
    )


def build(locale: str, cfg: dict) -> tuple[str, str | None]:
    """Return (description, error). `error` is None on success."""
    body_path = os.path.join(BODIES_DIR, f"{locale}.txt")
    if not os.path.exists(body_path):
        return "", f"missing body: metadata_src/descriptions/{locale}.txt"

    with open(body_path, encoding="utf-8") as handle:
        body = handle.read().strip()

    if not body:
        return "", "body is empty"

    # The budget is derived per locale from the block this locale actually
    # emits, not from a shared guess. Label lengths vary a lot -- Russian and
    # Greek labels are far longer than Japanese ones -- and a fixed reserve
    # would either waste room or, worse, be too small for one language and
    # push it over the ceiling.
    block = legal_block(cfg)
    budget = ASC_DESCRIPTION_LIMIT - len(block) - SEPARATOR_COST

    # Refuse rather than trim. A body over budget means the source copy needs
    # shortening in that language -- it does not mean the legal block is
    # optional, which is exactly the trade the old pipeline made silently.
    if len(body) > budget:
        return "", (
            f"body is {len(body)} chars, over this locale's {budget} budget by "
            f"{len(body) - budget}. Shorten the body; the legal block is not "
            f"negotiable."
        )

    description = f"{body}\n\n{block}\n"

    # Belt and braces: the budget arithmetic should make this unreachable.
    if len(description) > ASC_DESCRIPTION_LIMIT:
        return "", f"assembled description is {len(description)} chars, over {ASC_DESCRIPTION_LIMIT}"

    return description, None


def main(argv: list[str]) -> int:
    with open(CONFIG_PATH, encoding="utf-8") as handle:
        locales = json.load(handle)["locales"]

    wanted = argv[1:] or sorted(locales)
    unknown = [loc for loc in wanted if loc not in locales]
    if unknown:
        print(f"unknown locale(s): {', '.join(unknown)}", file=sys.stderr)
        return 2

    failures: list[str] = []
    for locale in wanted:
        cfg = locales[locale]
        description, error = build(locale, cfg)
        if error:
            failures.append(f"{locale}: {error}")
            print(f"  FAIL  {locale:<9} {error}")
            continue

        out_dir = os.path.join(METADATA_DIR, locale)
        os.makedirs(out_dir, exist_ok=True)
        with open(os.path.join(out_dir, "description.txt"), "w", encoding="utf-8") as handle:
            handle.write(description)

        # Emitted from the same `site` mapping as the description's legal
        # block, so App Store Connect's URL fields can never point at a
        # different language than the links inside the description itself.
        for filename, url in (
            ("privacy_url.txt", privacy_url(cfg["site"])),
            ("support_url.txt", support_url(cfg["site"])),
        ):
            with open(os.path.join(out_dir, filename), "w", encoding="utf-8") as handle:
                handle.write(f"{url}\n")

        print(f"  ok    {locale:<9} {len(description):>4}/{ASC_DESCRIPTION_LIMIT} chars")

    if failures:
        print(f"\n{len(failures)} locale(s) failed:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1

    print(f"\nBuilt {len(wanted)} description(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
