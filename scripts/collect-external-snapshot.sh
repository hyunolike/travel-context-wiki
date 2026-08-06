#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [--skip-unchanged] <input-json> <output-dir>\n' "$0" >&2
  exit 2
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

skip_unchanged="false"
if [ "${1:-}" = "--skip-unchanged" ]; then
  skip_unchanged="true"
  shift
fi

[ "$#" -eq 2 ] || usage

input_json="$1"
output_dir="$2"

[ -f "$input_json" ] || fail "missing input JSON: $input_json"
jq empty "$input_json" >/dev/null || fail "invalid JSON: $input_json"

snapshot_id="$(jq -r '.snapshotId // empty' "$input_json")"
source_kind="$(jq -r '.sourceKind // empty' "$input_json")"

[ -n "$snapshot_id" ] || fail "snapshotId is required"
[ -n "$source_kind" ] || fail "sourceKind is required"

jq -e '
  (.sourceUrl | type == "string" and length > 0) and
  (.license | type == "string" and length > 0) and
  (.collectedAt | type == "string" and length > 0) and
  (.payload | type == "object")
' "$input_json" >/dev/null || fail "external snapshot is missing required source metadata"

safe_kind="$(printf '%s' "$source_kind" | sed 's/[^A-Za-z0-9._-]/-/g')"
safe_id="$(printf '%s' "$snapshot_id" | sed 's/[^A-Za-z0-9._-]/-/g')"
[ -n "$safe_kind" ] || fail "sourceKind cannot be converted into a safe file name"
[ -n "$safe_id" ] || fail "snapshotId cannot be converted into a safe file name"

mkdir -p "$output_dir"
output_path="$output_dir/$safe_kind-$safe_id.json"

# Envelope metadata such as collectedAt changes on every scheduled run, so a
# plain rewrite produces a commit even when the source data is identical.
# Compare the payload alone and leave the stored capture untouched when it has
# not moved. See "Scheduled Collection Rules" in SCHEMA.md.
if [ "$skip_unchanged" = "true" ] && [ -f "$output_path" ]; then
  if jq -S '.payload' "$input_json" > "$TMP_DIR/incoming-payload.json" \
    && jq -S '.payload' "$output_path" > "$TMP_DIR/stored-payload.json" \
    && cmp -s "$TMP_DIR/incoming-payload.json" "$TMP_DIR/stored-payload.json"; then
    printf 'unchanged external snapshot: %s\n' "$output_path"
    exit 0
  fi
fi

jq -S . "$input_json" > "$output_path"

printf 'captured external snapshot: %s\n' "$output_path"
