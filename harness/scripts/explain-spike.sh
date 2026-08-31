#!/usr/bin/env bash
# Spike: send the assembled context bundle plus backend facts to a model and see
# whether a grounded explanation comes back. This is the smallest thing that
# answers "does the LLM wiki work" — no server, no database, no container.
#
# Two providers, one fixture. The point is not to pick a winner here but to make
# the same inputs runnable against both, so harness/scenarios/ can count the
# forbidden behaviours on each and the choice stops being a matter of opinion.
#
#   ./harness/scripts/explain-spike.sh --provider openrouter
#   ./harness/scripts/explain-spike.sh --provider anthropic
#
# It lives under harness/ rather than scripts/ because SCHEMA "Batch Collection
# Rules" requires every script under scripts/ to run without secrets, and this
# one calls an authenticated API. With no key present it still does something
# useful: it prints the exact request body it would send, so the prompt can be
# reviewed without spending a token or a rate-limit slot.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PROVIDER="anthropic"
SERVICE="hanjeok"
FACTS_FILE="harness/fixtures/course-explanation-request.json"

# max_tokens covers thinking and response text together on reasoning models, and
# thinking is on by default on several of them. The design doc proposed 4096;
# that is tight enough to truncate an answer once thinking takes its share.
MAX_TOKENS=8192

fail() {
  printf 'explain-spike: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf 'Usage: %s [--provider anthropic|openrouter] [--service NAME] [--facts PATH]\n' "$0" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    --service)  SERVICE="${2:-}"; shift 2 ;;
    --facts)    FACTS_FILE="${2:-}"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *)          usage; exit 2 ;;
  esac
done

case "$PROVIDER" in
  anthropic)  MODEL="${HERMES_MODEL:-claude-opus-5}" ;;
  openrouter) MODEL="${HERMES_MODEL:-nvidia/nemotron-3-ultra-550b-a55b:free}" ;;
  *)          fail "unknown provider: $PROVIDER (expected anthropic or openrouter)" ;;
esac

command -v jq >/dev/null 2>&1 || fail "jq is required"
[ -f "$FACTS_FILE" ] || fail "no such facts file: $FACTS_FILE"
jq empty "$FACTS_FILE" >/dev/null 2>&1 || fail "$FACTS_FILE is not valid JSON"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

./scripts/build-bundle.sh "$SERVICE" > "$tmp_dir/bundle.txt"

INSTRUCTION="다음은 한적 백엔드가 결정론적으로 만든 코스와 그 근거 사실이다. 위 컨텍스트만 근거로 설명을 작성하라."

# The output shape is the same contract on both providers. Anthropic enforces it
# natively; OpenRouter's free Nemotron does not support response_format, so the
# same schema is forced through a tool call instead. Same guarantee, one more
# layer of indirection — which is the concrete form the "shim turns first-class
# parameters into workarounds" objection takes here.
SCHEMA='{
  "type": "object",
  "properties": {
    "explanation": { "type": "string" },
    "citations": { "type": "array", "items": { "type": "string" } }
  },
  "required": ["explanation", "citations"],
  "additionalProperties": false
}'

if [ "$PROVIDER" = "anthropic" ]; then
  # The bundle is the cache prefix: byte-identical every request, so it sits in
  # `system` behind a cache_control breakpoint while only the facts vary. TTL is
  # 1h because a shared course link gets opened across a day.
  jq -n \
    --arg model "$MODEL" \
    --argjson max_tokens "$MAX_TOKENS" \
    --arg instruction "$INSTRUCTION" \
    --rawfile bundle "$tmp_dir/bundle.txt" \
    --slurpfile facts "$FACTS_FILE" \
    --argjson schema "$SCHEMA" \
    '{
      model: $model,
      max_tokens: $max_tokens,
      fallbacks: "default",
      output_config: {
        effort: "low",
        format: { type: "json_schema", schema: $schema }
      },
      system: [
        { type: "text", text: $bundle, cache_control: { type: "ephemeral", ttl: "1h" } }
      ],
      messages: [
        { role: "user", content: ($instruction + "\n\n" + ($facts[0] | tojson)) }
      ]
    }' > "$tmp_dir/request.json"
else
  # OpenAI-compatible shape. No cache_control: the free tier has nothing to
  # optimise, so the bundle is reprocessed every call. That costs latency and a
  # rate-limit slot, not money.
  jq -n \
    --arg model "$MODEL" \
    --argjson max_tokens "$MAX_TOKENS" \
    --arg instruction "$INSTRUCTION" \
    --rawfile bundle "$tmp_dir/bundle.txt" \
    --slurpfile facts "$FACTS_FILE" \
    --argjson schema "$SCHEMA" \
    '{
      model: $model,
      max_tokens: $max_tokens,
      messages: [
        { role: "system", content: $bundle },
        { role: "user", content: ($instruction + "\n\n" + ($facts[0] | tojson)) }
      ],
      tools: [
        {
          type: "function",
          function: {
            name: "submit_explanation",
            description: "근거에 기반한 설명과 인용 경로를 제출한다. 반드시 이 도구로만 답한다.",
            parameters: $schema
          }
        }
      ],
      tool_choice: { type: "function", function: { name: "submit_explanation" } }
    }' > "$tmp_dir/request.json"
fi

if [ "$PROVIDER" = "anthropic" ]; then
  KEY="${ANTHROPIC_API_KEY:-}"
  KEY_NAME="ANTHROPIC_API_KEY"
else
  KEY="${OPENROUTER_API_KEY:-}"
  KEY_NAME="OPENROUTER_API_KEY"
fi

if [ -z "$KEY" ]; then
  cat "$tmp_dir/request.json"
  printf '\n' >&2
  printf 'explain-spike: %s is not set, so nothing was sent.\n' "$KEY_NAME" >&2
  printf 'explain-spike: provider %s, model %s.\n' "$PROVIDER" "$MODEL" >&2
  printf 'explain-spike: bundle %s bytes, request %s bytes.\n' \
    "$(wc -c < "$tmp_dir/bundle.txt" | tr -d ' ')" \
    "$(wc -c < "$tmp_dir/request.json" | tr -d ' ')" >&2
  exit 0
fi

if [ "$PROVIDER" = "anthropic" ]; then
  curl -sS https://api.anthropic.com/v1/messages \
    -H "content-type: application/json" \
    -H "x-api-key: $KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "anthropic-beta: server-side-fallback-2026-07-01" \
    -d @"$tmp_dir/request.json" > "$tmp_dir/response.json"
else
  curl -sS https://openrouter.ai/api/v1/chat/completions \
    -H "content-type: application/json" \
    -H "authorization: Bearer $KEY" \
    -H "x-title: travel-context-wiki hermes spike" \
    -d @"$tmp_dir/request.json" > "$tmp_dir/response.json"
fi

# Both providers can return an error object inside a 200 body.
if jq -e 'has("error") and (.error != null)' "$tmp_dir/response.json" >/dev/null; then
  jq -r '.error | if type == "object" then "\(.type // .code // "error"): \(.message)" else tostring end' \
    "$tmp_dir/response.json" >&2
  exit 1
fi

if [ "$PROVIDER" = "anthropic" ]; then
  # Read stop_reason before content. A safety classifier can decline with HTTP
  # 200, an empty content array, and stop_reason "refusal" — code that indexes
  # content[0] unconditionally breaks exactly there.
  stop_reason="$(jq -r '.stop_reason // "unknown"' "$tmp_dir/response.json")"
  if [ "$stop_reason" = "refusal" ]; then
    printf 'explain-spike: refused (category %s)\n' \
      "$(jq -r '.stop_details.category // "unknown"' "$tmp_dir/response.json")" >&2
    exit 1
  fi
  jq -r '[.content[] | select(.type == "text") | .text] | join("")' "$tmp_dir/response.json" \
    > "$tmp_dir/answer.json"
  USAGE_FILTER='
    "model            : \(.model)",
    "stop_reason      : \(.stop_reason)",
    "input            : \(.usage.input_tokens)",
    "cache write      : \(.usage.cache_creation_input_tokens // 0)",
    "cache read       : \(.usage.cache_read_input_tokens // 0)",
    "output           : \(.usage.output_tokens)"'
else
  finish="$(jq -r '.choices[0].finish_reason // "unknown"' "$tmp_dir/response.json")"
  if [ "$finish" = "length" ]; then
    printf 'explain-spike: truncated at max_tokens — raise MAX_TOKENS\n' >&2
  fi
  # tool_choice forces the call, so the answer is the arguments string. If the
  # model answered in prose instead, that is itself a finding worth surfacing.
  if ! jq -e '.choices[0].message.tool_calls[0].function.arguments' "$tmp_dir/response.json" >/dev/null; then
    printf 'explain-spike: model did not call the tool — schema was not enforced\n' >&2
    jq -r '.choices[0].message.content // "(no content)"' "$tmp_dir/response.json" >&2
    exit 1
  fi
  jq -r '.choices[0].message.tool_calls[0].function.arguments' "$tmp_dir/response.json" \
    > "$tmp_dir/answer.json"
  USAGE_FILTER='
    "model            : \(.model)",
    "finish_reason    : \(.choices[0].finish_reason)",
    "prompt tokens    : \(.usage.prompt_tokens // 0)",
    "completion tokens: \(.usage.completion_tokens // 0)"'
fi

printf '=== explanation ===\n'
if jq empty "$tmp_dir/answer.json" >/dev/null 2>&1; then
  jq -r '.explanation' "$tmp_dir/answer.json"
  printf '\n=== citations ===\n'
  jq -r '.citations[]' "$tmp_dir/answer.json"
else
  printf 'explain-spike: answer was not valid JSON — printing raw\n' >&2
  cat "$tmp_dir/answer.json"
fi

printf '\n=== usage ===\n' >&2
jq -r "$USAGE_FILTER" "$tmp_dir/response.json" >&2

if [ "$PROVIDER" = "anthropic" ]; then
  printf '\nexplain-spike: run this twice. cache read stays 0 on the second run only if\n' >&2
  printf 'explain-spike: something in the bundle is not byte-stable.\n' >&2
fi
