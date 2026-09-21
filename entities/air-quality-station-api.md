---
title: Air Quality Station API
created: 2026-09-21
updated: 2026-09-21
type: entity
tags:
  - weather
  - openapi
  - public-data
  - data-lineage
sources:
  - raw/external-snapshots/air-quality-airkorea-station-list.json
confidence: medium
contested: true
contradictions: []
---

# Air Quality Station API

AirKorea's station information service lists the monitoring stations that measure air pollution in Korea. The `collect-air-quality-stations` workflow captures it weekly into `raw/external-snapshots/air-quality-airkorea-station-list.json`, with `sourceKind: air-quality`. The file is replaced only when the list changes.

It is a reference list of places, not measurements. Readings change hourly, and live readings belong in a consumer backend, not in this repository. So nothing here can say whether the air is good today.

## What The Capture Holds

The 2026-09-14 capture lists 672 stations. ^[raw/external-snapshots/air-quality-airkorea-station-list.json]

| Network (`mangName`) | Stations |
| --- | --- |
| 도시대기 | 532 |
| 도로변대기 | 68 |
| 항만 | 34 |
| 교외대기 | 27 |
| 국가배경농도(도서) | 11 |

Every station lists `PM2.5` among the pollutants it measures in `item`, and every station has coordinates.

## Traps In The Fields

- **`dmX` is latitude and `dmY` is longitude.** 퇴계동 in 춘천 has `dmX` `37.84` and `dmY` `127.74`. Reading X as longitude puts every station in the wrong place.
- **The station list has no district code.** It cannot be joined to [[regional-visitor-api]] on `signguCode`. The only routes are the coordinates or the free-text `addr`.
- **`addr` is not normalised.** The same province appears as `경기` and `경기도`, `서울` and `서울특별시`, `인천` and `인천광역시`, and South Jeolla and Gwangju addresses appear under `전남광주통합특별시`. Grouping by the first word of `addr` splits one province into several.

## Open Question: The License

The capture records the license as 공공누리 제3유형, attribution plus no modification. Storing the list byte for byte in `raw/` is within that. Whether a normalised derived record, such as a cleaned address or a district assignment, counts as a modification has not been checked. Until it is, no record under `records/` should derive from this list. This is why the page is marked contested.

## Consumer Status

No consumer uses this list. [[weather-aware-travel-recommendation]] is where air quality would belong as an outdoor-suitability fact, and that page has no producing service either.

## Related Pages

- [[weather-aware-travel-recommendation]]
- [[regional-visitor-api]]
- [[raw-derived-data-separation]]
