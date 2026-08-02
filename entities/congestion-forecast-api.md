---
title: Congestion Forecast API
created: 2026-08-03
updated: 2026-08-03
type: entity
tags:
  - congestion
  - openapi
  - public-data
sources:
  - raw/public-tourism-api/2026-openapi-briefing.txt
  - raw/service-snapshots/hanjeok/design-v3.md
confidence: low
contested: true
contradictions: []
---

# Congestion Forecast API

The Congestion Forecast API provides visitor concentration trend prediction information for tourist attractions.

Travel services can use this API as the source for [[congestion-diagnosis]]. The first consumer snapshot records an important coverage risk: the briefing lists 10,731 congestion records, far fewer than the full Korean tourism information service.

## Spike Requirements

- Verify whether the congestion identifier equals TourAPI `contentId`.
- Verify whether the 10,731 count means attractions or attraction-time records.
- Verify whether the API includes time-slot granularity.

## Related Pages

- [[tourapi-korservice2]]
- [[congestion-diagnosis]]
- [[raw-derived-data-separation]]
