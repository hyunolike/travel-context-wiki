---
title: Raw Derived Data Separation
created: 2026-08-03
updated: 2026-09-22
type: concept
tags:
  - data-lineage
  - api-compliance
  - public-data
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/public-tourism-api/2026-openapi-briefing.txt
  - raw/external-snapshots/air-quality-airkorea-station-list.json
  - raw/external-snapshots/tourism-visitors/2026-07.json
confidence: high
contested: false
contradictions: []
---

# Raw Derived Data Separation

Raw Derived Data Separation keeps public API response data unchanged and stores service-specific calculations in separate derived records.

The OpenAPI briefing warns that modifying original tourism data can create responsibility for disputes and usage-verification issues. Consumer services should preserve `raw_*` records and calculate grades, percentiles, locations, weather interpretations, and scores into `derived_*` records.

## Service Impact

- Public API response fields remain traceable.
- Grade thresholds can change without rewriting source data.
- LLM explanations can distinguish "provided by public API" from "calculated by the consuming service".

## In This Repository

The same line holds for the evidence this wiki collects. The regional visitor collector stores daily rows as the source returns them and never aggregates a month before storage, because a monthly total would be derived data sitting in `raw/`. ^[raw/external-snapshots/tourism-visitors/2026-07.json]

For the air-quality station list the separation is also a license question. It is published under 공공누리 제3유형, which prohibits modification, so a cleaned or re-keyed copy may not be allowed at all. [[air-quality-station-api]] records this as unresolved. ^[raw/external-snapshots/air-quality-airkorea-station-list.json]

## Related Pages

- [[tourapi-korservice2]]
- [[congestion-forecast-api]]
- [[travel-context-layer]]
- [[regional-visitor-api]]
- [[air-quality-station-api]]
