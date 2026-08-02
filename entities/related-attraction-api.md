---
title: Related Attraction API
created: 2026-08-03
updated: 2026-08-03
type: entity
tags:
  - openapi
  - public-data
  - recommendation-policy
sources:
  - raw/openapi-briefing/2026-openapi-briefing.txt
  - raw/hanjeok-design/design-v3.md
confidence: low
contested: true
contradictions: []
---

# Related Attraction API

The Related Attraction API provides attraction-to-attraction relationship information used to build alternative candidate sets.

Hanjeok uses it before distance filtering and congestion filtering in [[alternative-scoring]].

## Spike Requirements

- Verify whether the API returns a numeric relatedness score.
- Verify identifier compatibility with TourAPI and congestion records.
- Verify candidate volume for demo regions.

## Related Pages

- [[alternative-scoring]]
- [[tourapi-korservice2]]
- [[congestion-forecast-api]]

