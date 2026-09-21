---
title: KMA Short-Term Forecast API
created: 2026-09-22
updated: 2026-09-22
type: entity
tags:
  - weather
  - openapi
  - public-data
  - weather-aware-recommendation
sources:
  - raw/weather-api/kma-vilage-fcst-guide-260623.txt
confidence: medium
contested: false
contradictions: []
---

# KMA Short-Term Forecast API

The Korea Meteorological Administration's 단기예보 조회서비스 (`VilageFcstInfoService_2.0`, dataset 15084084 on data.go.kr) returns forecasts on a 5 km grid. It is the weather source this wiki's weather rules are written against. The provider's guide, dated 2026-06-23, is stored under `raw/weather-api/`, both as the original `.docx` and as a text conversion.

This repository keeps the contract, not the weather. A forecast is live data. Only a consumer backend should fetch it for a trip, and the manual `capture-weather-forecast-sample` workflow exists only to record what one response looks like.

## Operations

| Operation | What it returns |
| --- | --- |
| `getUltraSrtNcst` | Observed conditions for the current hour. |
| `getUltraSrtFcst` | Ultra-short forecast, issued every hour at 30 minutes past. |
| `getVilageFcst` | Short-term forecast. The one a trip-day explanation would use. |
| `getFcstVersion` | Forecast version information. |

Requests take `base_date`, `base_time`, and the grid point `nx`, `ny`. The grid is not latitude and longitude: 서울특별시 종로구 is `60`, `127` in the provider's grid workbook. The response format defaults to XML unless `dataType=JSON` is passed.

## When A Forecast Exists

`getVilageFcst` is issued eight times a day, at `0200`, `0500`, `0800`, `1100`, `1400`, `1700`, `2000`, and `2300` KST, and each one is served from ten minutes past the hour. ^[raw/weather-api/kma-vilage-fcst-guide-260623.txt] A caller has to pick the latest base time already served; the guide lists `03` no data among its result codes, and the sample workflow picks one at least fifteen minutes old.

Since the extension of 2024-11-28, a forecast issued at 02 to 14시 reaches 글피, and one issued at 17 to 23시 reaches 그글피. The extended days are three-hourly, and on them `PCP`, `SNO`, and `WSD` arrive as qualitative codes `1` to `3` instead of amounts. ^[raw/weather-api/kma-vilage-fcst-guide-260623.txt] The same category therefore changes type within one response depending on how far ahead the row is.

## Categories A Travel Explanation Would Touch

| Category | Meaning | Values |
| --- | --- | --- |
| `SKY` | 하늘상태 | `1` 맑음, `3` 구름많음, `4` 흐림 |
| `PTY` | 강수형태 | `0` 없음, `1` 비, `2` 비/눈, `3` 눈, `4` 소나기 |
| `POP` | 강수확률 | Percent. |
| `PCP` | 1시간 강수량 | A string such as `1mm 미만` or `6.2mm`, not a number. `-`, null, and `0` all mean no rain. |
| `TMP` | 1시간 기온 | °C. |
| `TMN`, `TMX` | 일 최저, 최고기온 | °C. |

`PTY` has a longer code list in the ultra-short services, where `5` to `7` add 빗방울 and 눈날림. Those codes never appear in `getVilageFcst`, so a mapping written against one service silently drops values from the other. Over the sea, temperature, precipitation probability, precipitation, and humidity are masked as missing.

## Result Codes

`resultCode` `00` is success. The failures worth distinguishing are `03` no data, `22` daily request limit exceeded, `30` key not registered, and `31` key expired. These arrive inside the response body, so a caller has to check `resultCode` and cannot rely on the HTTP status alone.

## What The Source Does Not Define

The forecast gives temperatures, not heat risk. Nothing in the guide says at what `TMX` a day becomes a heat-risk day, and nothing here says when an outdoor visit becomes unsuitable. `records/weather/rules.json` names both gaps in `unsourcedFacts` so that nobody fills them with a threshold nobody sourced.

## Related Pages

- [[weather-aware-travel-recommendation]]
- [[air-quality-station-api]]
- [[keep-llm-out-of-ranking]]
