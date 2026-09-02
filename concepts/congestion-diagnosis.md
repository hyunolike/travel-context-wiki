---
title: Congestion Diagnosis
created: 2026-08-03
updated: 2026-08-19
type: concept
tags:
  - congestion
  - recommendation-policy
  - public-data
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/service-snapshots/hanjeok/course-recommendation.md
  - raw/service-snapshots/hanjeok/api-contract-v4.md
confidence: high
contested: false
contradictions:
  - "design-v3 lists time slot as a primary input. api-contract-v4 deleted it because the public congestion API carries only a date field and no time axis. v4 supersedes v3."
---

# Congestion Diagnosis

Congestion Diagnosis converts public congestion forecast data into a user-facing crowding grade for a selected attraction and visit date.

The inputs are attraction id and visit date. **There is no time-of-day axis** — the public congestion API returns a date and no time field, so the slot parameter was deleted from the contract rather than left unimplemented. An explanation may not assert a time-of-day crowding claim; the data to support one does not exist.

## Grade Policy

Grades come from the **percentile**, not the raw concentration value:

- `RELAXED`: up to 50th percentile
- `NORMAL`: 50th to 75th percentile
- `CROWDED`: 75th to 90th percentile
- `VERY_CROWDED`: 90th percentile and above

The raw concentration is reported alongside the grade but is not the grade's input. Feeding concentration straight into the percentile cutoffs is a known implementation error the consumer service made once and corrected; an explanation that describes the grade as coming from the concentration value repeats it.

## No Coverage Is A Normal State, Not An Error

When an attraction has no forecast coverage the response is `hasCongestionData: false` with **HTTP 200 and success true**, carrying a message and a list of nearby diagnosable places instead of a diagnosis. Missing coverage is a product state, not a failure. An explanation layer must handle this branch: there is no grade, no percentile, and no better-date list to talk about, and inventing one is the exact failure this wiki exists to prevent.

## Related Pages

- [[congestion-forecast-api]]
- [[alternative-scoring]]
- [[course-generation-policy]]
