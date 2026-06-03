#!/bin/sh
set -eu

required_defines="EVOLVE_SUPABASE_URL EVOLVE_SUPABASE_PUBLISHABLE_KEY"
missing_defines=""

decode_dart_define() {
  if decoded="$(printf '%s' "$1" | base64 --decode 2>/dev/null)"; then
    printf '%s' "$decoded"
    return 0
  fi

  if decoded="$(printf '%s' "$1" | base64 -D 2>/dev/null)"; then
    printf '%s' "$decoded"
    return 0
  fi

  return 1
}

has_non_empty_dart_define() {
  expected_key="$1"
  old_ifs="$IFS"
  IFS=","

  for encoded_define in ${DART_DEFINES:-}; do
    IFS="$old_ifs"
    decoded_define="$(decode_dart_define "$encoded_define" || true)"
    define_key="${decoded_define%%=*}"
    define_value="${decoded_define#*=}"

    if [ "$define_key" = "$expected_key" ] &&
      [ "$define_value" != "$decoded_define" ] &&
      [ -n "$define_value" ]; then
      IFS="$old_ifs"
      return 0
    fi

    IFS=","
  done

  IFS="$old_ifs"
  return 1
}

for define_name in $required_defines; do
  if ! has_non_empty_dart_define "$define_name"; then
    missing_defines="$missing_defines $define_name"
  fi
done

if [ -n "$missing_defines" ]; then
  echo "error: Missing required Flutter dart define(s):$missing_defines" >&2
  echo "error: Build desktop with --dart-define-from-file=.env or explicit --dart-define values." >&2
  exit 1
fi
