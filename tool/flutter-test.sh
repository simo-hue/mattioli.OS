#!/bin/bash
#
# Run `flutter test` for one package, serialised against every other invocation
# for that same package.
#
# WHY THIS EXISTS
# ---------------
# `flutter test` rebuilds native code assets into the package's SHARED
# `build/native_assets/<os>/` directory on every invocation
# (testCompilerBuildNativeAssets -> installCodeAssets -> _copyNativeCodeAssetsForOS).
# Two invocations against the same package therefore race over the same files,
# and the loser fails with one of:
#
#   error: install_name_tool: can't open file:
#       .../build/native_assets/macos/objective_c.dylib (No such file or directory)
#   FileSystemException: Deletion failed, OS Error: No such file or directory, errno = 2
#       (a flutter TOOL CRASH, not a test failure)
#
# The damage lands on whichever test file happened to be compiling at that
# moment, so the failure looks random and looks like it belongs to the test.
# It does not. It was recorded in TO_SIMO_DO.md for months as "borderline
# pumpAndSettle timing in evolve_controls_test.dart"; that diagnosis was wrong.
# `flutter_test` drives a FAKE clock, so `pumpAndSettle` cannot run out of time
# because the machine is busy — and evolve_controls_test.dart passes 6/6 alone
# and passes under 24-way CPU saturation in 3 seconds.
#
# It bites whenever two test runs overlap: two terminals, a watch task, an IDE
# runner, CI matrix jobs sharing a checkout, or — the way it actually happened
# here — several agents each running the suite in the same working tree.
#
# `FLUTTER_BUILD_DIR` does NOT help: it does not relocate `build/native_assets`,
# which is the directory that races. Serialising is the fix that works.
#
# USAGE
#   tool/flutter-test.sh <package-dir> [extra flutter test args...]
#   tool/flutter-test.sh desktop
#   tool/flutter-test.sh mobile test/private_db_recovery_test.dart
#
# Waits for the lock rather than failing, so it is a drop-in replacement.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <package-dir> [flutter test args...]" >&2
  exit 2
fi

PKG="$1"; shift
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$REPO_ROOT/$PKG"

if [ ! -f "$PKG_DIR/pubspec.yaml" ]; then
  echo "error: $PKG_DIR is not a Dart/Flutter package (no pubspec.yaml)" >&2
  exit 2
fi

# The desktop and mobile apps read their Supabase config from --dart-define with
# no committed fallback, so a bare `flutter test` fails
# desktop_supabase_config_security_test BY DESIGN. Supply the same dummy values
# CI uses, unless the caller already passed their own.
DEFINES=()
case "$PKG" in
  desktop|mobile)
    if [[ "$*" != *EVOLVE_SUPABASE_URL* ]]; then
      DEFINES+=(--dart-define=EVOLVE_SUPABASE_URL=https://dummy.supabase.co)
      DEFINES+=(--dart-define=EVOLVE_SUPABASE_PUBLISHABLE_KEY=dummy_key)
    fi
    ;;
esac

# One lock per package: different packages have different build directories and
# genuinely can run in parallel, which is most of the available speed-up.
LOCK_DIR="${TMPDIR:-/tmp}/evolve-flutter-test-locks"
mkdir -p "$LOCK_DIR"
LOCK_FILE="$LOCK_DIR/$(echo "$PKG" | tr '/' '_').lock"

# macOS ships no flock(1). Use a directory as the mutex: mkdir is atomic on every
# POSIX filesystem, and a stale lock from a killed run is reclaimed by age.
MUTEX="$LOCK_FILE.d"
WAITED=0
while ! mkdir "$MUTEX" 2>/dev/null; do
  # Reclaim a lock whose owner is gone (or that outlived any plausible run).
  if [ -f "$MUTEX/pid" ]; then
    OWNER="$(cat "$MUTEX/pid" 2>/dev/null || echo '')"
    if [ -n "$OWNER" ] && ! kill -0 "$OWNER" 2>/dev/null; then
      echo "[flutter-test] reclaiming lock from dead pid $OWNER" >&2
      rm -rf "$MUTEX"
      continue
    fi
  fi
  if [ "$WAITED" -ge 1800 ]; then
    echo "[flutter-test] gave up waiting 30m for $PKG; is a run wedged?" >&2
    exit 1
  fi
  if [ "$WAITED" -eq 0 ]; then
    echo "[flutter-test] another '$PKG' test run holds the build dir; waiting…" >&2
  fi
  sleep 2
  WAITED=$((WAITED + 2))
done
echo $$ > "$MUTEX/pid"
trap 'rm -rf "$MUTEX"' EXIT INT TERM

cd "$PKG_DIR"
exec flutter test "${DEFINES[@]}" "$@"
