#!/usr/bin/env bash
# Assemble a service package's context bundle into one deterministic string.
#
# The output goes to stdout and is meant to be dropped into the LLM `system`
# block behind a cache_control breakpoint. Prompt caching matches on an exact
# prefix, so the ONLY thing this script may depend on is file contents and the
# order the package declares. No timestamp, no hostname, no run counter, no
# directory listing order. A single varying byte turns every request into a
# cache miss, which costs money without failing anything.
#
# `retrievalPolicy` is validated but not embedded: it instructs the retrieval
# layer, not the model, and the byte measurement in the Hermes Agent design
# excluded it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SOFT_LIMIT_BYTES=40960

usage() {
  printf 'Usage: %s <service>\n' "$0" >&2
  printf '       %s --list\n' "$0" >&2
}

fail() {
  printf 'build-bundle: %s\n' "$1" >&2
  exit 1
}

if [ "${1:-}" = "--list" ]; then
  find packages -mindepth 1 -maxdepth 1 -type d | sed 's|^packages/||' | LC_ALL=C sort
  exit 0
fi

service="${1:-}"
[ -n "$service" ] || { usage; exit 2; }
[ $# -eq 1 ] || { usage; exit 2; }

package="packages/$service/context-bundle.json"
[ -f "$package" ] || fail "no such package: $package"
jq empty "$package" >/dev/null 2>&1 || fail "$package is not valid JSON"

# Order is declared, never discovered. canonicalContext explains the policy,
# recordContext supplies the normalized values those policies refer to, and the
# service prompt comes last so its instructions sit closest to the user turn.
paths_file="$(mktemp)"
trap 'rm -f "$paths_file"' EXIT

jq -r '.canonicalContext[]?, .recordContext[]?' "$package" > "$paths_file"
printf 'packages/%s/prompt.md\n' "$service" >> "$paths_file"

policy="$(jq -r '.retrievalPolicy // empty' "$package")"
if [ -n "$policy" ] && [ ! -f "$policy" ]; then
  fail "$package retrievalPolicy points at a missing file: $policy"
fi

# Validate every path before emitting anything, so a broken package never
# produces a half-written bundle that looks usable.
#
# The marker check is the one that matters most. This script separates documents
# with `----- FILE: <path> -----` lines, so a source file whose own body carries
# such a line makes the bundle ambiguous: a consumer parsing it back gets a
# document with a fabricated path. That fabricated path then reads as a real
# entry in the bundle's path set, which is what a citation is validated against
# — so an LLM could cite a document that does not exist and pass. Only the
# generator can see the source files before they are concatenated, so only the
# generator can refuse. A consumer cannot recover the boundary after the fact.
while IFS= read -r path; do
  [ -n "$path" ] || continue
  case "$path" in
    /*|*..*) fail "$package lists a path outside the repository: $path" ;;
  esac
  [ -f "$path" ] || fail "$package references a missing file: $path"
  if grep -qE '^----- FILE: .+ -----$' "$path"; then
    fail "$path contains a line shaped like a bundle FILE marker; it would split into a document with a fabricated path"
  fi
done < "$paths_file"

count=0
while IFS= read -r path; do
  [ -n "$path" ] || continue
  printf -- '----- FILE: %s -----\n' "$path"
  cat "$path"
  printf '\n'
  count=$((count + 1))
done < "$paths_file"

bytes="$(
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    printf -- '----- FILE: %s -----\n' "$path"
    cat "$path"
    printf '\n'
  done < "$paths_file" | wc -c | tr -d ' '
)"

printf 'build-bundle: %s — %s files, %s bytes\n' "$service" "$count" "$bytes" >&2

if [ "$bytes" -gt "$SOFT_LIMIT_BYTES" ]; then
  printf 'build-bundle: WARNING bundle exceeds %s bytes; revisit the no-vector-search decision in indexes/retrieval-policy.md\n' \
    "$SOFT_LIMIT_BYTES" >&2
fi
