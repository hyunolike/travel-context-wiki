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

# Computed rather than asked of `date`, whose -d spelling differs between the
# GNU date in CI and the BSD date on a developer's machine.
days_in_month() {
  year="${1%%-*}"
  month="${1##*-}"
  month="${month#0}"
  case "$month" in
    1|3|5|7|8|10|12) printf '31\n' ;;
    4|6|9|11) printf '30\n' ;;
    2)
      if [ "$((year % 4))" -eq 0 ] && { [ "$((year % 100))" -ne 0 ] || [ "$((year % 400))" -eq 0 ]; }; then
        printf '29\n'
      else
        printf '28\n'
      fi
      ;;
    *) fail "not a month: $1" ;;
  esac
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

# A period is stored only once the source has published all of it. Storing a
# partial month is not a smaller version of the right thing: the file is
# immutable from the moment it lands, so the complete month arriving later is
# refused by the check below and the period stays wrong for good. The first real
# capture of this series returned nine days of August on the 7th of September,
# which is how the shape of the mistake became known.
#
# The count is taken from the payload rather than from a number the caller
# declares, so a collector cannot assert coverage it does not have. dayField
# names the field that carries a day; the expected count is a pure function of
# the period. A source whose periods carry no day field declares no coverage and
# keeps the old behaviour.
day_field="$(jq -r '.coverage.dayField // empty' "$input_json")"
if [ -n "$day_field" ]; then
  printf '%s\n' "$day_field" | grep -Eq '^[A-Za-z][A-Za-z0-9_]*$' \
    || fail "coverage.dayField must be a plain field name: $day_field"

  expected_days="$(days_in_month "$period")"
  actual_days="$(
    jq --arg field "$day_field" \
      '[.payload | .. | objects | .[$field]? // empty] | unique | length' "$input_json"
  )"

  if [ "$actual_days" -gt "$expected_days" ]; then
    fail "period $period carries $actual_days distinct $day_field values but the month has $expected_days days; the payload reaches outside its own period"
  fi

  # Not an error. The newest month is partially published on every scheduled
  # run, so failing here would paint a workflow red for behaving correctly.
  if [ "$actual_days" -lt "$expected_days" ]; then
    printf 'incomplete period snapshot: %s covers %s of %s days; not stored\n' \
      "$period" "$actual_days" "$expected_days"
    exit 0
  fi
fi

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
