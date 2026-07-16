#!/bin/sh
set -eu

# ---------------------------------------------------------------------------
# copy_archive_dsyms.sh
#
# Runs as the Runner target's "Copy SPM dSYMs" build phase (archive / install
# builds only). Forwards every dSYM that Xcode does NOT collect on its own into
# the archive's dSYMs folder, so App Store Connect can symbolicate crashes and
# the "Upload Symbols Failed / the archive did not include a dSYM ..." warning
# disappears.
#
# Two sources are handled:
#
#   1. Swift Package Manager binary dependencies (e.g. Sentry.xcframework) that
#      ship a prebuilt dSYM under DerivedData/.../SourcePackages/artifacts.
#
#   2. Flutter native-asset ("code asset") frameworks such as
#      objective_c.framework (pulled in by flutter_secure_storage_darwin).
#      Flutter's build generates a correct, fully-symbolicated dSYM (dsymutil
#      runs before the dylib is stripped) but only copies it into
#      BUILT_PRODUCTS_DIR — which during an *archive* is not the archive dSYMs
#      folder (DWARF_DSYM_FOLDER_PATH). So the dSYM exists but never reaches the
#      .xcarchive. We forward it here.
# ---------------------------------------------------------------------------

# Only meaningful for archive / `xcodebuild install` builds. Regular
# debug/run builds neither produce nor need an archive dSYMs folder.
if [ "${ACTION:-}" != "install" ]; then
  exit 0
fi

DSYM_DEST="${DWARF_DSYM_FOLDER_PATH:-}"
if [ -z "${DSYM_DEST}" ]; then
  echo "warning: DWARF_DSYM_FOLDER_PATH is not set; skipping dSYM archival."
  exit 0
fi
mkdir -p "${DSYM_DEST}"

# Copy a single .dSYM bundle into the archive dSYMs folder (idempotent).
install_dsym() {
  src="$1"
  [ -n "${src}" ] || return 0
  [ -d "${src}" ] || return 0
  dest="${DSYM_DEST}/$(basename "${src}")"
  # Never copy a dSYM onto itself (happens on non-archive builds where
  # BUILT_PRODUCTS_DIR == DWARF_DSYM_FOLDER_PATH).
  if [ "${src}" = "${dest}" ]; then
    return 0
  fi
  rm -rf "${dest}"
  cp -a "${src}" "${dest}"
  echo "note: Archived dSYM $(basename "${src}")"
}

# 1) SPM binary dependencies (Sentry, etc.).
PACKAGES_PATH="${BUILD_DIR%Build/*}SourcePackages/artifacts"
if [ -d "${PACKAGES_PATH}" ]; then
  find "${PACKAGES_PATH}" -name "*.dSYM" -type d | while IFS= read -r dsym; do
    install_dsym "${dsym}"
  done
fi

# 2) Flutter native-asset frameworks (objective_c.framework, and any future
#    code-asset plugin). Flutter drops both the framework and its sibling
#    "<name>.framework.dSYM" into BUILT_PRODUCTS_DIR (and BUILT_PRODUCTS_DIR/
#    native_assets/); pick up whichever is present.
for base in "${BUILT_PRODUCTS_DIR:-}" "${BUILT_PRODUCTS_DIR:-}/native_assets"; do
  [ -n "${base}" ] || continue
  [ -d "${base}" ] || continue
  for dsym in "${base}"/*.framework.dSYM; do
    install_dsym "${dsym}"
  done
done

exit 0
