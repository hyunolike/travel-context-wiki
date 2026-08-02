---
title: Raw Derived Data Separation
created: 2026-08-03
updated: 2026-08-03
type: concept
tags:
  - data-lineage
  - api-compliance
  - public-data
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/public-tourism-api/2026-openapi-briefing.txt
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

## Related Pages

- [[tourapi-korservice2]]
- [[congestion-forecast-api]]
- [[travel-context-layer]]
