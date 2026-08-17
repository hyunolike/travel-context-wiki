# Collection Stats Image Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Draw the repository's external-evidence coverage as a hand-drawn SVG, embedded in `README.md` and redrawn daily by a workflow that commits only when the picture changes.

**Architecture:** A shell script extracts metrics from `raw/external-snapshots/` with `jq` and hands them to a `jq` program that emits SVG. All sketch wobble is produced by a Lehmer generator seeded from the metrics themselves, so identical evidence renders byte-identically. A workflow redraws, refuses to commit if any path other than the artifact is dirty, and pushes to `main`.

**Tech Stack:** POSIX shell, `jq` (no other runtime), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-17-collection-stats-image-design.md`

## Global Constraints

- `jq` and POSIX shell only. No Python, no Node, no npm. Every script under `scripts/` must run with no secret present (SCHEMA rule 3).
- The output must be a pure function of committed files. **Nothing time-varying may reach the SVG — especially not the current date.** An unchanged input must produce a byte-identical file, or the daily workflow commits every day.
- Sketch jitter comes from `noise(seed_of($metrics); …)`, never from a real random source.
- Text files: UTF-8, LF, no BOM, final newline. `harness/scripts/smoke.sh` enforces this for `.md`, `.json`, `.jsonl`, `.sh`, `.yml`.
- Palette, fixed: paper `#fdfdf7`, ink `#1e1e1e`, muted `#5c5c5c`, accent `#4c6ef5`.
- Font stack, fixed: `Comic Sans MS, Chalkboard SE, Segoe Print, Bradley Hand, cursive`.
- The artifact path is exactly one: `docs/collection-stats.svg`.
- **`--check` is never added to `harness/scripts/smoke.sh`.** `wiki-batch.yml` runs smoke on every push and pull request, and the stats workflow runs smoke before pushing. Wiring `--check` there would turn `main` red between merging a capture and redrawing, and would deadlock the stats workflow against its own output. Staleness is closed by the workflow's `push` trigger instead.

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/build-collection-stats.sh` (create) | Argument parsing, metric extraction from snapshots, and the render/check/metrics modes. Knows the evidence layout; knows nothing about SVG. |
| `scripts/collection-stats.jq` (create) | Pure metrics-document → SVG renderer, including the deterministic sketch primitives. Knows nothing about the filesystem. |
| `harness/fixtures/collection-stats/**` (create) | Small, fixed-date envelopes shaped like the real ones. |
| `harness/scenarios/collection-stats-image.md` (create) | Given/When/Then for the behaviour worth protecting. |
| `harness/scripts/smoke.sh` (modify) | Assertions on metrics, determinism, empty state, and `--check`. |
| `docs/collection-stats.svg` (create) | The generated artifact. |
| `README.md` (modify) | The embed, in a new `## 수집 현황` section. |
| `.github/workflows/collection-stats.yml` (create) | Daily redraw, single-path guard, push to `main`. |
| `SCHEMA.md` (modify) | New "Generated Artifact Rules" section. |
| `log.md` (modify) | One `create` entry. |

The split between the two `scripts/` files is what makes the renderer testable without a filesystem and the extractor testable without parsing SVG.

---

### Task 1: Metric extraction

**Files:**
- Create: `harness/fixtures/collection-stats/tourism-visitors/2026-06.json`
- Create: `harness/fixtures/collection-stats/tourism-visitors/2026-07.json`
- Create: `harness/fixtures/collection-stats/air-quality-airkorea-station-list.json`
- Create: `harness/scenarios/collection-stats-image.md`
- Create: `scripts/build-collection-stats.sh`
- Test: `harness/scripts/smoke.sh` (insert after the period-snapshot assertion block, before the `scripts/build-index.sh --check` line)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `scripts/build-collection-stats.sh --metrics [--snapshot-dir DIR]`, writing this exact document to stdout with sorted keys:

```json
{
  "lastCollectedAt": "2026-08-12",
  "periods": {
    "count": 2,
    "first": "2026-06",
    "last": "2026-07",
    "regions": 5,
    "rows": 10,
    "series": [{"period": "2026-06", "rows": 4}, {"period": "2026-07", "rows": 6}]
  },
  "stations": {"count": 673}
}
```

- [ ] **Step 1: Write the fixtures**

`harness/fixtures/collection-stats/tourism-visitors/2026-06.json`:

```json
{
  "collectedAt": "2026-07-08T21:00:00Z",
  "license": "이용허락범위 제한 없음",
  "payload": {
    "response": {
      "body": {
        "items": {
          "item": [
            {"baseYmd": "20260601", "signguCode": "11110", "signguNm": "종로구", "touDivCd": "1", "touNum": 1000},
            {"baseYmd": "20260601", "signguCode": "11140", "signguNm": "중구", "touDivCd": "1", "touNum": 900},
            {"baseYmd": "20260602", "signguCode": "11110", "signguNm": "종로구", "touDivCd": "2", "touNum": 800},
            {"baseYmd": "20260602", "signguCode": "11170", "signguNm": "용산구", "touDivCd": "3", "touNum": 700}
          ]
        },
        "totalCount": 4
      },
      "header": {"resultCode": "0000", "resultMsg": "OK"}
    }
  },
  "period": "2026-06",
  "request": {"endYmd": "20260630", "pages": 1, "startYmd": "20260601", "totalCount": 4},
  "snapshotId": "kto-regional-visitors-2026-06",
  "sourceKind": "tourism-visitors",
  "sourceUrl": "https://www.data.go.kr/data/15101972/openapi.do"
}
```

`harness/fixtures/collection-stats/tourism-visitors/2026-07.json` — note **five** distinct `signguCode` values, so the region count can only pass if it is read from the latest period and not from every period:

```json
{
  "collectedAt": "2026-08-08T21:00:00Z",
  "license": "이용허락범위 제한 없음",
  "payload": {
    "response": {
      "body": {
        "items": {
          "item": [
            {"baseYmd": "20260701", "signguCode": "11110", "signguNm": "종로구", "touDivCd": "1", "touNum": 1100},
            {"baseYmd": "20260701", "signguCode": "11140", "signguNm": "중구", "touDivCd": "1", "touNum": 950},
            {"baseYmd": "20260701", "signguCode": "11170", "signguNm": "용산구", "touDivCd": "1", "touNum": 720},
            {"baseYmd": "20260702", "signguCode": "11200", "signguNm": "성동구", "touDivCd": "2", "touNum": 610},
            {"baseYmd": "20260702", "signguCode": "11215", "signguNm": "광진구", "touDivCd": "2", "touNum": 580},
            {"baseYmd": "20260702", "signguCode": "11110", "signguNm": "종로구", "touDivCd": "3", "touNum": 240}
          ]
        },
        "totalCount": 6
      },
      "header": {"resultCode": "0000", "resultMsg": "OK"}
    }
  },
  "period": "2026-07",
  "request": {"endYmd": "20260731", "pages": 1, "startYmd": "20260701", "totalCount": 6},
  "snapshotId": "kto-regional-visitors-2026-07",
  "sourceKind": "tourism-visitors",
  "sourceUrl": "https://www.data.go.kr/data/15101972/openapi.do"
}
```

`harness/fixtures/collection-stats/air-quality-airkorea-station-list.json` — this collector's envelope has no `period` and its `items` is a bare array, so the extractor must not assume the visitor shape:

```json
{
  "collectedAt": "2026-08-12T20:49:15Z",
  "license": "공공누리 제3유형 (출처표시 + 변경금지)",
  "payload": {
    "response": {
      "body": {
        "items": [
          {"stationName": "종로구", "addr": "서울 종로구"},
          {"stationName": "중구", "addr": "서울 중구"}
        ],
        "numOfRows": 1000,
        "pageNo": 1,
        "totalCount": 673
      },
      "header": {"resultCode": "00", "resultMsg": "NORMAL_CODE"}
    }
  },
  "snapshotId": "airkorea-station-list",
  "sourceKind": "air-quality",
  "sourceUrl": "https://www.data.go.kr/data/15073877/openapi.do"
}
```

`totalCount` is deliberately 673 while `items` holds two rows: the metric reads `totalCount`, and the fixture proves it does not silently fall back to counting rows.

- [ ] **Step 2: Write the scenario**

`harness/scenarios/collection-stats-image.md`:

```markdown
# Collection stats image

증거 계층이 실제로 얼마나 모였는지를 README 첫 화면에서 읽을 수 있어야 한다.
이 시나리오는 그림의 좌표가 아니라 **숫자와 결정론**을 고정한다. 좌표를 고정하면
시각적 수정마다 테스트를 고쳐야 하면서 정작 깨질 수 있는 것은 못 잡는다.

## Scenario: 저장된 증거에서 지표를 읽는다

- **Given** `harness/fixtures/collection-stats/`에 2026-06, 2026-07 기간 스냅샷과
  측정소 스냅샷이 있고
- **When** `scripts/build-collection-stats.sh --metrics`를 그 디렉터리에 대해 실행하면
- **Then** 기간 2개, 기간 범위 2026-06~2026-07, 일별 행 합계 10, 측정소 673,
  마지막 수집일 2026-08-12를 보고한다
- **And** 기초지자체 수는 5다 — 가장 최근 기간에서만 센다. 전 기간을 합치면 6이
  나오는데, 그것은 "지금 커버리지"가 아니라 "한 번이라도 등장한 지역"이다.

## Scenario: 수집 전에도 그림이 나온다

- **Given** 스냅샷이 하나도 없는 디렉터리가 있고
- **When** 같은 스크립트를 실행하면
- **Then** 0으로 채운 지표를 내고 종료코드 0으로 끝난다
- **And** 렌더된 SVG는 "아직 수집된 기간이 없습니다"를 담는다

## Scenario: 빠진 달이 구멍으로 남는다

- **Given** 2026-05와 2026-07은 있고 2026-06은 없는 지표 문서가 있고
- **When** 렌더러에 직접 넣으면
- **Then** 06 칸이 빈 테두리로 그려진다

  이 그림이 존재하는 이유가 그 구멍이다. 빠진 달을 아예 생략하는 형태는
  수집이 실패한 상태에서도 건강해 보인다.

## Scenario: 같은 증거는 같은 그림이 된다

- **Given** 동일한 픽스처가 있고
- **When** 렌더를 두 번 실행하면
- **Then** 두 SVG는 바이트 단위로 동일하다
- **And** 출력 어디에도 실행 당일 날짜가 없다

  워크플로가 매일 돌면서 그림이 바뀌었을 때만 커밋하기 때문이다. 난수 흔들림이나
  생성 시각 각인은 매일 동일한 그림을 새 커밋으로 만들어 이 정책을 무력화한다.

## Scenario: 낡은 이미지를 알아챈다

- **Given** 입력과 더 이상 맞지 않는 SVG가 있고
- **When** `--check`를 실행하면
- **Then** 0이 아닌 코드로 실패하고 어떤 파일이 낡았는지 말한다
```

- [ ] **Step 3: Write the failing assertions in smoke**

Insert into `harness/scripts/smoke.sh`, immediately after the period-snapshot block (the one ending with the `writing a new period altered an existing one` assertion) and before `scripts/build-index.sh --check`:

```bash
# The stats image is a pure function of committed evidence, so its metrics are
# pinned against fixtures rather than against whatever raw/ happens to hold on
# the day the suite runs.
stats_fixtures=harness/fixtures/collection-stats
stats_metrics="$TMP_DIR/stats-metrics.json"
scripts/build-collection-stats.sh --metrics --snapshot-dir "$stats_fixtures" > "$stats_metrics"

[ "$(jq -r '.periods.count' "$stats_metrics")" = "2" ] || fail "collection stats counted the wrong number of periods"
[ "$(jq -r '.periods.first' "$stats_metrics")" = "2026-06" ] || fail "collection stats reported the wrong first period"
[ "$(jq -r '.periods.last' "$stats_metrics")" = "2026-07" ] || fail "collection stats reported the wrong last period"
[ "$(jq -r '.periods.rows' "$stats_metrics")" = "10" ] || fail "collection stats summed the wrong row count"
[ "$(jq -r '.stations.count' "$stats_metrics")" = "673" ] || fail "collection stats reported the wrong station count"
[ "$(jq -r '.lastCollectedAt' "$stats_metrics")" = "2026-08-12" ] || fail "collection stats reported the wrong last collection date"

# Coverage is a statement about now, so it is read from the newest period only.
# Unioning every period would answer "which regions ever appeared", which is a
# different and more flattering question. The fixtures differ (5 vs 6) so that
# the wrong reading cannot pass.
[ "$(jq -r '.periods.regions' "$stats_metrics")" = "5" ] || fail "collection stats counted regions outside the latest period"

# The collectors run on their own schedule, so the image has to render before
# the first capture rather than divide by zero.
mkdir -p "$TMP_DIR/empty-snapshots"
empty_metrics="$TMP_DIR/stats-metrics-empty.json"
scripts/build-collection-stats.sh --metrics --snapshot-dir "$TMP_DIR/empty-snapshots" > "$empty_metrics"
[ "$(jq -r '.periods.count' "$empty_metrics")" = "0" ] || fail "collection stats did not report zero periods for an empty evidence layer"
[ "$(jq -r '.periods.rows' "$empty_metrics")" = "0" ] || fail "collection stats did not report zero rows for an empty evidence layer"
[ "$(jq -r '.lastCollectedAt' "$empty_metrics")" = "" ] || fail "collection stats invented a collection date for an empty evidence layer"
```

- [ ] **Step 4: Run smoke to verify it fails**

Run: `./harness/scripts/smoke.sh`
Expected: FAIL — `harness/scripts/smoke.sh: line …: scripts/build-collection-stats.sh: No such file or directory`

- [ ] **Step 5: Write the extractor**

`scripts/build-collection-stats.sh`:

```bash
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
```

- [ ] **Step 6: Make it executable and run smoke to verify it passes**

```bash
chmod +x scripts/build-collection-stats.sh
./harness/scripts/smoke.sh
```

Expected: PASS, ending with `smoke passed: … canonical pages checked`.

- [ ] **Step 7: Commit**

```bash
git add scripts/build-collection-stats.sh harness/fixtures/collection-stats harness/scenarios/collection-stats-image.md harness/scripts/smoke.sh
git commit -m "$(cat <<'EOF'
feat: read collection coverage out of the evidence layer

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Deterministic hand-drawn renderer

**Files:**
- Create: `scripts/collection-stats.jq`
- Modify: `scripts/build-collection-stats.sh` (replace the `fail "rendering is not implemented yet"` line)
- Test: `harness/scripts/smoke.sh` (append to the block added in Task 1)

**Interfaces:**
- Consumes: the metrics document from Task 1, exactly as specified there.
- Produces: `scripts/build-collection-stats.sh [--snapshot-dir DIR] [--out FILE]` writing an SVG, and `scripts/collection-stats.jq` usable directly as `jq -r -f scripts/collection-stats.jq metrics.json`.

- [ ] **Step 1: Write the failing assertions in smoke**

Append to the stats block in `harness/scripts/smoke.sh`:

```bash
# The workflow commits only when the picture changes, so identical evidence
# must render byte-identically. A real random jitter would produce a new file
# every day and turn a "no change" policy into a daily commit.
scripts/build-collection-stats.sh --snapshot-dir "$stats_fixtures" --out "$TMP_DIR/stats-a.svg" >/dev/null
scripts/build-collection-stats.sh --snapshot-dir "$stats_fixtures" --out "$TMP_DIR/stats-b.svg" >/dev/null
cmp -s "$TMP_DIR/stats-a.svg" "$TMP_DIR/stats-b.svg" || fail "collection stats rendered differently from identical inputs"

head -c 4 "$TMP_DIR/stats-a.svg" | grep -q '<svg' || fail "collection stats output does not open with an svg element"
tail -c 7 "$TMP_DIR/stats-a.svg" | grep -q '</svg>' || fail "collection stats output does not close its svg element"

# GitHub's dark theme shows through a transparent background, so the canvas is
# painted rather than inherited.
grep -q 'fill="#fdfdf7"' "$TMP_DIR/stats-a.svg" || fail "collection stats output has no opaque paper background"

# Nothing time-varying may reach the output. The fixtures carry fixed dates, so
# today's date can only appear here by being stamped in.
stats_today="$(date -u +%Y-%m-%d)"
if grep -q "$stats_today" "$TMP_DIR/stats-a.svg"; then
  fail "collection stats stamped the current date into the image"
fi
grep -q '2026-08-12' "$TMP_DIR/stats-a.svg" || fail "collection stats did not show the last collection date"

# One labelled cell per month in the covered span.
grep -q '>06</text>' "$TMP_DIR/stats-a.svg" || fail "collection stats did not label its month cells"
grep -q '>07</text>' "$TMP_DIR/stats-a.svg" || fail "collection stats did not label its month cells"

# A month missing from the series must still get a cell, drawn empty. That gap
# is the one thing this figure exists to show: a form that simply omits the
# month looks healthy while hiding a failed capture. Fed straight to the
# renderer, which is what the two-stage split is for.
printf '%s\n' '{"lastCollectedAt":"2026-08-12","periods":{"count":2,"first":"2026-05","last":"2026-07","regions":5,"rows":10,"series":[{"period":"2026-05","rows":5},{"period":"2026-07","rows":5}]},"stations":{"count":673}}' > "$TMP_DIR/stats-gap.json"
jq -r -f scripts/collection-stats.jq "$TMP_DIR/stats-gap.json" > "$TMP_DIR/stats-gap.svg"
[ "$(grep -c '>06</text>' "$TMP_DIR/stats-gap.svg")" = "1" ] || fail "collection stats dropped the month missing from the series"

scripts/build-collection-stats.sh --snapshot-dir "$TMP_DIR/empty-snapshots" --out "$TMP_DIR/stats-empty.svg" >/dev/null
grep -q '아직 수집된 기간이 없습니다' "$TMP_DIR/stats-empty.svg" || fail "collection stats did not render the empty state"
```

- [ ] **Step 2: Run smoke to verify it fails**

Run: `./harness/scripts/smoke.sh`
Expected: FAIL with `FAIL: rendering is not implemented yet`

- [ ] **Step 3: Write the renderer**

`scripts/collection-stats.jq`:

```jq
# Renders the collection-stats metrics document as a hand-drawn SVG.
#
# Pure: input is the metrics document, output is the SVG text. It never reads a
# clock or a random source. That is a contract, not a style choice — the daily
# workflow commits only when this output changes, so any non-determinism turns
# into a commit per day that says nothing.

def r: (. * 10 | round) / 10;

def esc:
  tostring | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");

def commas:
  (tostring | explode | reverse) as $d
  | [ range($d | length) as $i
      | ( $d[$i],
          (if ($i % 3 == 2) and ($i < ($d | length) - 1) then 44 else empty end) ) ]
  | reverse | implode;


def midx: (.[0:4] | tonumber) * 12 + (.[5:7] | tonumber) - 1;
def mstr: (. / 12 | floor) as $y | (. % 12 + 1) as $mo
  | "\($y)-\(if $mo < 10 then "0" else "" end)\($mo)";

# djb2 over the serialised metrics. Seeding from the data is what ties the
# sketch to the numbers: change a value and only that shape moves.
def seed_of($doc):
  (reduce ($doc | tojson | explode[]) as $c (5381; ((. * 33) + $c) % 2147483647))
  | if . == 0 then 1 else . end;

# MINSTD. The multiplier is chosen so every intermediate product stays below
# 2^53 and is therefore exact in the IEEE doubles jq uses; a larger one would
# lose precision and could drift between platforms, which is the one thing this
# generator cannot afford.
def noise($seed; $n):
  [ foreach range($n) as $_ ($seed; (. * 16807) % 2147483647; (. / 2147483647) - 0.5) ];

def w($N; $k): $N[((($k % 4096) + 4096) % 4096)];

# One pen stroke: a cubic whose control points are pulled off the straight line.
# Endpoints move less than the middle, so corners still read as corners.
def rline($N; $x1; $y1; $x2; $y2; $k; $amp):
    ($x1 + w($N; $k)     * $amp * 1.1) as $ax
  | ($y1 + w($N; $k + 1) * $amp * 1.1) as $ay
  | ($x2 + w($N; $k + 2) * $amp * 1.1) as $bx
  | ($y2 + w($N; $k + 3) * $amp * 1.1) as $by
  | ($x1 + ($x2 - $x1) / 3       + w($N; $k + 4) * $amp * 3.2) as $c1x
  | ($y1 + ($y2 - $y1) / 3       + w($N; $k + 5) * $amp * 3.2) as $c1y
  | ($x1 + ($x2 - $x1) * 2 / 3   + w($N; $k + 6) * $amp * 3.2) as $c2x
  | ($y1 + ($y2 - $y1) * 2 / 3   + w($N; $k + 7) * $amp * 3.2) as $c2y
  | "M\($ax|r) \($ay|r) C\($c1x|r) \($c1y|r) \($c2x|r) \($c2y|r) \($bx|r) \($by|r)";

def stroke_path($d; $colour; $width; $opacity):
  "<path d=\"\($d)\" fill=\"none\" stroke=\"\($colour)\" stroke-width=\"\($width)\" stroke-opacity=\"\($opacity)\" stroke-linecap=\"round\"/>";

# Two passes over the same edge. The divergence between them is the whole
# effect; one pass just looks like a wobbly line.
def sketch_line($N; $x1; $y1; $x2; $y2; $k; $amp; $colour; $width):
  stroke_path(rline($N; $x1; $y1; $x2; $y2; $k; $amp); $colour; $width; 1)
  + stroke_path(rline($N; $x1; $y1; $x2; $y2; $k + 8; $amp); $colour; $width; 0.75);

# Edges overshoot their corners, which is what separates a hand-drawn rectangle
# from a merely imprecise one.
def sketch_rect($N; $x; $y; $wd; $ht; $k; $amp; $colour; $width):
    ($amp * 1.4) as $o
  | sketch_line($N; $x - $o;       $y;             $x + $wd + $o; $y;             $k;      $amp; $colour; $width)
  + sketch_line($N; $x + $wd;      $y - $o;        $x + $wd;      $y + $ht + $o;  $k + 16; $amp; $colour; $width)
  + sketch_line($N; $x + $wd + $o; $y + $ht;       $x - $o;       $y + $ht;       $k + 32; $amp; $colour; $width)
  + sketch_line($N; $x;            $y + $ht + $o;  $x;            $y - $o;        $k + 48; $amp; $colour; $width);

# 45-degree fill, clipped analytically rather than with a clipPath element:
# GitHub proxies and sanitises a repository SVG, and plain <path> is the part
# of the format nothing argues with. For y = x + c the visible span is
# x from max(x0, y0 - c) to min(x1, y1 - c).
def hachure($N; $x; $y; $wd; $ht; $k; $gap; $colour; $width; $opacity):
    ($x + $wd) as $x1
  | ($y + $ht) as $y1
  | [ range((($y - $x1) / $gap | floor); (($y1 - $x) / $gap | ceil) + 1) as $i
      | ($i * $gap) as $c
      | ([$x, $y - $c] | max) as $sx
      | ([$x1, $y1 - $c] | min) as $ex
      | select($ex - $sx > 1)
      | stroke_path(rline($N; $sx; $sx + $c; $ex; $ex + $c; $k + $i * 8; 2.2); $colour; $width; $opacity) ]
  | join("");

def text_at($x; $y; $size; $colour; $anchor; $s):
  "<text x=\"\($x|r)\" y=\"\($y|r)\" font-family=\"Comic Sans MS, Chalkboard SE, Segoe Print, Bradley Hand, cursive\" font-size=\"\($size)\" fill=\"\($colour)\" text-anchor=\"\($anchor)\">\($s|esc)</text>";

"#fdfdf7" as $PAPER
| "#1e1e1e" as $INK
| "#5c5c5c" as $MUTED
| "#4c6ef5" as $ACCENT
| 900 as $W
| . as $m
| noise(seed_of($m); 4096) as $N
| ($m.periods.series) as $series
| ($series | length) as $n
| (if $n > 0 then 322 else 234 + 76 end) as $chartBottom
| ($chartBottom + 56) as $H

# Four headline numbers. A stat tile, not a chart: each is a single value with
# no comparison to make, and a bar of one bar is not a figure.
| [ {value: ($m.periods.count | tostring), caption: "수집 개월"},
    {value: ($m.periods.rows | commas),    caption: "일별 행"},
    {value: ($m.periods.regions | tostring), caption: "기초지자체"},
    {value: ($m.stations.count | commas),  caption: "대기측정소"} ] as $tiles

| ( [ range(4) as $i
      | (44 + $i * 216) as $tx
      | ($tx + 98) as $cx
      | sketch_rect($N; $tx; 88; 196; 84; 200 + $i * 96; 3.4; $INK; 1.6)
        + text_at($cx; 130; 32; $INK; "middle"; $tiles[$i].value)
        + text_at($cx; 156; 15; $MUTED; "middle"; $tiles[$i].caption) ]
    | join("") ) as $tileSvg

| ( if $n > 0 then
      ([$series[].period] | map(midx)) as $have
      | ($have | min) as $lo
      | ($have | max) as $hi
      | ($hi - $lo + 1) as $span
      | ([56, 812 / $span] | min) as $cw
      | [ range($span) as $i
          | ($lo + $i) as $mi
          | (44 + $i * $cw) as $cx
          | ($cw - 7) as $cwd
          | (1200 + $i * 640) as $k
          | (if ($have | index($mi)) then
               hachure($N; $cx; 234; $cwd; 44; $k; 11; $ACCENT; 1.2; 0.55)
               + sketch_rect($N; $cx; 234; $cwd; 44; $k + 96; 2.6; $ACCENT; 1.6)
             else
               sketch_rect($N; $cx; 234; $cwd; 44; $k + 96; 2.6; $MUTED; 1.2)
             end)
          + text_at($cx + $cwd / 2; 296; 13; $MUTED; "middle"; ($mi | mstr | .[5:7]))
          + (if ($mi % 12) == 0 or $i == 0
             then text_at($cx + $cwd / 2; 312; 12; $MUTED; "middle"; ($mi | mstr | .[0:4]))
             else "" end) ]
      | join("")
    else
      sketch_rect($N; 44; 234; 812; 60; 1200; 3.4; $MUTED; 1.4)
      + text_at(450; 270; 17; $MUTED; "middle"; "아직 수집된 기간이 없습니다")
    end ) as $chartSvg

| ( if $m.periods.first == "" then "수집 전"
    else "\($m.periods.first) – \($m.periods.last)" end ) as $range
| ( if $m.lastCollectedAt == "" then "마지막 수집 없음"
    else "마지막 수집 \($m.lastCollectedAt)" end ) as $footer

| "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\($W)\" height=\"\($H)\" viewBox=\"0 0 \($W) \($H)\" role=\"img\" aria-label=\"수집 현황: 기간 \($m.periods.count)개, 일별 행 \($m.periods.rows), 기초지자체 \($m.periods.regions), 대기측정소 \($m.stations.count)\">"
  + "<rect x=\"0\" y=\"0\" width=\"\($W)\" height=\"\($H)\" fill=\"\($PAPER)\"/>"
  + text_at(44; 58; 30; $INK; "start"; "수집 현황")
  + text_at(856; 58; 16; $MUTED; "end"; $range)
  + $tileSvg
  + text_at(44; 214; 20; $INK; "start"; "수집된 월")
  + $chartSvg
  + text_at(44; $chartBottom + 34; 15; $MUTED; "start"; $footer)
  + "</svg>\n"
```

One cell per calendar month between the first and last stored period, filled when that period is on disk and left as an empty outline when it is not. The form follows the question: monthly row counts are `days x regions x 3` and therefore near-constant, so a bar chart of them compares three bars of the same length and says nothing. What a reader actually wants to know is how far back coverage runs and whether anything is missing, and only the strip can show a gap — a bar chart drops the missing month entirely and still looks healthy.

There is one series and no legend; the heading names it. Month and year sit under the cells in muted ink rather than in the accent colour, so identity never rests on colour alone.

- [ ] **Step 4: Wire the renderer into the script**

In `scripts/build-collection-stats.sh`, replace the final line `fail "rendering is not implemented yet"` with:

```bash
jq -r -f scripts/collection-stats.jq "$TMP_DIR/metrics.json" > "$TMP_DIR/out.svg" \
  || fail "could not render the stats image"

case "$mode" in
  check)
    [ -f "$out_file" ] || fail "missing generated artifact: $out_file"
    cmp -s "$TMP_DIR/out.svg" "$out_file" \
      || fail "$out_file is stale; run scripts/build-collection-stats.sh"
    printf 'collection stats up to date: %s\n' "$out_file"
    ;;
  render)
    mkdir -p "$(dirname "$out_file")"
    cp "$TMP_DIR/out.svg" "$out_file"
    printf 'wrote collection stats: %s\n' "$out_file"
    ;;
esac
```

- [ ] **Step 5: Run smoke to verify it passes**

Run: `./harness/scripts/smoke.sh`
Expected: PASS.

If the determinism assertion fails, the cause is a stray non-deterministic input, not a flaky test — diff the two files and trace the differing coordinate back to its `$k`.

- [ ] **Step 6: Look at the rendered image**

```bash
scripts/build-collection-stats.sh --snapshot-dir harness/fixtures/collection-stats --out /tmp/stats-preview.svg
open /tmp/stats-preview.svg
```

The validator in the dataviz skill checks colour, not layout. Confirm by eye: no month label collides with its neighbour, no text runs past x=856, the tile numbers are centred in their boxes, and the strokes read as drawn rather than as glitched. Adjust the layout constants if not; they are the only numbers that should need touching.

- [ ] **Step 7: Commit**

```bash
git add scripts/collection-stats.jq scripts/build-collection-stats.sh harness/scripts/smoke.sh
git commit -m "$(cat <<'EOF'
feat: render collection coverage as a deterministic sketch

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: The committed artifact and the README embed

**Files:**
- Create: `docs/collection-stats.svg` (generated)
- Modify: `README.md` (insert a section before line 19, `## Knowledge Layers`)
- Test: `harness/scripts/smoke.sh`

**Interfaces:**
- Consumes: `scripts/build-collection-stats.sh` and `--check` from Task 2.
- Produces: the committed artifact at its fixed path, which Task 4's workflow refreshes.

- [ ] **Step 1: Write the failing assertions in smoke**

Add to the `require_file` list, next to the other `scripts/` entries:

```bash
require_file scripts/build-collection-stats.sh
require_file scripts/collection-stats.jq
require_file docs/collection-stats.svg
require_file harness/scenarios/collection-stats-image.md
```

Add next to the other executable checks:

```bash
[ -x scripts/build-collection-stats.sh ] || fail "scripts/build-collection-stats.sh is not executable"
```

Append to the stats block:

```bash
grep -q 'docs/collection-stats.svg' README.md || fail "README.md does not embed the collection stats image"

# --check is the guard a human runs before committing a redraw. It is pinned
# here against a temporary file, never against docs/collection-stats.svg:
# wiki-batch.yml runs this suite on every push, and the stats workflow runs it
# before pushing, so asserting on the real artifact would turn a scheduling gap
# into a contract failure and deadlock the workflow against its own output.
cp "$TMP_DIR/stats-a.svg" "$TMP_DIR/stats-check.svg"
scripts/build-collection-stats.sh --check --snapshot-dir "$stats_fixtures" --out "$TMP_DIR/stats-check.svg" >/dev/null
printf '<!-- stale -->\n' >> "$TMP_DIR/stats-check.svg"
if scripts/build-collection-stats.sh --check --snapshot-dir "$stats_fixtures" --out "$TMP_DIR/stats-check.svg" >/dev/null 2>&1; then
  fail "--check accepted a stale collection stats image"
fi
```

- [ ] **Step 2: Run smoke to verify it fails**

Run: `./harness/scripts/smoke.sh`
Expected: FAIL with `FAIL: missing file: docs/collection-stats.svg`

- [ ] **Step 3: Generate the artifact**

```bash
scripts/build-collection-stats.sh
```

Against the current `main` this produces the empty state, because no visitor
period has been captured yet. That is the correct first version.

- [ ] **Step 4: Add the README section**

Insert immediately before `## Knowledge Layers` in `README.md`:

```markdown
## 수집 현황

![수집 현황](docs/collection-stats.svg)

`scripts/build-collection-stats.sh`가 `raw/external-snapshots/`를 읽어 매일 다시 그립니다. 숫자가 그대로인 날은 커밋하지 않으므로, 그림에 찍힌 날짜는 그린 날이 아니라 증거가 마지막으로 수집된 날입니다.
```

- [ ] **Step 5: Run smoke to verify it passes**

Run: `./harness/scripts/smoke.sh`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add docs/collection-stats.svg README.md harness/scripts/smoke.sh
git commit -m "$(cat <<'EOF'
feat: show collection coverage on the README

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: The refresh workflow and its rule

**Files:**
- Create: `.github/workflows/collection-stats.yml`
- Modify: `SCHEMA.md` (insert a new section between "Scheduled Collection Rules" and "Retrieval And Package Rules")
- Modify: `log.md` (append one entry)

**Interfaces:**
- Consumes: `scripts/build-collection-stats.sh` with no arguments, writing `docs/collection-stats.svg`.
- Produces: nothing later tasks depend on. This is the last task.

- [ ] **Step 1: Write the SCHEMA section**

Insert into `SCHEMA.md`, immediately before `## Retrieval And Package Rules`:

```markdown
## Generated Artifact Rules

A generated artifact is a file this repository writes about itself: derived
wholly from files already committed here, carrying no evidence of its own. Today
there is exactly one, `docs/collection-stats.svg`.

1. **It may be pushed to the default branch by a scheduled workflow.** This is
   the only exception to rule 8 of "Scheduled Collection Rules". The reason the
   review gate applies elsewhere is that a capture brings in something a human
   has not seen; a generated artifact brings in nothing, so a pull request would
   ask for a judgement that does not exist. The exception holds only while all
   of the following do: it calls no external API, reads no secret, and derives
   solely from committed files.
2. **Its path is fixed and single.** The refreshing workflow fails if any path
   other than that artifact is dirty after generation. A generator free to write
   anywhere is a generator that can quietly rewrite evidence.
3. **It is not evidence.** No canonical page and no record may cite it as a
   source. It summarises sources, and citing a summary launders provenance:
   the reader can no longer reach the thing that was actually captured.
4. **It must be a pure function of its inputs.** Nothing time-varying may reach
   the output — not the current date, not a random number, not a run identifier.
   Otherwise an unchanged input produces a changed file, the "commit only on a
   change" rule stops filtering anything, and the history fills with commits
   that say nothing. Any sketch or layout randomness must be seeded from the
   data itself.
5. **It is regenerated, never edited.** A hand edit is overwritten by the next
   run, so a change to the artifact means a change to its generator.
```

- [ ] **Step 2: Write the workflow**

`.github/workflows/collection-stats.yml`:

```yaml
name: Collection Stats Image

# Redraws docs/collection-stats.svg from evidence already committed here and
# pushes it to main when the picture changed.
#
# This is the only workflow that writes outside raw/ and pushes to the default
# branch. "Generated Artifact Rules" in SCHEMA.md defines that exception: no API
# call, no secret, nothing but committed files as input, so there is no
# judgement for a reviewer to make. The guards below are what keep it narrow.

on:
  schedule:
    # 05:00 KST daily. Offset from the other three crons so no two runs race.
    - cron: "0 20 * * *"
  push:
    branches:
      - main
    # Closes the window between merging a capture and the next daily run. The
    # artifact's own path is absent from this list, so the push this workflow
    # makes cannot retrigger it.
    paths:
      - "raw/external-snapshots/**"
      - "scripts/build-collection-stats.sh"
      - "scripts/collection-stats.jq"
  workflow_dispatch:

permissions:
  contents: write

concurrency:
  group: collection-stats
  cancel-in-progress: false

jobs:
  redraw:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Redraw the image
        run: scripts/build-collection-stats.sh

      - name: Detect a real change
        id: diff
        run: |
          # Rule 2: the generator owns exactly one path. Anything else moving
          # means something wrote where it should not have, and committing
          # would carry that with it.
          stray="$(git status --porcelain -- . ':(exclude)docs/collection-stats.svg')"
          if [ -n "$stray" ]; then
            echo "::error::the generator touched a path other than docs/collection-stats.svg"
            printf '%s\n' "$stray"
            exit 1
          fi

          # Rule 4: an unchanged input must produce an unchanged file. If this
          # branch stops being taken on quiet days, the generator has picked up
          # something time-varying.
          if [ -n "$(git status --porcelain docs/collection-stats.svg)" ]; then
            echo "changed=true" >> "$GITHUB_OUTPUT"
          else
            echo "::notice::the picture did not change; nothing to commit."
            echo "changed=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Verify the tree still satisfies the contract
        if: steps.diff.outputs.changed == 'true'
        run: ./harness/scripts/smoke.sh

      - name: Commit and push
        if: steps.diff.outputs.changed == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add docs/collection-stats.svg
          git commit -m "chore: redraw the collection stats image"
          git push
```

- [ ] **Step 3: Run smoke to verify the tree is still valid**

Run: `./harness/scripts/smoke.sh`
Expected: PASS. The `.yml` file is covered by the format check, so a missing final newline or a CRLF fails here.

- [ ] **Step 4: Append the log entry**

Read the current count first — the entry ends by restating it:

```bash
grep '^Active canonical pages:' index.md
```

Append to `log.md`, substituting that number for `<N>`:

```markdown
## 2026-08-17 - create - draw the collection coverage on the README

- Added: `scripts/build-collection-stats.sh` and `scripts/collection-stats.jq`, which read `raw/external-snapshots/` and render `docs/collection-stats.svg` — periods stored, daily rows, 기초지자체 covered in the latest period, and the air-quality station count. The README previously stated what the wiki intends to collect and nothing about what it holds.
- The renderer is a pure function of the metrics. Its hand-drawn wobble comes from a Lehmer generator seeded by a hash of those metrics, not from a random source, and the footer carries the newest `collectedAt` rather than the current date. Both follow from the refresh policy: the workflow runs daily and commits only when the picture changes, so any non-determinism would produce one meaningless commit per day.
- 기초지자체 coverage is counted in the newest period only. Unioning every period would report which regions have ever appeared, which is a more flattering number and a different claim.
- Added: `.github/workflows/collection-stats.yml`, which redraws daily, on a push to `main` under `raw/external-snapshots/`, and on demand. It fails if any path other than the artifact is dirty after generation, and pushes to `main` rather than opening a pull request.
- Added: `SCHEMA.md` "Generated Artifact Rules", which is what makes that push legal. Rule 8 of "Scheduled Collection Rules" exists because a capture brings in something no human has seen; this artifact brings in nothing of its own, so a pull request would ask for a judgement that does not exist. The new rules keep the exception narrow: one fixed path, no API, no secret, not citable as a source, and pure.
- `--check` is deliberately not wired into `harness/scripts/smoke.sh`. `wiki-batch.yml` runs smoke on every push and the stats workflow runs it before pushing, so asserting there would turn the interval between a merged capture and the next redraw into a contract failure, and would deadlock the workflow against its own output. The `push` trigger closes that interval instead.
- The first committed version renders the empty state, because no visitor period has been captured yet. That is the accurate picture.
- Canonical pages unchanged at <N>.
```

- [ ] **Step 5: Run smoke to verify the log grammar holds**

Run: `./harness/scripts/smoke.sh`
Expected: PASS. The heading must match `## YYYY-MM-DD - (ingest|create|update|archive|delete|lint|repair) - …` or smoke reports `log.md heading does not match SCHEMA format`.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/collection-stats.yml SCHEMA.md log.md
git commit -m "$(cat <<'EOF'
feat: redraw the collection stats image on a schedule

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Verification before calling this done

1. `./harness/scripts/smoke.sh` passes.
2. `scripts/build-collection-stats.sh --check` passes on a clean tree.
3. `scripts/build-collection-stats.sh` run twice leaves `git status` clean the second time.
4. The rendered SVG has been opened and looked at, in both a light and a dark viewer, with no label collisions and no text past the canvas.
5. `git log --oneline` shows four commits, one per task.

## Known follow-ups, deliberately not in this plan

- The image shows zeros until the regional visitor collector merges and captures a period. Nothing to fix; it will fill in.
- Embedding Excalifont as base64 would make the lettering identical on Linux. Rejected for now — it buries the text diff this format was chosen for. If it is ever wanted, it changes only `label` in `scripts/collection-stats.jq`.
- File size is dominated by hachure. Measured: 15 KB at 3 months, 44 KB at 15 months. The strip's cells shrink as the span grows, so this scales far better than the bars it replaced (44 KB at 3 bars), but past roughly 36 months switch the cells to a solid low-opacity fill with a hachured outline.
