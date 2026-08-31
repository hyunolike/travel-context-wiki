---
title: Why This Place Today
created: 2026-08-03
updated: 2026-08-19
type: query
tags:
  - course-explanation
  - llm-rag
  - recommendation-policy
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/service-snapshots/hanjeok/course-recommendation.md
  - raw/service-snapshots/hanjeok/api-contract-v4.md
confidence: high
contested: false
contradictions: []
---

# Why This Place Today

This query template explains why a travel service recommended a place and an order for a specific date, using only the facts the service backend returns.

## Required Inputs

Five facts. They do not arrive in one payload — the course response carries the visit date and the items, while the destination, the diagnosis, and the alternatives come from their own endpoints. Every response is wrapped in `{ success, data, error }` and the facts live under `data`.

| Fact | Source endpoint |
| --- | --- |
| `destination` | `GET /attractions/{id}` |
| `visitDate` | `targetDate` on `GET /courses/{uuid}` |
| `congestionDiagnosis` | `GET /attractions/{id}/congestion?date=` |
| `alternatives` | `GET /attractions/{id}/alternatives?date=&radius=` |
| `courseItems` | `items` on `GET /courses/{uuid}` |

A field absent from these is a field the explanation may not assert. `harness/fixtures/course-explanation-request.json` holds a worked example of all four responses.

## Answer Policy

The answer should:

- summarize the destination's congestion diagnosis using [[congestion-diagnosis]], in percentile terms
- mention that alternatives were ranked by [[alternative-scoring]], and that only quiet candidates are offered
- explain the returned visit order using [[course-generation-policy]] — it minimizes travel time from a fixed start
- state what the reduction rate compares against: the course versus visiting the destination alone
- avoid claiming that the LLM selected or ordered anything

The answer must not:

- say the crowded destination was moved later; it is always the first visit
- give a time-of-day reason for a visit time; the times come from travel time
- assert a weather condition, because no consumer service supplies one
- assert a requested time slot, because the contract has no time axis

When `hasCongestionData` is false there is no grade, percentile, or better-date list. The answer explains that coverage is missing and that nearby diagnosable places were offered instead.

## Related Pages

- [[travel-context-layer]]
- [[congestion-diagnosis]]
- [[keep-llm-out-of-ranking]]
- [[course-generation-policy]]
