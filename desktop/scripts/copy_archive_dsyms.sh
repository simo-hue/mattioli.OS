#!/bin/sh
set -eu

# ---------------------------------------------------------------------------
# copy_archive_dsyms.sh
#
# Runs as the Runner target's "Copy SPM dSYMs" build phase (archive / install
# builds only). Makes sure every framework embedded in the app has a matching
# dSYM in the archive's dSYMs folder, so App Store Connect can symbolicate
# crashes and the "Upload Symbols Failed / the archive did not include a dSYM
# ... with the UUIDs [...]" warning disappears.
#
# Three passes, most-specific first:
#   1. SPM binary dependencies (e.g. Sentry.xcframework) ship a prebuilt dSYM
#      under DerivedData/.../SourcePackages/artifacts.
#   2. Flutter-generated dSYMs. Flutter emits "<name>.framework.dSYM" for its
#      code-asset frameworks (objective_c.framework from
#      flutter_secure_storage_darwin, App.framework, ...) somewhere under
#      BUILT_PRODUCTS_DIR, but only during a fresh (non-incremental) build and
#      it never copies them into the archive's dSYMs folder. Search recursively
#      and forward each real (fully-symbolicated) dSYM we find.
#   3. Fallback guarantee. For any framework still lacking a dSYM in the archive,
#      generate one with dsymutil straight from the embedded binary. If the
#      binary is stripped this yields a UUID-matching dSYM (enough to clear the
#      App Store Connect warning); if it still carries a debug map the dSYM is
#      fully symbolicated. This makes a clean upload deterministic even when
#      pass 2 finds nothing (e.g. an incremental archive that reused a cached
#      native-assets build).
# ---------------------------------------------------------------------------

# Only archive / `xcodebuild install` builds produce (or need) an archive dSYMs
# folder. Regular debug/run builds are a no-op.
if [ "${ACTION:-}" != "install" ]; then
  exit 0
fi

DSYM_DEST="${DWARF_DSYM_FOLDER_PATH:-}"
if [ -z "${DSYM_DEST}" ]; then
  echo "warning: DWARF_DSYM_FOLDER_PATH is not set; skipping dSYM archival."
  exit 0
fi
mkdir -p "${DSYM_DEST}"

log() { echo "note: [copy_archive_dsyms] $*"; }

# Copy a single .dSYM bundle into the archive dSYMs folder (idempotent, safe).
install_dsym() {
  src="$1"
  [ -n "${src}" ] || return 0
  [ -d "${src}" ] || return 0
  dest="${DSYM_DEST}/$(basename "${src}")"
  # Never copy a dSYM onto itself.
  if [ "${src}" = "${dest}" ]; then
    return 0
  fi
  rm -rf "${dest}"
  cp -a "${src}" "${dest}"
  log "forwarded dSYM $(basename "${src}")"
}

# 1) SPM binary dependencies (Sentry, etc.).
PACKAGES_PATH="${BUILD_DIR%Build/*}SourcePackages/artifacts"
if [ -d "${PACKAGES_PATH}" ]; then
  find "${PACKAGES_PATH}" -name "*.dSYM" -type d 2>/dev/null | while IFS= read -r dsym; do
    install_dsym "${dsym}"
  done
fi

# 2) Flutter-generated dSYMs anywhere under BUILT_PRODUCTS_DIR (skip copies that
#    already live in the archive dSYMs dir or inside the built .app bundle).
if [ -n "${BUILT_PRODUCTS_DIR:-}" ] && [ -d "${BUILT_PRODUCTS_DIR}" ]; then
  find "${BUILT_PRODUCTS_DIR}" -name "*.framework.dSYM" -type d 2>/dev/null | while IFS= read -r dsym; do
    case "${dsym}" in
      "${DSYM_DEST}"/*) continue ;;
      *.app/*) continue ;;
    esac
    install_dsym "${dsym}"
  done
fi

# 3) Fallback: guarantee a dSYM for every framework embedded in the built app.
APP="${CODESIGNING_FOLDER_PATH:-}"
if [ -z "${APP}" ] || [ ! -d "${APP}" ]; then
  APP="$(find "${BUILT_PRODUCTS_DIR:-/nonexistent}" -maxdepth 1 -name "*.app" -type d 2>/dev/null | head -n 1)"
fi
if [ -n "${APP}" ] && [ -d "${APP}/Contents/Frameworks" ]; then
  for fw in "${APP}/Contents/Frameworks"/*.framework; do
    [ -d "${fw}" ] || continue
    name="$(basename "${fw}" .framework)"
    bin="${fw}/Versions/A/${name}"
    [ -f "${bin}" ] || bin="${fw}/${name}"
    [ -f "${bin}" ] || continue
    dest="${DSYM_DEST}/${name}.framework.dSYM"
    # A real dSYM was already placed by pass 1/2 or by Xcode itself — check UUIDs.
    if [ -d "${dest}" ]; then
      bin_uuid="$(dwarfdump --uuid "${bin}" | head -n 1 | awk '{print $2}')"
      if [ -n "${bin_uuid}" ] && ! dwarfdump --uuid "${dest}" | grep -q "${bin_uuid}"; then
        log "existing dSYM for ${name} has mismatched UUIDs. Regenerating..."
        rm -rf "${dest}"
      else
        continue
      fi
    fi
    if xcrun dsymutil "${bin}" -o "${dest}" >/dev/null 2>&1; then
      log "generated fallback dSYM ${name}.framework.dSYM"
    else
      rm -rf "${dest}"
      log "could not generate a dSYM for ${name} (skipped)"
    fi
  done
fi

log "archive dSYMs folder now contains:"
ls -1 "${DSYM_DEST}" 2>/dev/null || true
exit 0
