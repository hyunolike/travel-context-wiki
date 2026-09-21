---
title: Congestion Forecast API
created: 2026-08-03
updated: 2026-09-22
type: entity
tags:
  - congestion
  - openapi
  - public-data
sources:
  - raw/public-tourism-api/2026-openapi-briefing.txt
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/service-snapshots/hanjeok/api-contract-v4.md
confidence: low
contested: true
contradictions: []
---

# Congestion Forecast API

The Congestion Forecast API provides visitor concentration trend prediction information for tourist attractions.

Travel services can use this API as the source for [[congestion-diagnosis]]. The first consumer snapshot records an important coverage risk: the briefing lists 10,731 congestion records, far fewer than the full Korean tourism information service.

## Resolved: There Is No Time-Of-Day Axis

The first-week spike found that the response carries a date (`baseYmd`) and no time field. The consumer contract deleted every time-slot field in v4 as a result, rather than leaving them unimplemented. ^[raw/service-snapshots/hanjeok/api-contract-v4.md] [[congestion-diagnosis]] carries the consequence for explanations.

## Still Open

- Whether the congestion identifier equals TourAPI `contentId`.
- Whether the 10,731 count means attractions or attraction-date records. The consumer's design lists this as spike item B3, and nothing captured here has answered it. ^[raw/service-snapshots/hanjeok/design-v3.md]

## Related Pages

- [[tourapi-korservice2]]
- [[congestion-diagnosis]]
- [[raw-derived-data-separation]]
- [[regional-visitor-api]]
