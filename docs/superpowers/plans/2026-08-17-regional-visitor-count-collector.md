# Regional Visitor Count Collector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture visitor counts per 기초지자체 from data.go.kr 15101972 as period-partitioned raw evidence, on a schedule, without ever rewriting a stored period.

**Architecture:** A new `scripts/collect-period-snapshot.sh` writes one file per `YYYY-MM` period under `raw/external-snapshots/tourism-visitors/` and refuses to overwrite a period it already stored. A monthly workflow requests each month as a date range, pages through the response, and opens a pull request when a new period lands. The API is daily-only, so a month file holds that month's daily rows unaggregated — rolling them up would be derivation, which `raw/` does not hold. `scripts/collect-external-snapshot.sh` is left untouched because the air-quality collector depends on its contract.

**Tech Stack:** Bash, jq, curl, GitHub Actions, the existing `harness/scripts/smoke.sh`.

**Design:** `docs/superpowers/specs/2026-08-17-regional-visitor-count-collector-design.md`

## Global Constraints

Copied from `SCHEMA.md` "Scheduled Collection Rules" and `AGENTS.md`. Every task inherits these.

- Secrets never reach `scripts/`. Only a workflow step may read a service key, and every script must run correctly with no secret present.
- Never print a request URL. Korean public-data services pass the key as a query parameter and this repository is public. Use `--data-urlencode`, never `curl -v`.
- Evidence lands in `raw/` and stops there. Never push to `main`; open a pull request.
- Do not edit raw source bodies after capture. Add a new snapshot instead.
- `sources:` in a canonical page must point to existing files **under `raw/`**. `docs/` is a deliverable, never evidence.
- Canonical pages live only in `entities/`, `concepts/`, `comparisons/`, `queries/`, `decisions/`, and adding one requires updating `index.md` and `log.md` in the same change.
- Tags must come from the "Registered Tags" list in `SCHEMA.md`.
- Markdown, JSON, and shell files outside `raw/` are UTF-8, LF, no BOM, final newline.
- `log.md` headings match `## YYYY-MM-DD - (ingest|create|update|archive|delete|lint|repair) - <summary>`.
- Verify with `./harness/scripts/smoke.sh`.

**Task order note:** Task 1 is done (commit `369a9c9`). Task 2's registration and guide extraction are done as of 2026-08-17 on a 개발계정; its confirmed values are in Task 3's contract table and in the design doc. What remains of Task 2 is the live-call observation, which Task 3's first dispatch supplies.

---

### Task 1: Period-partitioned snapshot script

**Files:**
- Create: `scripts/collect-period-snapshot.sh`
- Create: `harness/fixtures/period-snapshot.valid.json`
- Modify: `harness/scripts/smoke.sh`
- Modify: `SCHEMA.md`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `scripts/collect-period-snapshot.sh <envelope-json> <output-dir>`, which writes `<output-dir>/<period>.json`. Exit 0 when the period is written or already stored unchanged; exit 1 when the stored period differs, when `period` is missing or not `YYYY-MM`, or when required envelope metadata is absent; exit 2 on wrong argument count. Task 3 calls this script once per period.

- [ ] **Step 1: Write the fixture the tests run against**

Create `harness/fixtures/period-snapshot.valid.json`. The row field names below are illustrative — this fixture exercises the script's contract, which does not read into `payload`. Task 2 confirms the real field names, and none of them change this file's purpose.

```json
{
  "snapshotId": "kto-regional-visitors-2026-07",
  "sourceKind": "tourism-visitors",
  "period": "2026-07",
  "sourceUrl": "https://www.data.go.kr/data/15101972/openapi.do",
  "license": "이용허락범위 제한 없음",
  "collectedAt": "2026-08-17T00:00:00Z",
  "payload": {
    "response": {
      "header": { "resultCode": "00", "resultMsg": "OK" },
      "body": {
        "numOfRows": 3,
        "pageNo": 1,
        "totalCount": 3,
        "items": [
          { "signguCode": "11110", "signguNm": "종로구", "touNum": 1234567 },
          { "signguCode": "11140", "signguNm": "중구", "touNum": 2345678 },
          { "signguCode": "26350", "signguNm": "해운대구", "touNum": 3456789 }
        ]
      }
    }
  }
}
```

- [ ] **Step 2: Write the failing assertions**

Append to `harness/scripts/smoke.sh`, immediately after the `--sort-arrays` block that ends with the `"reordering counted as unchanged without --sort-arrays"` check (currently line 175) and before the `scripts/build-index.sh --check` line.

```bash
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
```

Also add these three lines to the existing check blocks near the top of the file: `require_file scripts/collect-period-snapshot.sh` after the `require_file scripts/collect-external-snapshot.sh` line (currently line 81), `require_file harness/fixtures/period-snapshot.valid.json` after the `harness/fixtures/external-tourism-snapshot.valid.json` line (currently line 65), and `[ -x scripts/collect-period-snapshot.sh ] || fail "scripts/collect-period-snapshot.sh is not executable"` after the matching check for `collect-external-snapshot.sh` (currently line 86).

- [ ] **Step 3: Run the smoke to verify it fails**

Run: `./harness/scripts/smoke.sh`
Expected: FAIL with `missing file: scripts/collect-period-snapshot.sh`

- [ ] **Step 4: Write the script**

Create `scripts/collect-period-snapshot.sh`:

```bash
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
```

Then: `chmod +x scripts/collect-period-snapshot.sh`

- [ ] **Step 5: Run the smoke to verify it passes**

Run: `./harness/scripts/smoke.sh`
Expected: PASS, ending with `smoke passed: 13 canonical pages checked`

- [ ] **Step 6: Document the rule in SCHEMA.md**

In "Scheduled Collection Rules", append rule 9 after the existing rule 8:

```markdown
9. **Partition a growing series by period, and treat a stored period as
   immutable.** A source that accumulates new rows over time does not fit the
   single-file model of `scripts/collect-external-snapshot.sh`: its payload
   changes on every run, so rule 5 stops filtering anything, and a rolling query
   window silently drops the oldest data out of the evidence layer. Use
   `scripts/collect-period-snapshot.sh`, which writes one file per `YYYY-MM`
   period and refuses to rewrite a period it has already stored. When a
   re-fetched period differs, the run fails and names the period, because a
   restated figure is a judgement for a human rather than an overwrite.
   Partitioning also settles what rule 6 leaves open: with the time axis in the
   file name, what remains inside a file is an unordered set, so a period file
   is always stored normalised.
```

In rule 6, append this sentence to the end of the existing paragraph:

```markdown
   A collector that partitions its series by period under rule 9 is not one of
   those cases; the time axis lives in its file names, not in its arrays.
```

- [ ] **Step 7: Run the smoke again**

Run: `./harness/scripts/smoke.sh`
Expected: PASS. This confirms the SCHEMA.md edit kept LF endings and a final newline.

- [ ] **Step 8: Commit**

```bash
git add scripts/collect-period-snapshot.sh harness/fixtures/period-snapshot.valid.json harness/scripts/smoke.sh SCHEMA.md
git commit -m "feat: store a growing series as immutable period snapshots

The single-file snapshot model overwrites, which fits a station list and
loses evidence for a time series. This writes one file per period, halts
when a stored period is restated, and normalises inside a period file
because splitting moved the time axis into the file name."
```

---

### Task 2: Confirm the endpoint contract

**Files:**
- Create: `raw/experiments/kto-regional-visitors-endpoint-verification.md`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: eleven confirmed values that Task 3 substitutes into the workflow. Named exactly as the `<...>` markers there: `ENDPOINT`, `OPERATION`, `SERVICE_KEY_PARAM`, `PERIOD_START_PARAM`, `PERIOD_END_PARAM`, `RETURN_TYPE_PARAM`, `ROWS_PARAM`, `PAGE_PARAM`, `ITEMS_JSON_PATH`, `PERIOD_FIELD`, `PERIOD_FIELD_FORMAT`.

This task is human work performed outside this repository. Rule 3 forbids a secret-dependent script under `scripts/`, and the air-quality collector's licence label was recorded from memory and turned out wrong, so every value here is read off the source rather than assumed.

- [ ] **Step 1: Apply for the dataset**

Apply for 활용신청 on [dataset 15101972](https://www.data.go.kr/data/15101972/openapi.do). The 운영단계 is 심의승인, not automatic, so this may take days. The existing `DATA_GO_KR_SERVICE_KEY` secret is reused — data.go.kr issues one key per account and only the per-dataset registration is new.

- [ ] **Step 2: Read the nine values out of the guide**

Download `TourAPI_Guide_(관광빅데이터)v4.1.zip` from the dataset page. These operation names are published nowhere else — they are not in any public code index — so the guide is the only source. Record:

| Value | What to find |
|---|---|
| `ENDPOINT` | full base URL including the service path |
| `OPERATION` | the operation returning **기초지자체 monthly** visitor counts |
| `SERVICE_KEY_PARAM` | the service-key parameter name |
| `PERIOD_START_PARAM` | the start-of-range parameter name |
| `PERIOD_END_PARAM` | the end-of-range parameter name |
| `RETURN_TYPE_PARAM` | the response-format parameter name **and its exact spelling** — AirKorea services differ between `returnType` and `_returnType` and answer XML when the name is wrong |
| `ROWS_PARAM` | the rows-per-page parameter name |
| `PAGE_PARAM` | the page-number parameter name |
| `ITEMS_JSON_PATH` | the jq path to the row array from the document root, e.g. `.response.body.items.item` |
| `PERIOD_FIELD` | the field on each row carrying the period |
| `PERIOD_FIELD_FORMAT` | whether that field reads `202607` or `2026-07` |

- [ ] **Step 3: Verify with one real call, outside this repository**

In a scratch directory that is not this repo, request a single known month:

```bash
curl -sS --fail-with-body --get "$ENDPOINT/$OPERATION" \
  --data-urlencode "$SERVICE_KEY_PARAM=$SERVICE_KEY" \
  --data-urlencode "$RETURN_TYPE_PARAM=json" \
  --data-urlencode "numOfRows=1000" \
  --data-urlencode "pageNo=1" \
  -o response.json
```

Substitute the real parameter names from step 2 for the period range. Then confirm the shape without printing the body:

```bash
jq -r '.response.header.resultCode' response.json
jq -r '.response.body.totalCount, .response.body.numOfRows' response.json
jq -r '[<ITEMS_JSON_PATH>[] | .<PERIOD_FIELD>] | unique' response.json
```

Expected: `resultCode` is `00`, `totalCount` does not exceed `numOfRows`, and the period list shows the format recorded in step 2.

- [ ] **Step 4: Capture the verification as raw evidence**

`raw/experiments/` is registered for "Public API verification results and response samples". Create `raw/experiments/kto-regional-visitors-endpoint-verification.md` recording: the date verified, the nine values, the observed `resultCode`, the observed `totalCount` for the month requested, and the licence label read off the dataset page. Do not paste the service key or any URL containing it.

- [ ] **Step 5: Commit**

```bash
git add raw/experiments/kto-regional-visitors-endpoint-verification.md
git commit -m "chore: verify the regional visitor count endpoint contract

Operation names for this service are published only inside the guide zip.
Recording the nine values read off the source, so the workflow header
states a confirmed contract rather than a remembered one."
```

---

### Task 3: Monthly collector workflow and first backfill

**Files:**
- Create: `.github/workflows/collect-regional-visitors.yml`
- Creates at runtime: `raw/external-snapshots/tourism-visitors/<YYYY-MM>.json`

**Interfaces:**
- Consumes: `scripts/collect-period-snapshot.sh <envelope-json> <output-dir>` from Task 1. It writes `<output-dir>/<period>.json`, exits 0 when the period is written or already stored unchanged, and exits non-zero when a stored period differs.
- Produces: period snapshot files that Task 4 cites as `sources`.

**Confirmed endpoint contract.** Read out of `TourAPI_Guide_(관광빅데이터)v4.1.zip` on 2026-08-17. These are verified values, not guesses — use them verbatim.

| Item | Value |
|---|---|
| Base URL | `http://apis.data.go.kr/B551011/DataLabService` |
| Operation | `locgoRegnVisitrDDList` (기초지자체) |
| Required params | `serviceKey`, `MobileOS`, `MobileApp`, `startYmd`, `endYmd` |
| Optional params | `_type`, `numOfRows`, `pageNo` |
| Date format | `yyyyMMdd` for `startYmd`/`endYmd` |
| Success code | `resultCode` is `0000` |
| Row array | `.response.body.items.item` |
| Row fields | `signguCode`, `signguNm`, `daywkDivCd`, `daywkDivNm`, `touDivCd`, `touDivNm`, `touNum`, `baseYmd` |

Three things about this API drive the design of the steps below:

1. **It is daily-only.** There is no monthly operation. The workflow requests a whole month as a date range and stores that month's daily rows unaggregated. Rolling them up would be derivation, which `raw/` does not hold.
2. **Pagination is the normal case.** One day returns roughly 740 rows, so a month is roughly 22,000. The air-quality collector fails when `totalCount` exceeds `numOfRows`; here that would fail on every run. This collector pages to completion and fails instead when the assembled row count does not equal `totalCount`.
3. **`_type=json` has a leading underscore** and the default response format is XML. A wrong parameter name yields XML with no error, which `jq empty` catches.

The secret `DATA_GO_KR_SERVICE_KEY` holds the URL-decoded key: the air-quality workflow passes it through `--data-urlencode` and succeeds, which is only possible with the decoded form.

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/collect-regional-visitors.yml`:

```yaml
name: Collect Regional Visitors

# Captures daily visitor counts per 기초지자체, stored one file per month, so a
# congestion record can eventually cite an observed distribution instead of an
# unsourced percentile scale.
#
# This is a growing time series, not a reference list, so it uses
# scripts/collect-period-snapshot.sh: one file per period, and a stored period is
# never rewritten. See "Scheduled Collection Rules" rule 9 in SCHEMA.md.
#
# Endpoint, operation, parameters, and response shape were read out of
# TourAPI_Guide_(관광빅데이터)v4.1.zip on the dataset page, 2026-08-17. Three of
# them are easy to get wrong from memory: resultCode is 0000 and not 00,
# MobileOS and MobileApp are required, and the response-format parameter is
# _type with a leading underscore whose default is XML.
#
# The API has no monthly operation. A month is requested as a date range and its
# daily rows are stored unaggregated, because aggregating before storage would
# put derived data in raw/.

on:
  schedule:
    # The 8th at 06:00 KST. Daily data lags about four days, so the previous
    # calendar month is complete by then. Offset from the other two crons.
    - cron: "0 21 7 * *"
  workflow_dispatch:
    inputs:
      months:
        description: "How many months back to collect, ending with last month. Use 1 to verify the contract, 18 for the initial backfill."
        required: false
        default: "3"

permissions:
  contents: write
  pull-requests: write

env:
  ENDPOINT: http://apis.data.go.kr/B551011/DataLabService/locgoRegnVisitrDDList
  SOURCE_KIND: tourism-visitors
  SOURCE_URL: https://www.data.go.kr/data/15101972/openapi.do
  LICENSE: 이용허락범위 제한 없음
  SNAPSHOT_DIR: raw/external-snapshots/tourism-visitors
  ROWS_PER_PAGE: "1000"

jobs:
  collect:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check for the service key
        id: guard
        env:
          SERVICE_KEY: ${{ secrets.DATA_GO_KR_SERVICE_KEY }}
        run: |
          if [ -z "$SERVICE_KEY" ]; then
            echo "::notice::DATA_GO_KR_SERVICE_KEY is not configured; skipping collection."
            echo "ready=false" >> "$GITHUB_OUTPUT"
          else
            echo "ready=true" >> "$GITHUB_OUTPUT"
          fi

      # The service key travels as a query parameter and logs on a public
      # repository are public. Never print the URL, never use curl -v, and let
      # curl do the encoding so the decoded key is not pre-encoded past the
      # log masker.
      - name: Collect each month
        if: steps.guard.outputs.ready == 'true'
        env:
          SERVICE_KEY: ${{ secrets.DATA_GO_KR_SERVICE_KEY }}
          MONTHS: ${{ github.event.inputs.months || '3' }}
        run: |
          case "$MONTHS" in
            ''|*[!0-9]*) echo "::error::months must be a positive integer"; exit 1 ;;
          esac
          if [ "$MONTHS" -lt 1 ] || [ "$MONTHS" -gt 18 ]; then
            echo "::error::months must be between 1 and 18"
            exit 1
          fi

          mkdir -p "$SNAPSHOT_DIR"
          work="$(mktemp -d)"

          for i in $(seq 1 "$MONTHS"); do
            month="$(date -u -d "$(date -u +%Y-%m-01) -$i month" +%Y-%m)"
            start="$(date -u -d "$month-01" +%Y%m%d)"
            end="$(date -u -d "$month-01 +1 month -1 day" +%Y%m%d)"
            rows_file="$work/rows-$month.jsonl"
            : > "$rows_file"
            page=1
            total=""

            while : ; do
              curl -sS --fail-with-body --get "$ENDPOINT" \
                --data-urlencode "serviceKey=$SERVICE_KEY" \
                --data-urlencode "MobileOS=ETC" \
                --data-urlencode "MobileApp=travel-context-wiki" \
                --data-urlencode "_type=json" \
                --data-urlencode "numOfRows=$ROWS_PER_PAGE" \
                --data-urlencode "pageNo=$page" \
                --data-urlencode "startYmd=$start" \
                --data-urlencode "endYmd=$end" \
                -o "$work/page.json"

              # A rejected key still returns HTTP 200 with an error envelope
              # that can echo the request back, so validate the shape and fail
              # without printing the body. A wrong _type spelling returns XML,
              # which fails here rather than silently storing markup.
              jq empty "$work/page.json" \
                || { echo "::error::response for $month page $page was not valid JSON"; exit 1; }

              code="$(jq -r '.response.header.resultCode // "missing"' "$work/page.json")"
              if [ "$code" != "0000" ]; then
                echo "::error::public data API returned resultCode=$code for $month page $page"
                exit 1
              fi

              total="$(jq -r '.response.body.totalCount // "missing"' "$work/page.json")"
              case "$total" in
                ''|*[!0-9]*) echo "::error::response body for $month has no numeric totalCount"; exit 1 ;;
              esac

              if [ "$page" -eq 1 ]; then
                jq '.response.header' "$work/page.json" > "$work/header-$month.json"
              fi

              # items.item collapses to a single object when a page holds one
              # row, so normalise to an array before appending.
              jq -c '(.response.body.items.item // [])
                     | if type == "object" then [.] else . end
                     | .[]' "$work/page.json" >> "$rows_file"

              have="$(wc -l < "$rows_file" | tr -d ' ')"
              [ "$have" -lt "$total" ] || break

              page=$((page + 1))
              if [ "$page" -gt 200 ]; then
                echo "::error::pagination for $month passed 200 pages; refusing to keep requesting"
                exit 1
              fi
            done

            have="$(wc -l < "$rows_file" | tr -d ' ')"

            # An unpublished month returns zero rows. Storing it would freeze an
            # empty period that the immutability check then refuses to replace
            # once the real data arrives.
            if [ "$total" -eq 0 ]; then
              echo "::notice::$month has no rows yet; skipping."
              continue
            fi

            if [ "$have" -ne "$total" ]; then
              echo "::error::assembled $have rows for $month but totalCount is $total"
              exit 1
            fi

            jq -s '.' "$rows_file" > "$work/items-$month.json"

            # request records how this document was assembled, because the
            # payload is many paginated responses rather than one. It sits
            # outside payload so that a change in page count is not compared as
            # a restatement of the data.
            jq -n \
              --slurpfile items "$work/items-$month.json" \
              --slurpfile header "$work/header-$month.json" \
              --arg period "$month" \
              --arg start "$start" \
              --arg end "$end" \
              --arg pages "$page" \
              --argjson total "$total" \
              --arg sourceKind "$SOURCE_KIND" \
              --arg sourceUrl "$SOURCE_URL" \
              --arg license "$LICENSE" \
              --arg collectedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              '{snapshotId: ("kto-regional-visitors-" + $period),
                sourceKind: $sourceKind,
                period: $period,
                sourceUrl: $sourceUrl,
                license: $license,
                collectedAt: $collectedAt,
                request: {startYmd: $start, endYmd: $end,
                          pages: ($pages | tonumber), totalCount: $total},
                payload: {response: {header: $header[0],
                                     body: {items: {item: $items[0]},
                                            totalCount: $total}}}}' \
              > "$work/envelope-$month.json"

            scripts/collect-period-snapshot.sh "$work/envelope-$month.json" "$SNAPSHOT_DIR"
          done

          rm -rf "$work"

      # scripts/build-index.sh is deliberately not run here. It reads canonical
      # pages, records/, and packages/ only, so a capture under raw/ cannot move
      # any index artifact until a human writes a record that cites it.
      - name: Detect a real change
        if: steps.guard.outputs.ready == 'true'
        id: diff
        run: |
          if [ -n "$(git status --porcelain "$SNAPSHOT_DIR")" ]; then
            echo "changed=true" >> "$GITHUB_OUTPUT"
          else
            echo "::notice::no new period; nothing to propose."
            echo "changed=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Verify the capture still satisfies the contract
        if: steps.diff.outputs.changed == 'true'
        run: ./harness/scripts/smoke.sh

      - name: Open a pull request
        if: steps.diff.outputs.changed == 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          branch="collect/regional-visitors-$(date -u +%Y%m%d-%H%M%S)"
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git checkout -b "$branch"
          git add "$SNAPSHOT_DIR"
          git commit -m "chore: capture regional visitor counts"
          git push -u origin "$branch"
          printf '%s\n' \
            "Scheduled capture of daily visitor counts per 기초지자체, stored one file per month. Stored periods are never rewritten." \
            "" \
            "Rows are as the source returned them. \`touDivCd\` splits each region-day into 현지인, 외지인, and 외국인; no rollup is applied, because aggregating before storage would put derived data in \`raw/\`." \
            "" \
            "Evidence only: this touches \`raw/external-snapshots/tourism-visitors/\` and nothing else. Deriving \`records/\`, rebuilding \`indexes/\`, and promoting canonical pages stay human work." \
            "" \
            "No checks will appear below. A pull request opened with \`GITHUB_TOKEN\` does not trigger other workflows, so \`Wiki Batch Checks\` stays idle here. The collecting run already executed \`./harness/scripts/smoke.sh\` against this exact tree before opening the pull request." \
            > pr-body.md
          gh pr create --base main --head "$branch" \
            --title "chore: capture regional visitor counts" \
            --body-file pr-body.md
```

- [ ] **Step 2: Check the smoke still passes**

Run: `./harness/scripts/smoke.sh`
Expected: PASS. The smoke's file-format check covers `.yml` outside `raw/`, so this catches a missing final newline or CRLF.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/collect-regional-visitors.yml
git commit -m "feat: collect regional visitor counts monthly

The API is daily-only with no monthly operation, so a month is fetched as
a date range and its daily rows are stored unaggregated. Pagination is the
normal case here, not the exception it is for air quality, so the run
pages to completion and fails when the assembled count misses totalCount."
```

Do not push or dispatch. Step 4 is the controller's, because it needs the branch merged and a live secret.

---

### Task 4: Rule-1 decision document

**Files:**
- Create: `decisions/aggregate-mobility-is-not-user-location.md`
- Modify: `index.md`
- Modify: `log.md`
- Modify: `indexes/manifest.json`, `indexes/chunks.jsonl`, `indexes/source-map.json` (regenerated, not hand-edited)

**Interfaces:**
- Consumes: `raw/experiments/kto-regional-visitors-endpoint-verification.md` from Task 2 and a captured period file from Task 3, both cited as `sources`. This task must run after both, because `SCHEMA.md` requires `sources` to point at existing files under `raw/`.
- Produces: canonical page count 14.

- [ ] **Step 1: Write the decision page**

Create `decisions/aggregate-mobility-is-not-user-location.md`. Replace `2026-07` in the `sources` list with a period file that actually exists after Task 3, and set `created`/`updated` to the day you write it.

```markdown
---
title: Aggregate Mobility Is Not User Location
created: 2026-08-17
updated: 2026-08-17
type: decision
tags:
  - api-compliance
  - public-data
  - congestion
sources:
  - raw/experiments/kto-regional-visitors-endpoint-verification.md
  - raw/external-snapshots/tourism-visitors/2026-07.json
confidence: medium
contested: false
contradictions: []
---

# Aggregate Mobility Is Not User Location

## Decision

A scheduled collector may capture region-level visitor counts derived from mobile carrier data. Rule 1 of "Scheduled Collection Rules" does not exclude them.

## Reason

Rule 1 forbids a response describing user identity, user location, or user history. This response describes a place: a 기초지자체 and how many visitors it recorded in a month. No row corresponds to a person, and no row can be narrowed to one.

The upstream derivation is not the test. If it were, rule 1 would also exclude the air-quality station list, which exists because people live near the stations.

## Consequences

- `raw/external-snapshots/tourism-visitors/` may accumulate one capture per month.
- [[congestion-diagnosis]] can eventually cite an observed distribution instead of an unsourced percentile scale.
- The exception does not widen. Individual-level records, trajectories, and raw location traces stay out of this repository regardless of source.
- A future collector claiming this precedent must describe places rather than people. Aggregating a person-level response after the fact does not convert it.

## Related Pages

- [[congestion-diagnosis]]
- [[raw-derived-data-separation]]
```

- [ ] **Step 2: Add the index entry**

In `index.md`, change `Active canonical pages: 13` to `Active canonical pages: 14`, and insert this line into the Decisions section. It sorts first alphabetically, above `keep-llm-out-of-ranking`:

```markdown
- [[aggregate-mobility-is-not-user-location]] - 이동통신에서 파생된 지역 단위 집계는 규칙 1이 금지하는 사용자 위치가 아니다.
```

- [ ] **Step 3: Append the log entry**

Append to `log.md`, matching the heading grammar the smoke enforces:

```markdown
## 2026-08-17 - create - allow region-level mobility aggregates as evidence

- Created: `decisions/aggregate-mobility-is-not-user-location.md`. Rule 1 of "Scheduled Collection Rules" forbids a response describing user location, and the regional visitor count dataset is derived from KT and SKT mobile data, so a reader stops on it. The response describes a 기초지자체 and a count, not a person, which is what rule 1 permits.
- The decision states the boundary rather than only the permission: individual-level records, trajectories, and raw location traces stay out regardless of source, and aggregating a person-level response after the fact does not convert it.
- Sourced against the endpoint verification and a real capture rather than the design note, because `sources` must point under `raw/`.
- Canonical pages 13 to 14.
```

- [ ] **Step 4: Regenerate the indexes**

Adding a canonical page changes `indexes/`, and CI runs `scripts/build-index.sh --check`.

Run: `scripts/build-index.sh`
Expected: `rebuilt indexes/manifest.json indexes/chunks.jsonl indexes/source-map.json`

- [ ] **Step 5: Verify**

Run: `./harness/scripts/smoke.sh`
Expected: PASS, ending with `smoke passed: 14 canonical pages checked`

- [ ] **Step 6: Commit**

```bash
git add decisions/aggregate-mobility-is-not-user-location.md index.md log.md indexes/
git commit -m "docs: record that region-level mobility aggregates pass rule 1

The dataset is derived from carrier location data, so rule 1 needs an
explicit reading rather than a workflow comment. States the boundary too,
so the exception does not spread to person-level sources."
```

---

## Verification

The whole plan is done when all of these hold:

- `./harness/scripts/smoke.sh` passes, reporting 14 canonical pages.
- `scripts/build-index.sh --check` passes.
- `raw/external-snapshots/tourism-visitors/` contains one file per backfilled month, each named `YYYY-MM.json`.
- Re-running `gh workflow run collect-regional-visitors.yml` with the default span opens **no** pull request, because every period in the span is already stored and unchanged. This is the check that proves the collector goes quiet — the failure the air-quality collector had to be repaired for.
