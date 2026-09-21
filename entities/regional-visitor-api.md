---
title: Regional Visitor API
created: 2026-09-21
updated: 2026-09-21
type: entity
tags:
  - congestion
  - openapi
  - public-data
  - data-lineage
sources:
  - raw/external-snapshots/tourism-visitors/2026-06.json
  - raw/external-snapshots/tourism-visitors/2026-07.json
confidence: medium
contested: false
contradictions: []
---

# Regional Visitor API

The Korea Tourism Organization's DataLab regional visitor service reports a daily visitor figure for every 기초지자체, split three ways by visitor type. The `collect-regional-visitors` workflow captures it one file per month under `raw/external-snapshots/tourism-visitors/`, with `sourceKind: tourism-visitors`.

It was collected so that [[congestion-diagnosis]] could eventually rest on an observed distribution instead of an unsourced percentile scale. It cannot do that directly: congestion is diagnosed per attraction, and this series stops at the district.

## Row Shape

One row is one district, one day, one visitor type. ^[raw/external-snapshots/tourism-visitors/2026-07.json]

| Field | Meaning |
| --- | --- |
| `baseYmd` | Day, `YYYYMMDD`. |
| `daywkDivCd`, `daywkDivNm` | Weekday code and name. |
| `signguCode`, `signguNm` | District code and name. |
| `touDivCd`, `touDivNm` | `1` 현지인(a), `2` 외지인(b), `3` 외국인(c). |
| `touNum` | Visitor figure, as a decimal string. |

`touNum` carries fractions such as `186126.5`, so it is a modelled estimate, not a head count. The captures do not say how it is estimated. An explanation may compare districts or days with it, but must not present it as the number of people who came.

## Coverage Captured

| Period | Rows | Districts | Days |
| --- | --- | --- | --- |
| 2026-06 | 24,120 | 268 | 30 |
| 2026-07 | 25,017 | 270 | 31 |

The source publishes a month about 29 days after it ends, so the newest month is always partial when the collector runs. Partial months are not stored.

## Join On The Code, Never The Name

`signguNm` is not unique. In June, `중구` is six different districts (`11140`, `26110`, `27110`, `28110`, `30140`, `31110`), and `고성군` is two (`48820`, `51820`). A join or a lookup by name silently merges them.

## District Codes Changed On 2026-07-01

The code set is not stable across periods. Between June and July, 29 codes disappear and 31 appear: ^[raw/external-snapshots/tourism-visitors/2026-06.json] ^[raw/external-snapshots/tourism-visitors/2026-07.json]

- **Gwangju and South Jeolla.** All 5 Gwangju (`29xxx`) and 22 South Jeolla (`46xxx`) codes are replaced by 27 codes under a new `12` prefix. Names carry over, for example `46110` 목포시 becomes `12110` 목포시 and `29200` 광산구 becomes `12330` 광산구.
- **Incheon.** `28110` 중구 and `28140` 동구 disappear, and `28125` 제물포구 and `28155` 영종구 appear. `28260` 서구 appears in July only for 07-01 to 07-05, beside the new `28275` 서해구 and `28290` 검단구, which cover the whole month.

Two consequences follow for anything built on this series.

1. A series keyed on `signguCode` breaks at the month boundary. The Gwangju and South Jeolla codes map one to one by name within the old prefix, but the Incheon reorganisation redrew boundaries, so no code-to-code mapping for it is supported by the captures.
2. The completeness rule for stored periods counts distinct days across the whole month, not per district. July was admitted as complete while `28260` carried 5 of 31 days. A per-district series must check its own coverage.

## Related Pages

- [[congestion-diagnosis]]
- [[congestion-forecast-api]]
- [[air-quality-station-api]]
- [[raw-derived-data-separation]]
