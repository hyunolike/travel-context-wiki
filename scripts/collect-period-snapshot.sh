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

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

[ "$#" -eq 2 ] || usage

input_json="$1"
output_dir="$2"

[ -f "$input_json" ] || fail "missing input JSON: $input_json"
jq empty "$input_json" >/dev/null || fail "invalid JSON: $input_json"

period="$(jq -r '.period // empty' "$input_json")"
[ -n "$period" ] || fail "period is required"
printf '%s\n' "$period" | grep -Eq '^[0-9]{4}-(0[1-9]|1[0-2])$' \
  || fail "period must be YYYY-MM: $period"

jq -e '
  (.snapshotId | type == "string" and length > 0) and
  (.sourceKind | type == "string" and length > 0) and
  (.sourceUrl | type == "string" and length > 0) and
  (.license | type == "string" and length > 0) and
  (.collectedAt | type == "string" and length > 0) and
  (.payload | type == "object")
' "$input_json" >/dev/null || fail "period snapshot is missing required source metadata"

mkdir -p "$output_dir"
output_path="$output_dir/$period.json"

# Splitting a growing series into one file per period moves the time axis into
# the file name, so what remains inside a file is an unordered set of regions.
# Normalising it is what makes the immutability check below trustworthy: a
# source that reorders its rows would otherwise read as a restatement and halt
# every run. This is the distinction rule 6 leaves open and rule 9 settles, so
# normalisation is unconditional here rather than an opt-in flag.
jq '
  def canonize: walk(if type == "object" then (to_entries | sort_by(.key) | from_entries) else . end);
  def sort_arrays: walk(if type == "array" then sort_by(tojson) else . end);
  .payload |= (canonize | sort_arrays)
' "$input_json" > "$TMP_DIR/normalised.json" || fail "could not normalise payload: $input_json"

# A period already on disk is contractually immutable. This source restates
# telecom-derived figures after the fact, and overwriting would destroy the
# original reading with no record that it moved. Stop and name the period.
if [ -f "$output_path" ]; then
  jq -S '.payload' "$TMP_DIR/normalised.json" > "$TMP_DIR/incoming-payload.json"
  jq -S '.payload' "$output_path" > "$TMP_DIR/stored-payload.json"
  if cmp -s "$TMP_DIR/incoming-payload.json" "$TMP_DIR/stored-payload.json"; then
    printf 'unchanged period snapshot: %s\n' "$output_path"
    exit 0
  fi
  fail "stored period $period differs from the fetched payload; the source restated history and a human must decide whether to accept it"
fi

jq -S . "$TMP_DIR/normalised.json" > "$output_path"

printf 'captured period snapshot: %s\n' "$output_path"
