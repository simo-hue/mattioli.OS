#!/usr/bin/env python3
"""
ARB -> slang JSON converter (the migration "crosswalk" engine).

Phase 0 (bootstrap): performs a lossless 1:1 import of the existing
Flutter gen_l10n ARB files (`lib/l10n/app_<locale>.arb`) into slang's
nested-JSON format (`lib/i18n/<locale>.i18n.json`), keeping the current
(flat) key names so the new `t.*` API works alongside the old system.

Why flat first: the semantic re-nesting of 1,684 keys is the per-feature,
independently-reviewable work (Phases 1..N). Doing it here in one shot would
be exactly the unreviewable big-bang we rejected. Each later phase moves a
feature's keys from the flat root into its semantic namespace
(e.g. `settings.appearance.darkMode`) *together with* its call sites.

Conversion rules:
  - Drop ARB tooling keys: `@@locale` and every `@<key>` metadata block.
  - Keep values verbatim, including `{placeholder}` tokens — these map
    directly to slang's `string_interpolation: braces`.
  - Preserve key order (clean diffs; ARB order is otherwise arbitrary).

Re-running is safe and deterministic (pure function of the ARB inputs).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

# Locales handled by this one-time Phase-0 bootstrap (flat ARB -> flat slang JSON).
# Arabic is NOT listed here on purpose: by the time `ar` was re-enabled, the slang
# JSON had already moved to hand-maintained *nested* namespaces (Phases 1..N), so
# this flat bootstrap is obsolete for it — it would write flat keys and, in any
# case, the guard in main() now aborts because the targets are nested. Arabic is
# therefore authored directly as the nested lib/i18n/ar.i18n.json (same as the
# other locales today); slang auto-discovers it. Do NOT add "ar" here.
LOCALES = ["en", "it", "es", "de"]

MOBILE_ROOT = Path(__file__).resolve().parent.parent
ARB_DIR = MOBILE_ROOT / "lib" / "l10n"
OUT_DIR = MOBILE_ROOT / "lib" / "i18n"


def convert_one(locale: str) -> tuple[int, int]:
    src = ARB_DIR / f"app_{locale}.arb"
    if not src.exists():
        raise FileNotFoundError(f"Missing ARB file: {src}")

    raw = json.loads(src.read_text(encoding="utf-8"))

    out: dict[str, str] = {}
    skipped_meta = 0
    for key, value in raw.items():
        if key.startswith("@"):  # @@locale and @<key> metadata blocks
            skipped_meta += 1
            continue
        out[key] = value

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    dst = OUT_DIR / f"{locale}.i18n.json"
    dst.write_text(
        json.dumps(out, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return len(out), skipped_meta


def main() -> int:
    # Safety: from Phase 1 on, the lib/i18n/*.i18n.json files are hand-maintained
    # (nested semantic namespaces). This converter is a ONE-TIME Phase-0 bootstrap —
    # refuse to run if a target already contains nested objects, so we never flatten
    # / clobber migrated namespaces back to the old flat keys. See LOCALIZATION_PLAN.md.
    for loc in LOCALES:
        dst = OUT_DIR / f"{loc}.i18n.json"
        if dst.exists():
            existing = json.loads(dst.read_text(encoding="utf-8"))
            if any(isinstance(v, dict) for v in existing.values()):
                print(
                    f"ABORT: {dst} already has nested namespaces — the JSON is now "
                    "hand-maintained. This bootstrap converter must not be re-run "
                    "(it would flatten migrated namespaces). See LOCALIZATION_PLAN.md."
                )
                return 2

    summary: dict[str, int] = {}
    for loc in LOCALES:
        keys, meta = convert_one(loc)
        summary[loc] = keys
        print(f"  {loc}: {keys} keys written  ({meta} metadata entries dropped)")

    # Integrity check: every locale must carry the same key set as the base.
    base = json.loads((OUT_DIR / "en.i18n.json").read_text(encoding="utf-8"))
    base_keys = set(base)
    ok = True
    for loc in LOCALES:
        if loc == "en":
            continue
        cur = set(json.loads((OUT_DIR / f"{loc}.i18n.json").read_text(encoding="utf-8")))
        missing = base_keys - cur
        extra = cur - base_keys
        if missing or extra:
            ok = False
            print(f"  ! {loc}: missing={len(missing)} extra={len(extra)}")
            for k in list(missing)[:5]:
                print(f"      missing: {k}")
            for k in list(extra)[:5]:
                print(f"      extra:   {k}")

    counts = set(summary.values())
    print(f"\nKey counts per locale: {summary}")
    print("Parity:", "OK (all locales share the base key set)" if ok else "MISMATCH (see above)")
    return 0 if ok and len(counts) == 1 else 1


if __name__ == "__main__":
    sys.exit(main())
