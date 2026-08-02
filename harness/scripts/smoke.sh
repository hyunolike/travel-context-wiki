#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

require_dir() {
  [ -d "$1" ] || fail "missing directory: $1"
}

require_file README.md
require_file AGENTS.md
require_file SCHEMA.md
require_file index.md
require_file log.md
require_file .specify/memory/constitution.md
require_file .specify/templates/spec-template.md
require_file .specify/templates/plan-template.md
require_file .specify/templates/tasks-template.md

require_dir raw/public-tourism-api
require_dir raw/service-snapshots
require_dir raw/weather-api
require_dir raw/tourism-research
require_dir raw/experiments
require_dir raw/user-input
require_dir raw/external-snapshots
require_dir concepts
require_dir entities
require_dir queries
require_dir decisions
require_dir records/places
require_dir records/weather
require_dir records/congestion
require_dir records/events
require_dir records/regions
require_dir records/papers
require_dir indexes
require_dir packages/generic-travel
require_dir packages/hanjeok
require_dir scripts
require_dir .github/workflows

require_file raw/public-tourism-api/2026-openapi-briefing.txt
require_file raw/service-snapshots/hanjeok/design-v3.md
require_file raw/service-snapshots/hanjeok/course-recommendation.md
require_file raw/service-snapshots/hanjeok/attractions.fixture.json
require_file harness/fixtures/user-input-capture.valid.json
require_file harness/fixtures/external-tourism-snapshot.valid.json
require_file records/places/gyeongbokgung.json
require_file records/weather/rules.json
require_file records/congestion/grade-policy.json
require_file records/regions/seoul-jongno.json
require_file indexes/manifest.json
require_file indexes/chunks.jsonl
require_file indexes/source-map.json
require_file indexes/retrieval-policy.md
require_file packages/generic-travel/context-bundle.json
require_file packages/generic-travel/prompt.md
require_file packages/hanjeok/context-bundle.json
require_file packages/hanjeok/prompt.md
require_file scripts/collect-user-input.sh
require_file scripts/collect-external-snapshot.sh
require_file scripts/build-index.sh
require_file .github/workflows/wiki-batch.yml

[ -x scripts/collect-user-input.sh ] || fail "scripts/collect-user-input.sh is not executable"
[ -x scripts/collect-external-snapshot.sh ] || fail "scripts/collect-external-snapshot.sh is not executable"
[ -x scripts/build-index.sh ] || fail "scripts/build-index.sh is not executable"

canonical_count="$(find concepts entities comparisons queries decisions -type f -name '*.md' | wc -l | tr -d ' ')"
index_count="$(awk -F': ' '/^Active canonical pages:/ { print $2 }' index.md)"
[ "$canonical_count" = "$index_count" ] || fail "index count $index_count does not match canonical count $canonical_count"

find concepts entities comparisons queries decisions -type f -name '*.md' | while IFS= read -r file; do
  head -n 1 "$file" | grep -qx -- '---' || fail "$file missing frontmatter start"
  grep -q '^title: ' "$file" || fail "$file missing title"
  grep -q '^created: ' "$file" || fail "$file missing created"
  grep -q '^updated: ' "$file" || fail "$file missing updated"
  grep -q '^type: ' "$file" || fail "$file missing type"
  grep -q '^sources:' "$file" || fail "$file missing sources"
  grep -q '^confidence: ' "$file" || fail "$file missing confidence"
  grep -q '^contested: ' "$file" || fail "$file missing contested"
  grep -q '^contradictions:' "$file" || fail "$file missing contradictions"

  type="$(awk -F': ' '/^type: / { print $2; exit }' "$file")"
  dir="$(dirname "$file")"
  case "$dir:$type" in
    concepts:concept|entities:entity|comparisons:comparison|queries:query|decisions:decision) ;;
    *) fail "$file type $type does not match directory $dir" ;;
  esac

  awk '
    /^sources:/ { in_sources=1; next }
    in_sources && /^  - / { sub(/^  - /, ""); print; next }
    in_sources && /^[^ ]/ { in_sources=0 }
  ' "$file" | while IFS= read -r source_path; do
    [ -f "$source_path" ] || fail "$file references missing source $source_path"
  done
done

grep -q 'initial evidence wiki scaffold' log.md || fail "log.md missing initial scaffold entry"
grep -q 'Travel context explanation' harness/scenarios/travel-context-explanation.md || fail "scenario missing expected title"

find records indexes packages harness/fixtures -type f -name '*.json' | while IFS= read -r json_file; do
  jq empty "$json_file" >/dev/null || fail "$json_file is not valid JSON"
done

scripts/collect-user-input.sh harness/fixtures/user-input-capture.valid.json "$TMP_DIR/user-input" >/dev/null
[ -f "$TMP_DIR/user-input/sample-family-rainy-day.json" ] || fail "user input capture script did not create expected output"

scripts/collect-external-snapshot.sh harness/fixtures/external-tourism-snapshot.valid.json "$TMP_DIR/external" >/dev/null
[ -f "$TMP_DIR/external/public-tourism-api-tourapi-sample-jongno-20260803.json" ] || fail "external snapshot script did not create expected output"

scripts/build-index.sh --check >/dev/null

while IFS= read -r line; do
  [ -z "$line" ] && continue
  printf '%s\n' "$line" | jq empty >/dev/null || fail "indexes/chunks.jsonl contains invalid JSON line"
done < indexes/chunks.jsonl

jq -r '.canonicalPages[]?.path, .records[]?, .packages[]?' indexes/manifest.json | while IFS= read -r manifest_path; do
  [ -f "$manifest_path" ] || fail "indexes/manifest.json references missing path $manifest_path"
done

jq -r '.. | objects | .source? // empty' records/places/*.json records/congestion/*.json records/regions/*.json | while IFS= read -r source_path; do
  [ -f "$source_path" ] || fail "record references missing source $source_path"
done

jq -r '.canonicalContext[]?, .recordContext[]?, .retrievalPolicy? // empty' packages/*/context-bundle.json | while IFS= read -r package_path; do
  [ -f "$package_path" ] || fail "package references missing path $package_path"
done

printf 'smoke passed: %s canonical pages checked\n' "$canonical_count"
