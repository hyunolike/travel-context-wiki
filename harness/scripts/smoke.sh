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
require_dir raw/project-guides
require_dir inbox
require_dir research
require_dir concepts
require_dir entities
require_dir comparisons
require_dir queries
require_dir decisions
require_dir records/places
require_dir records/weather
require_dir records/congestion
require_dir records/events
require_dir records/regions
require_dir records/papers
require_dir records/project-artifacts
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
require_file harness/fixtures/period-snapshot.valid.json
require_file raw/project-guides/open-source-ai-agent-project-guide.md
require_file records/places/gyeongbokgung.json
require_file records/weather/rules.json
require_file records/congestion/grade-policy.json
require_file records/regions/seoul-jongno.json
require_file records/project-artifacts/portfolio-deliverables.json
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
require_file scripts/collect-period-snapshot.sh
require_file scripts/build-index.sh
require_file .github/workflows/wiki-batch.yml

[ -x scripts/collect-user-input.sh ] || fail "scripts/collect-user-input.sh is not executable"
[ -x scripts/collect-external-snapshot.sh ] || fail "scripts/collect-external-snapshot.sh is not executable"
[ -x scripts/collect-period-snapshot.sh ] || fail "scripts/collect-period-snapshot.sh is not executable"
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

  slug="$(basename "$file" .md)"
  if ! printf '%s\n' "$slug" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    fail "$file is not lowercase kebab-case"
  fi

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

# SCHEMA "Scheduled Collection Rules": a scheduled capture must not rewrite the
# stored file when only envelope metadata such as collectedAt moved, otherwise
# every run produces a commit whose payload is identical.
snapshot_path="$TMP_DIR/external/public-tourism-api-tourapi-sample-jongno-20260803.json"
snapshot_before="$(cksum < "$snapshot_path")"

jq '.collectedAt = "2099-01-01T00:00:00Z"' harness/fixtures/external-tourism-snapshot.valid.json > "$TMP_DIR/retimed-snapshot.json"
scripts/collect-external-snapshot.sh --skip-unchanged "$TMP_DIR/retimed-snapshot.json" "$TMP_DIR/external" >/dev/null
[ "$(cksum < "$snapshot_path")" = "$snapshot_before" ] || fail "--skip-unchanged rewrote a snapshot whose payload did not change"

jq '.payload.smokeProbe = "changed"' harness/fixtures/external-tourism-snapshot.valid.json > "$TMP_DIR/repayloaded-snapshot.json"
scripts/collect-external-snapshot.sh --skip-unchanged "$TMP_DIR/repayloaded-snapshot.json" "$TMP_DIR/external" >/dev/null
[ "$(cksum < "$snapshot_path")" != "$snapshot_before" ] || fail "--skip-unchanged ignored a real payload change"

# SCHEMA "Scheduled Collection Rules": the air-quality source returns the same
# rows in a different order on every call, so an unchanged payload compared as
# changed and proposed a pull request every run. --sort-arrays must make that
# compare as unchanged, must still see a real change, and must stay opt-in so
# payloads whose order carries meaning keep the old behaviour.
jq '.payload.items = [{"id":"a"},{"id":"b"},{"id":"c"}]' harness/fixtures/external-tourism-snapshot.valid.json > "$TMP_DIR/ordered-snapshot.json"
jq '.payload.items = [{"id":"c"},{"id":"a"},{"id":"b"}]' harness/fixtures/external-tourism-snapshot.valid.json > "$TMP_DIR/reordered-snapshot.json"
sorted_path="$TMP_DIR/sorted/public-tourism-api-tourapi-sample-jongno-20260803.json"

scripts/collect-external-snapshot.sh --sort-arrays "$TMP_DIR/ordered-snapshot.json" "$TMP_DIR/sorted" >/dev/null
sorted_before="$(cksum < "$sorted_path")"

scripts/collect-external-snapshot.sh --skip-unchanged --sort-arrays "$TMP_DIR/reordered-snapshot.json" "$TMP_DIR/sorted" >/dev/null
[ "$(cksum < "$sorted_path")" = "$sorted_before" ] || fail "--sort-arrays let a reordered but identical payload rewrite the snapshot"

jq '.payload.items += [{"id":"d"}]' "$TMP_DIR/reordered-snapshot.json" > "$TMP_DIR/grown-snapshot.json"
scripts/collect-external-snapshot.sh --skip-unchanged --sort-arrays "$TMP_DIR/grown-snapshot.json" "$TMP_DIR/sorted" >/dev/null
[ "$(cksum < "$sorted_path")" != "$sorted_before" ] || fail "--sort-arrays swallowed a real payload change"

scripts/collect-external-snapshot.sh "$TMP_DIR/ordered-snapshot.json" "$TMP_DIR/unsorted" >/dev/null
unsorted_path="$TMP_DIR/unsorted/public-tourism-api-tourapi-sample-jongno-20260803.json"
unsorted_before="$(cksum < "$unsorted_path")"
scripts/collect-external-snapshot.sh --skip-unchanged "$TMP_DIR/reordered-snapshot.json" "$TMP_DIR/unsorted" >/dev/null
[ "$(cksum < "$unsorted_path")" != "$unsorted_before" ] || fail "reordering counted as unchanged without --sort-arrays"

# SCHEMA "Scheduled Collection Rules" rule 9: a period-partitioned capture
# writes one file per period, leaves a stored period alone, and halts when the
# source restates one instead of overwriting the original reading.
scripts/collect-period-snapshot.sh harness/fixtures/period-snapshot.valid.json "$TMP_DIR/periods" >/dev/null
period_path="$TMP_DIR/periods/2026-07.json"
[ -f "$period_path" ] || fail "period snapshot script did not create expected output"
period_before="$(cksum < "$period_path")"

jq '.collectedAt = "2099-01-01T00:00:00Z"' harness/fixtures/period-snapshot.valid.json > "$TMP_DIR/retimed-period.json"
scripts/collect-period-snapshot.sh "$TMP_DIR/retimed-period.json" "$TMP_DIR/periods" >/dev/null
[ "$(cksum < "$period_path")" = "$period_before" ] || fail "period snapshot rewrote a stored period whose payload did not change"

jq '.payload.response.body.items |= reverse' harness/fixtures/period-snapshot.valid.json > "$TMP_DIR/reordered-period.json"
scripts/collect-period-snapshot.sh "$TMP_DIR/reordered-period.json" "$TMP_DIR/periods" >/dev/null
[ "$(cksum < "$period_path")" = "$period_before" ] || fail "period snapshot read a reordered payload as a restatement"

jq '.payload.response.body.items[0].touNum = 9999999' harness/fixtures/period-snapshot.valid.json > "$TMP_DIR/restated-period.json"
if scripts/collect-period-snapshot.sh "$TMP_DIR/restated-period.json" "$TMP_DIR/periods" >/dev/null 2>&1; then
  fail "period snapshot accepted a restated payload instead of halting"
fi
[ "$(cksum < "$period_path")" = "$period_before" ] || fail "period snapshot altered a stored period while rejecting a restatement"

jq '.period = "2026-13"' harness/fixtures/period-snapshot.valid.json > "$TMP_DIR/malformed-period.json"
if scripts/collect-period-snapshot.sh "$TMP_DIR/malformed-period.json" "$TMP_DIR/periods" >/dev/null 2>&1; then
  fail "period snapshot accepted a malformed period"
fi

jq '.period = "2026-08" | .snapshotId = "kto-regional-visitors-2026-08"' harness/fixtures/period-snapshot.valid.json > "$TMP_DIR/next-period.json"
scripts/collect-period-snapshot.sh "$TMP_DIR/next-period.json" "$TMP_DIR/periods" >/dev/null
[ -f "$TMP_DIR/periods/2026-08.json" ] || fail "period snapshot did not write a second period alongside the first"
[ "$(cksum < "$period_path")" = "$period_before" ] || fail "writing a new period altered an existing one"

scripts/build-index.sh --check >/dev/null

while IFS= read -r line; do
  [ -z "$line" ] && continue
  printf '%s\n' "$line" | jq empty >/dev/null || fail "indexes/chunks.jsonl contains invalid JSON line"
done < indexes/chunks.jsonl

jq -r '.canonicalPages[]?.path, .records[]?, .packages[]?' indexes/manifest.json | while IFS= read -r manifest_path; do
  [ -f "$manifest_path" ] || fail "indexes/manifest.json references missing path $manifest_path"
done

jq -r '.. | objects | .source? // empty' records/places/*.json records/congestion/*.json records/regions/*.json records/project-artifacts/*.json | while IFS= read -r source_path; do
  [ -f "$source_path" ] || fail "record references missing source $source_path"
done

jq -r '.canonicalContext[]?, .recordContext[]?, .retrievalPolicy? // empty' packages/*/context-bundle.json | while IFS= read -r package_path; do
  [ -f "$package_path" ] || fail "package references missing path $package_path"
done

# SCHEMA "Index Rules": every canonical page appears once, in the section that
# matches its type, sorted alphabetically within that section.
INDEX_ENTRIES="$TMP_DIR/index-entries.tsv"
awk '
  /^## / { section = $2; next }
  /^- \[\[/ {
    slug = $0
    sub(/^- \[\[/, "", slug)
    sub(/\]\].*$/, "", slug)
    print section "\t" slug
  }
' index.md > "$INDEX_ENTRIES"

while IFS="$(printf '\t')" read -r section slug; do
  case "$section" in
    Concepts) section_dir=concepts ;;
    Entities) section_dir=entities ;;
    Comparisons) section_dir=comparisons ;;
    Queries) section_dir=queries ;;
    Decisions) section_dir=decisions ;;
    *) fail "index.md has an unknown section: $section" ;;
  esac
  [ -f "$section_dir/$slug.md" ] || fail "index.md lists $slug under $section but $section_dir/$slug.md does not exist"
done < "$INDEX_ENTRIES"

for section in $(cut -f1 "$INDEX_ENTRIES" | sort -u); do
  listed="$(awk -F'\t' -v s="$section" '$1 == s { print $2 }' "$INDEX_ENTRIES")"
  sorted="$(printf '%s\n' "$listed" | LC_ALL=C sort)"
  [ "$listed" = "$sorted" ] || fail "index.md section $section is not sorted alphabetically"
done

find concepts entities comparisons queries decisions -type f -name '*.md' -exec basename {} .md \; | LC_ALL=C sort > "$TMP_DIR/canonical-slugs.txt"
cut -f2 "$INDEX_ENTRIES" | LC_ALL=C sort > "$TMP_DIR/indexed-slugs.txt"
if ! diff -u "$TMP_DIR/canonical-slugs.txt" "$TMP_DIR/indexed-slugs.txt" > "$TMP_DIR/index-diff.txt"; then
  cat "$TMP_DIR/index-diff.txt" >&2
  fail "index.md entries do not match the canonical pages on disk"
fi

# SCHEMA "Log Rules": append-only history with a fixed heading grammar.
grep '^## ' log.md | while IFS= read -r heading; do
  if ! printf '%s\n' "$heading" | grep -Eq '^## [0-9]{4}-[0-9]{2}-[0-9]{2} - (ingest|create|update|archive|delete|lint|repair) - .+$'; then
    fail "log.md heading does not match SCHEMA format: $heading"
  fi
done

# SCHEMA "File Format Rules": UTF-8, LF, no BOM, final newline.
# raw/ is exempt because captured evidence is preserved byte-for-byte.
find . -type f \( -name '*.md' -o -name '*.json' -o -name '*.jsonl' -o -name '*.sh' -o -name '*.yml' -o -name '*.yaml' \) \
  -not -path './.git/*' -not -path './raw/*' | while IFS= read -r text_file; do
  if [ "$(head -c 3 "$text_file" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ]; then
    fail "$text_file starts with a byte-order mark"
  fi
  if grep -q "$(printf '\r')" "$text_file"; then
    fail "$text_file contains CRLF line endings"
  fi
  if [ -s "$text_file" ] && [ -n "$(tail -c 1 "$text_file")" ]; then
    fail "$text_file has no final newline"
  fi
done

printf 'smoke passed: %s canonical pages checked\n' "$canonical_count"
