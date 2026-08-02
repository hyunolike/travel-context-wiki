#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mode="write"
if [ "${1:-}" = "--check" ]; then
  mode="check"
elif [ "${1:-}" != "" ]; then
  printf 'Usage: %s [--check]\n' "$0" >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

frontmatter_value() {
  local file="$1"
  local key="$2"
  awk -F': ' -v key="$key" '$1 == key { print substr($0, length(key) + 3); exit }' "$file"
}

frontmatter_list_json() {
  local file="$1"
  local key="$2"
  awk -v marker="$key:" '
    $0 == marker { in_list = 1; next }
    in_list && /^  - / {
      sub(/^  - /, "")
      gsub(/^"|"$/, "")
      print
      next
    }
    in_list && /^[^ ]/ { in_list = 0 }
  ' "$file" | jq -R -s 'split("\n") | map(select(length > 0))'
}

first_body_text() {
  local file="$1"
  awk '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { in_frontmatter = 0; in_body = 1; next }
    in_body && $0 !~ /^#/ && $0 !~ /^[[:space:]]*$/ {
      print
      exit
    }
  ' "$file"
}

canonical_list="$tmp_dir/canonical-files.txt"
record_list="$tmp_dir/record-files.txt"
package_list="$tmp_dir/package-files.txt"
canonical_jsonl="$tmp_dir/canonical-pages.jsonl"
chunk_jsonl="$tmp_dir/generated-chunks.jsonl"
source_uses_jsonl="$tmp_dir/source-uses.jsonl"

: > "$canonical_list"
for dir in concepts entities comparisons queries decisions; do
  [ -d "$dir" ] || continue
  find "$dir" -type f -name '*.md'
done | sort > "$canonical_list"

find records -type f -name '*.json' | sort > "$record_list"
find packages -type f -name 'context-bundle.json' | sort > "$package_list"

: > "$canonical_jsonl"
: > "$chunk_jsonl"
: > "$source_uses_jsonl"

while IFS= read -r file; do
  [ -n "$file" ] || continue

  type="$(frontmatter_value "$file" type)"
  title="$(frontmatter_value "$file" title)"
  confidence="$(frontmatter_value "$file" confidence)"
  slug="$(basename "$file" .md)"
  id="$type:$slug"
  tags_json="$(frontmatter_list_json "$file" tags)"
  sources_json="$(frontmatter_list_json "$file" sources)"
  text="$(first_body_text "$file")"

  jq -n \
    --arg id "$id" \
    --arg path "$file" \
    --arg type "$type" \
    --arg title "$title" \
    --arg confidence "$confidence" \
    --argjson tags "$tags_json" \
    --argjson sources "$sources_json" \
    '{id: $id, path: $path, type: $type, title: $title, confidence: $confidence, tags: $tags, sources: $sources}' \
    >> "$canonical_jsonl"

  jq -cn \
    --arg id "$id#summary" \
    --arg path "$file" \
    --arg text "$text" \
    --argjson tags "$tags_json" \
    --argjson sources "$sources_json" \
    '{id: $id, path: $path, text: $text, tags: $tags, sources: $sources}' \
    >> "$chunk_jsonl"

  printf '%s\n' "$sources_json" | jq -r '.[]' | while IFS= read -r source_path; do
    jq -n --arg source "$source_path" --arg usedBy "$file" '{source: $source, usedBy: $usedBy}' >> "$source_uses_jsonl"
  done
done < "$canonical_list"

while IFS= read -r file; do
  [ -n "$file" ] || continue
  jq -r '.. | objects | .source? // empty' "$file" | while IFS= read -r source_path; do
    jq -n --arg source "$source_path" --arg usedBy "$file" '{source: $source, usedBy: $usedBy}' >> "$source_uses_jsonl"
  done
done < "$record_list"

records_json="$(jq -R -s 'split("\n") | map(select(length > 0))' "$record_list")"
packages_json="$(jq -R -s 'split("\n") | map(select(length > 0))' "$package_list")"

jq -n \
  --slurpfile canonicalPages "$canonical_jsonl" \
  --argjson records "$records_json" \
  --argjson packages "$packages_json" \
  '{
    version: "static",
    generatedBy: "scripts/build-index.sh",
    description: "Retrieval manifest for Travel Context Wiki. Static local retrieval comes before vector search.",
    retrievalPolicy: "indexes/retrieval-policy.md",
    canonicalPages: $canonicalPages,
    records: $records,
    packages: $packages
  }' > "$tmp_dir/manifest.json"

cp "$chunk_jsonl" "$tmp_dir/chunks.jsonl"

if [ -s "$source_uses_jsonl" ]; then
  jq -s '
    group_by(.source)
    | map({
        (.[0].source): {
          kind: ((.[0].source | split("/"))[1] // "raw"),
          usedBy: (map(.usedBy) | unique)
        }
      })
    | add
  ' "$source_uses_jsonl" > "$tmp_dir/source-map.json"
else
  printf '{}\n' > "$tmp_dir/source-map.json"
fi

if [ "$mode" = "check" ]; then
  diff -u indexes/manifest.json "$tmp_dir/manifest.json"
  diff -u indexes/chunks.jsonl "$tmp_dir/chunks.jsonl"
  diff -u indexes/source-map.json "$tmp_dir/source-map.json"
  printf 'index check passed\n'
else
  cp "$tmp_dir/manifest.json" indexes/manifest.json
  cp "$tmp_dir/chunks.jsonl" indexes/chunks.jsonl
  cp "$tmp_dir/source-map.json" indexes/source-map.json
  printf 'rebuilt indexes/manifest.json indexes/chunks.jsonl indexes/source-map.json\n'
fi
