# Regional Visitor Count Collector Design

**Status:** approved design; Task 1 implemented, Task 3 revised after the endpoint contract was confirmed
**Date:** 2026-08-17
**Source dataset:** [한국관광공사_빅데이터_지역별 방문자수_GW](https://www.data.go.kr/data/15101972/openapi.do) (data.go.kr 15101972)

## Confirmed endpoint contract

Read out of `TourAPI_Guide_(관광빅데이터)v4.1.zip` on the dataset page, 2026-08-17. Four of this design's original assumptions were wrong; the corrections are recorded in "What the guide changed" below.

| Value | Confirmed |
|---|---|
| Endpoint | `http://apis.data.go.kr/B551011/DataLabService` |
| Operation (기초지자체) | `locgoRegnVisitrDDList` |
| Operation (광역, unused) | `metcoRegnVisitrDDList` |
| Service key parameter | `serviceKey`, URL-decoded form |
| Range parameters | `startYmd`, `endYmd`, both `yyyyMMdd` |
| Response format parameter | `_type=json` — leading underscore; the default is XML |
| Required, and missed by the first draft | `MobileOS=ETC`, `MobileApp=<app name>` |
| Paging | `numOfRows`, `pageNo` |
| Row array | `.response.body.items.item` |
| Period field | `baseYmd`, `yyyyMMdd` |
| Success code | `resultCode` is **`0000`** |
| Row fields | `signguCode`, `signguNm`, `daywkDivCd`, `daywkDivNm`, `touDivCd`, `touDivNm`, `touNum`, `baseYmd` |
| Publication | 갱신주기 일 1회 |

`touDivCd` splits every region-day three ways: `1` 현지인, `2` 외지인, `3` 외국인. One day returns roughly 740 rows.

### What the guide changed

1. **There is no monthly operation.** Both operations are `…DDList` and `baseYmd` is a date. The 기초지자체 unit this design chose is served only at daily granularity. Monthly figures would have to be aggregated by us, and aggregation is derivation, which `raw/` does not hold. **Resolution:** keep one file per `YYYY-MM` period and store that month's daily rows inside it, unaggregated. The period-file model and `scripts/collect-period-snapshot.sh` are unaffected.
2. **`resultCode` is `0000`, not `00`.** The air-quality collector's `00` check would have rejected every successful response here.
3. **Pagination is mandatory, not exceptional.** A month is roughly 22,000 rows. The air-quality collector fails when `totalCount` exceeds `numOfRows` because crossing that line there is rare; here it is the normal case. This collector pages through to completion and instead fails when the rows it assembled do not reconcile with `totalCount`.
4. **Volume is material.** At roughly 3 MB per month file, an 18-month backfill adds about 60 MB. Accepted deliberately: the evidence layer keeps the source's own granularity, and the alternative was aggregating in `raw/`.

## Goal

Capture monthly visitor counts per 기초지자체 as raw evidence, so that `records/congestion/grade-policy.json` — which today defines percentile grades (여유/보통/혼잡/매우혼잡) with no underlying distribution in the wiki — can eventually be grounded in observed data.

This design covers the collector, its first real capture, and the rule-1 decision document. Deriving `records/` from the captured evidence is deliberately out of scope: percentile grades only become meaningful once several periods have accumulated, so that work belongs after this one.

## Why the existing collector cannot be copied

`.github/workflows/collect-air-quality-stations.yml` captures a station list: a fixed reference set that rarely changes. This dataset is different in kind.

| | Air-quality stations | Regional visitor counts |
|---|---|---|
| Shape | fixed reference list (673 rows) | accumulating time series |
| Publication | effectively static | 갱신주기 일 1회, with a lag of roughly 4 days |
| Rows per fetch | 673, one page | ~740 per day, so ~22,000 per month; pagination required |
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

The third row is where this script diverges from `--skip-unchanged`, which overwrites on difference. Here a past period is contractually immutable, and a difference means the source restated history. That is rare enough to deserve a human decision, so the run stops rather than deciding on its own.

Secrets never reach this script. It reads a file that a workflow step has already built, and runs correctly with no secret present.

## Component: `.github/workflows/collect-regional-visitors.yml`

**Schedule:** `0 21 7 * *` — the 8th of each month at 06:00 KST. Monthly data publishes by the 4th, leaving four days of slack. This does not collide with the existing crons (`0 21 * * 1` for air quality, `0 18 * * 0` for wiki batch).

**Manual trigger:** `workflow_dispatch` with a `months` input (default 3) used for the initial backfill.

**One month per request, paginated.** The API takes a `startYmd`/`endYmd` date range and returns roughly 740 rows per day, so a month cannot arrive in one page. The workflow loops over the requested months; for each it requests that month's first through last day, pages until it has assembled `totalCount` rows, builds one envelope, and feeds it to `collect-period-snapshot.sh`. The scheduled run uses the default of 3: the newly published month is stored, and the two before it are re-fetched and checked for restatement. The backfill uses 18. Backfill and steady state share one code path.

Rows are stored exactly as returned, at daily granularity, with `touDivCd` still splitting each region-day into 현지인/외지인/외국인. Rolling them up to a monthly figure would be derivation, and `raw/` does not hold derived data.

**Secret:** the existing `DATA_GO_KR_SERVICE_KEY`, in its **URL-decoded** form. `--data-urlencode` encodes it, so storing the pre-encoded variant double-encodes it and the service rejects the key. data.go.kr issues one key per account; only a per-dataset 활용신청 is additionally required.

**Steps**, following the air-quality workflow's structure:

1. Guard on the secret; emit a notice and skip when absent.
2. For each month, fetch every page with `--data-urlencode`, never printing the URL, never `curl -v`. Send the required `MobileOS` and `MobileApp` parameters and `_type=json`.
3. Validate each page: it parses as JSON and `resultCode` is `0000` — fail without printing the body, since a rejected key can echo the request back. After the last page, fail unless the assembled row count equals `totalCount`, so a truncated month is never stored as complete.
4. Build one envelope per month and store it through `collect-period-snapshot.sh`.
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
| `resultCode` not `0000` | fail; do not print the body |
| Assembled rows do not equal `totalCount` | fail; a truncated month must not be stored as complete |
| Stored period differs from re-fetched period | fail, naming the period; a human decides whether to accept the restatement |
| Malformed or missing `period` | fail |

## Prerequisites before the collector can succeed

1. **활용신청 for dataset 15101972.** Done 2026-08-17 on a 개발계정. A development registration is auto-approved and capped at 10,000 calls a day, which is far above what a monthly run needs. Two consequences to track: a development key has a limited 활용기간 and must be renewed, and moving to a 운영계정 later requires 심의승인. `AGENTS.md` already lists 운영계정 전환 as a policy topic; when the key is renewed or promoted, the switch belongs in `log.md`.
2. **Confirm the endpoint contract.** Done 2026-08-17 by extracting `TourAPI_Guide_(관광빅데이터)v4.1.zip` from the dataset page; the values are in "Confirmed endpoint contract" above. The guide is dated 2026-02-25, so a single live call verifies it before the workflow is written — run outside this repository, since rule 3 forbids a secret-dependent script under `scripts/`. What that call must show: `resultCode` is `0000`, the row array sits at `.response.body.items.item`, `baseYmd` is `yyyyMMdd`, and `_type=json` actually returns JSON rather than XML.

**Until both are done the workflow takes the guard branch and reports success having collected nothing.** The air-quality collector sat in exactly that state for six days while its green run history suggested otherwise. A passing run is not evidence of a capture; a new file under `raw/external-snapshots/tourism-visitors/` is.

## Out of scope

- Rolling the daily rows up to a monthly figure. The API is daily-only, and aggregating before storage would put derived data in `raw/`. The rollup belongs in `records/` when someone needs it.
- Deriving `records/congestion/` percentile distributions. Needs accumulated periods; a distribution computed from one month would be a weak claim dressed as evidence.
- 광역 시도 aggregates. `records/regions/seoul-jongno.json` is a 기초지자체, so that is the unit the wiki needs.
- Live or near-live readings of any kind. Rule 1 puts those in the consumer backend.
