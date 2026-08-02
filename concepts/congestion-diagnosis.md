---
title: Congestion Diagnosis
created: 2026-08-03
updated: 2026-08-03
type: concept
tags:
  - congestion
  - recommendation-policy
  - public-data
sources:
  - raw/hanjeok-design/design-v3.md
  - raw/harness/course-recommendation.md
confidence: medium
contested: true
contradictions: []
---

# Congestion Diagnosis

Congestion Diagnosis converts public congestion forecast data into a user-facing crowding grade for a selected attraction and visit time.

The Hanjeok design defines the primary input as attraction id, visit date, and time slot. The backend first checks whether the attraction has congestion coverage. If not, it returns a diagnosis-unavailable response and nearby diagnosable attractions as fallback.

## Grade Policy

The current design uses percentile-based grades:

- `RELAXED`: up to 50th percentile
- `NORMAL`: 50th to 75th percentile
- `CROWDED`: 75th to 90th percentile
- `VERY_CROWDED`: 90th percentile and above

This page is contested because the exact congestion API identifier and time granularity still require public API spike validation.

## Related Pages

- [[congestion-forecast-api]]
- [[alternative-scoring]]
- [[course-generation-policy]]

