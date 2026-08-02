#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s <input-json> <output-dir>\n' "$0" >&2
  exit 2
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ "$#" -eq 2 ] || usage

input_json="$1"
output_dir="$2"

[ -f "$input_json" ] || fail "missing input JSON: $input_json"
jq empty "$input_json" >/dev/null || fail "invalid JSON: $input_json"

capture_id="$(jq -r '.captureId // empty' "$input_json")"
consent_for_wiki="$(jq -r 'if has("consentForWiki") then .consentForWiki else empty end' "$input_json")"
contains_personal_data="$(jq -r 'if has("containsPersonalData") then .containsPersonalData else empty end' "$input_json")"

[ -n "$capture_id" ] || fail "captureId is required"
[ "$consent_for_wiki" = "true" ] || fail "consentForWiki must be true"
[ "$contains_personal_data" = "false" ] || fail "containsPersonalData must be false"

jq -e '
  (.capturedAt | type == "string") and
  (.source | type == "string") and
  (.request.destination | type == "string") and
  (.request.date | type == "string") and
  (.request.preferences | type == "array")
' "$input_json" >/dev/null || fail "user input capture is missing required request fields"

safe_id="$(printf '%s' "$capture_id" | sed 's/[^A-Za-z0-9._-]/-/g')"
[ -n "$safe_id" ] || fail "captureId cannot be converted into a safe file name"

mkdir -p "$output_dir"
output_path="$output_dir/$safe_id.json"
jq -S . "$input_json" > "$output_path"

printf 'captured user input: %s\n' "$output_path"
