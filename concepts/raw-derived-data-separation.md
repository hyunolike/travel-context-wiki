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
  - raw/hanjeok-design/design-v3.md
  - raw/openapi-briefing/2026-openapi-briefing.txt
confidence: high
contested: false
contradictions: []
---

# Raw Derived Data Separation

Raw Derived Data Separation keeps public API response data unchanged and stores service-specific calculations in separate derived records.

The OpenAPI briefing warns that modifying original tourism data can create responsibility for disputes and usage-verification issues. Hanjeok applies this by preserving `raw_*` tables and calculating grades, percentiles, locations, and scores into `derived_*` tables.

## Service Impact

- Public API response fields remain traceable.
- Grade thresholds can change without rewriting source data.
- LLM explanations can distinguish "provided by public API" from "calculated by Hanjeok".

## Related Pages

- [[tourapi-korservice2]]
- [[congestion-forecast-api]]
- [[evidence-backed-course-explanation]]

