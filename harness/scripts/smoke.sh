#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

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

require_dir raw/openapi-briefing
require_dir raw/hanjeok-design
require_dir raw/harness
require_dir concepts
require_dir entities
require_dir queries
require_dir decisions

require_file raw/openapi-briefing/2026-openapi-briefing.txt
require_file raw/hanjeok-design/design-v3.md
require_file raw/harness/course-recommendation.md
require_file raw/harness/attractions.fixture.json

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
grep -q 'Evidence-backed course explanation' harness/scenarios/evidence-backed-course-explanation.md || fail "scenario missing expected title"

printf 'smoke passed: %s canonical pages checked\n' "$canonical_count"

