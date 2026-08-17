#!/usr/bin/env bash
set -euo pipefail

# Draws docs/collection-stats.svg from the evidence stored in
# raw/external-snapshots/. Reads the repository and calls no API, so it runs
# correctly with no secret present, as SCHEMA rule 3 requires of every script
# here.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  printf 'Usage: %s [--check|--metrics] [--snapshot-dir DIR] [--out FILE]\n' "$0" >&2
  exit 2
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

snapshot_dir="raw/external-snapshots"
out_file="docs/collection-stats.svg"
mode=render

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) mode=check ;;
    --metrics) mode=metrics ;;
    --snapshot-dir) [ "$#" -ge 2 ] || usage; snapshot_dir="$2"; shift ;;
    --out) [ "$#" -ge 2 ] || usage; out_file="$2"; shift ;;
    *) usage ;;
  esac
  shift
done

visitors_dir="$snapshot_dir/tourism-visitors"
station_file="$snapshot_dir/air-quality-airkorea-station-list.json"

series_file="$TMP_DIR/series.jsonl"
: > "$series_file"
latest_period_file=""

# Fed by a here-document rather than a pipe: a pipe would run the loop in a
# subshell and latest_period_file would come back empty. LC_ALL=C keeps the
# order independent of the caller's locale — the names are YYYY-MM, so a byte
# sort is a chronological sort.
if [ -d "$visitors_dir" ]; then
  while IFS= read -r period_file; do
    [ -n "$period_file" ] || continue
    jq -c '{
      period: (.period // ""),
      rows: (.payload.response.body.totalCount // 0),
      collectedAt: (.collectedAt // "")
    }' "$period_file" >> "$series_file" \
      || fail "could not read period snapshot: $period_file"
    latest_period_file="$period_file"
  done <<EOF
$(find "$visitors_dir" -maxdepth 1 -type f -name '*.json' | LC_ALL=C sort)
EOF
fi

# Read from the newest period only. Unioning every period would report which
# regions have ever appeared, which is a different claim than current coverage,
# and would mean parsing every ~3 MB file on each run to answer it wrongly.
regions=0
if [ -n "$latest_period_file" ]; then
  regions="$(jq '
    [ (.payload.response.body.items.item // [])
      | if type == "object" then [.] else . end
      | .[].signguCode ]
    | unique | length
  ' "$latest_period_file")" || fail "could not count regions in $latest_period_file"
fi

stations=0
station_collected_at=""
if [ -f "$station_file" ]; then
  stations="$(jq -r '.payload.response.body.totalCount // 0' "$station_file")" \
    || fail "could not read station snapshot: $station_file"
  station_collected_at="$(jq -r '.collectedAt // ""' "$station_file")"
fi

# -S so the document is key-sorted, for the same reason every other artifact
# here is: a stable serialisation is what lets an unchanged input compare as
# unchanged. The date is truncated to a day because the image shows a day.
jq -s -S \
  --argjson regions "$regions" \
  --argjson stations "$stations" \
  --arg stationCollectedAt "$station_collected_at" \
  '
    . as $series
    | ([ $series[].collectedAt, $stationCollectedAt ]
       | map(select(. != "")) | max // "") as $last
    | {
        periods: {
          count: ($series | length),
          first: (if ($series | length) > 0 then $series[0].period else "" end),
          last:  (if ($series | length) > 0 then $series[-1].period else "" end),
          rows: ($series | map(.rows) | add // 0),
          regions: $regions,
          series: ($series | map({period, rows}))
        },
        stations: { count: $stations },
        lastCollectedAt: ($last | .[0:10])
      }
  ' "$series_file" > "$TMP_DIR/metrics.json" \
  || fail "could not assemble the metrics document"

if [ "$mode" = metrics ]; then
  jq -S . "$TMP_DIR/metrics.json"
  exit 0
fi

fail "rendering is not implemented yet"
