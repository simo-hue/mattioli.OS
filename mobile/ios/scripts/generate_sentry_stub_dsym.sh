#!/bin/bash
set -euo pipefail

# Xcode embeds Sentry's static framework resources/privacy manifest and injects
# an empty dynamic executable. Its real code/symbols are in Runner/Runner.dSYM,
# but archive validation also expects a dSYM for the injected executable.
[[ "${ACTION:-}" == "install" ]] || exit 0
binary="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/Sentry.framework/Sentry"
[[ -f "$binary" ]] || exit 0
dsym="${DWARF_DSYM_FOLDER_PATH}/Sentry.framework.dSYM"

uuids() {
  /usr/bin/xcrun dwarfdump --uuid "$1" | /usr/bin/awk '{print $2, $3}' | /usr/bin/sort
}
expected="$(uuids "$binary")"
[[ -n "$expected" ]] || { echo 'error: Sentry executable has no UUID'; exit 1; }
if [[ -f "$dsym/Contents/Resources/DWARF/Sentry" ]] && [[ "$(uuids "$dsym")" == "$expected" ]]; then
  exit 0
fi

# Never manufacture an empty dSYM for a real dynamic SDK. Fail if a future
# dependency change ships executable code that needs its original symbols.
if ! /usr/bin/xcrun otool -l "$binary" | /usr/bin/awk '
  $1 == "sectname" { text = ($2 == "__text") }
  text && $1 == "size" { count++; if ($2 !~ /^0x0+$/) nonempty = 1; text = 0 }
  END { if (!count || nonempty) exit 1 }
'; then
  echo 'error: Sentry is not an empty Xcode stub; supply its matching SDK dSYM.'
  exit 1
fi

mkdir -p "$DWARF_DSYM_FOLDER_PATH"
/usr/bin/xcrun dsymutil --quiet "$binary" -o "$dsym"
[[ "$(uuids "$dsym")" == "$expected" ]] || { echo 'error: Sentry dSYM UUID mismatch'; exit 1; }
/usr/bin/xcrun dwarfdump --verify "$dsym" > /dev/null
echo "Sentry resource-framework stub dSYM verified: $expected"
