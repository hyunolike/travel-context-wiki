# Regional Visitor Count Collector Design

**Status:** approved design, not yet implemented
**Date:** 2026-08-17
**Source dataset:** [한국관광공사_빅데이터_지역별 방문자수_GW](https://www.data.go.kr/data/15101972/openapi.do) (data.go.kr 15101972)

## Goal

Capture monthly visitor counts per 기초지자체 as raw evidence, so that `records/congestion/grade-policy.json` — which today defines percentile grades (여유/보통/혼잡/매우혼잡) with no underlying distribution in the wiki — can eventually be grounded in observed data.

This design covers the collector, its first real capture, and the rule-1 decision document. Deriving `records/` from the captured evidence is deliberately out of scope: percentile grades only become meaningful once several periods have accumulated, so that work belongs after this one.

## Why the existing collector cannot be copied

`.github/workflows/collect-air-quality-stations.yml` captures a station list: a fixed reference set that rarely changes. This dataset is different in kind.

| | Air-quality stations | Regional visitor counts |
|---|---|---|
| Shape | fixed reference list (673 rows) | accumulating time series |
| Publication | effectively static | monthly data by the 4th of the following month; daily data with a 4-day lag |
| Query limit | none | monthly queries span at most 18 months from the start date |
| Licence | 공공누리 제3유형 (변경금지) | 이용허락범위 제한 없음 |

`scripts/collect-external-snapshot.sh` stores one file per `snapshotId` and overwrites it with the newest payload. Applied to a time series that model fails three ways:

1. A new period appears every month, so the payload always differs and every scheduled run opens a pull request. Rule 5 is satisfied in the letter and defeated in spirit.
2. Fetching a rolling 18-month window and overwriting means data older than the window silently disappears from the evidence layer.
3. Telecom-derived statistics are restated after the fact. Overwriting destroys the original reading with no record that it changed.

The licence, by contrast, is a clear improvement. Unlike the air-quality snapshot — KOGL type 3, which forbids distributing a modified version and has left that capture sitting without a citing record — this dataset carries no usage restriction, so derivation into `records/` is unblocked.

## Storage model: one file per period

```
raw/external-snapshots/tourism-visitors/2026-06.json
raw/external-snapshots/tourism-visitors/2026-07.json
```

The envelope keeps the existing shape and adds `period`:

```json
{
  "snapshotId": "kto-regional-visitors-2026-07",
  "sourceKind": "tourism-visitors",
  "period": "2026-07",
  "sourceUrl": "https://www.data.go.kr/data/15101972/openapi.do",
  "license": "이용허락범위 제한 없음",
  "collectedAt": "2026-09-08T21:00:00Z",
  "payload": { }
}
```

Existing files are never rewritten by a scheduled run. `raw/` is refreshed by adding a new snapshot rather than editing an old one, and here that operating principle holds at file granularity. Each pull request adds exactly one file per new period, so review stays human-sized: twelve files a year.

### Array order must be normalised, not preserved

Rule 6 of "Scheduled Collection Rules" says collectors handling time series must not pass `--sort-arrays`, because order carries meaning in a sequence. That reasoning does not reach this design.

Once periods are split across files, the time axis lives in the filename. What remains inside a file is the set of regions observed in that month, and a set has no meaningful order. Preserving arrival order there would reproduce exactly the failure the air-quality collector hit: the server reorders rows, an unchanged payload compares as changed, and — under the failure behaviour below — a reordering would be misread as a restatement and halt the run.

So the period file is stored normalised: object keys sorted, arrays in canonical order. Rule 6 is honoured by splitting the series into files, not by preserving order within one.

## Component: `scripts/collect-period-snapshot.sh`

A new script. `scripts/collect-external-snapshot.sh` is left untouched, because the air-quality collector depends on its current contract and there is no reason to put that at risk.

```
scripts/collect-period-snapshot.sh <envelope-json> <output-dir>
```

Requires `period` matching `YYYY-MM` in addition to the fields the existing script requires (`snapshotId`, `sourceKind`, `sourceUrl`, `license`, `collectedAt`, and a `payload` object). Writes `<output-dir>/<period>.json`.

| Condition | Behaviour | Exit |
|---|---|---|
| Target file absent | write the normalised envelope | 0 |
| Target file present, payload identical after normalisation | leave the file untouched | 0 |
| Target file present, payload differs | fail, naming the period | 1 |
| `period` missing or not `YYYY-MM` | fail | 1 |
| Envelope invalid or missing required metadata | fail | 1 |

The third row is where this script diverges from `--skip-unchanged`, which overwrites on difference. Here a past period is contractually immutable, and a difference means the source restated history. That is rare enough to deserve a human decision, so the run stops rather than deciding on its own — the same reasoning behind the air-quality collector failing instead of paginating when `totalCount` exceeds `numOfRows`.

Secrets never reach this script. It reads a file that a workflow step has already built, and runs correctly with no secret present.

## Component: `.github/workflows/collect-regional-visitors.yml`

**Schedule:** `0 21 7 * *` — the 8th of each month at 06:00 KST. Monthly data publishes by the 4th, leaving four days of slack. This does not collide with the existing crons (`0 21 * * 1` for air quality, `0 18 * * 0` for wiki batch).

**Manual trigger:** `workflow_dispatch` with a `months` input (default 3) used for the initial backfill.

**One query, many files.** Each run requests a span of `months` ending at the most recently published month, in a single call, then splits the response by period and feeds each period through `collect-period-snapshot.sh`. The scheduled run uses the default of 3: the newly published month is stored, and the two before it are re-fetched and checked for restatement. The backfill uses 18, which is exactly the API's monthly query span, and produces up to eighteen files from one call. Backfill and steady state share one code path.

**Secret:** the existing `DATA_GO_KR_SERVICE_KEY`. data.go.kr issues one key per account; only a per-dataset 활용신청 is additionally required.

**Steps**, following the air-quality workflow's structure:

1. Guard on the secret; emit a notice and skip when absent.
2. Fetch with `--data-urlencode`, never printing the URL, never `curl -v`.
3. Validate: response parses as JSON, `resultCode` is `00`, and `totalCount` does not exceed `numOfRows` — fail without printing the body, since a rejected key can echo the request back.
4. Split by period and store each through `collect-period-snapshot.sh`.
5. Detect a real change with `git status --porcelain` on the snapshot directory.
6. On change, run `./harness/scripts/smoke.sh`.
7. On change, open a pull request against `main`. Never push to the default branch.

`scripts/build-index.sh` is not run, for the same reason it was removed from the air-quality workflow: it reads canonical pages, `records/`, and `packages/` only, so a capture under `raw/` cannot move any index artifact.

The pull request body states that no checks will appear on it, because a pull request opened with `GITHUB_TOKEN` does not trigger other workflows.

## Component: the rule-1 decision document

`decisions/aggregate-mobility-is-not-user-location.md`.

Rule 1 of "Scheduled Collection Rules" forbids responses describing "user identity, user location, user history". This dataset is derived from KT (내국인) and SKT (외국인) mobile location data, so a reader will stop on it. The decision records that the response describes a *place* — a 시군구 and a count of visitors to it — and contains no individual, and that it therefore passes rule 1.

The document states the boundary explicitly so the exception does not spread: region-level aggregates are permitted; individual-level records, trajectories, and raw location traces remain forbidden regardless of source.

`decisions/` is a canonical location, so per AGENTS.md this change must also update `index.md` and `log.md`. Active canonical pages go from 13 to 14.

## Testing

Five assertions added to `harness/scripts/smoke.sh`, with fixtures under `harness/fixtures/`:

1. A period with no existing file is written.
2. Re-running the same period with an identical payload leaves the file byte-identical.
3. Re-running the same period with a materially different payload exits non-zero and names the period.
4. An envelope whose `period` is missing or malformed is rejected.
5. A payload differing only in array order leaves the file byte-identical — pinning the normalisation, and guarding assertion 3 against false positives.

Assertions 3 and 5 are the pair that matters: together they say the script halts on a real restatement and stays quiet on a cosmetic reordering.

## Error handling summary

| Failure | Response |
|---|---|
| Secret absent | skip with a notice; the run reports success having done nothing |
| `resultCode` not `00` | fail; do not print the body |
| `totalCount` exceeds `numOfRows` | fail; a truncated capture must not be stored as complete |
| Stored period differs from re-fetched period | fail, naming the period; a human decides whether to accept the restatement |
| Malformed or missing `period` | fail |

## Prerequisites before the collector can succeed

Both are human work outside this repository, and neither is optional.

1. **활용신청 for dataset 15101972.** The operational stage is 심의승인, not automatic approval, so this takes time.
2. **Confirm the endpoint contract.** Operation names and request parameters for this service are published only inside `TourAPI_Guide_(관광빅데이터)v4.1.zip` on the dataset page; they are not in any public index, and this design deliberately does not guess them. Download the guide, then verify with a throwaway script outside this repository — rule 3 forbids a secret-dependent script under `scripts/`.

   Acceptance criteria for that verification, recorded in the workflow header once confirmed: the exact endpoint path; the operation name for 기초지자체 monthly visitor counts; the parameter names for the service key, period range, page number, and row count; the response format parameter and its correct spelling; and the observed `totalCount` for one known month. The air-quality collector's licence label was recorded from memory and turned out wrong, so each of these is confirmed against the source rather than assumed.

**Until both are done the workflow takes the guard branch and reports success having collected nothing.** The air-quality collector sat in exactly that state for six days while its green run history suggested otherwise. A passing run is not evidence of a capture; a new file under `raw/external-snapshots/tourism-visitors/` is.

## Out of scope

- Daily-granularity visitor counts. Roughly thirty times the volume, and monthly is sufficient for a percentile distribution.
- Deriving `records/congestion/` percentile distributions. Needs accumulated periods; a distribution computed from one month would be a weak claim dressed as evidence.
- 광역 시도 aggregates. `records/regions/seoul-jongno.json` is a 기초지자체, so that is the unit the wiki needs.
- Live or near-live readings of any kind. Rule 1 puts those in the consumer backend.
