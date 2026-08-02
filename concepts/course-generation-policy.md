---
title: Course Generation Policy
created: 2026-08-03
updated: 2026-08-03
type: concept
tags:
  - course-generation
  - recommendation-policy
  - course-explanation
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/service-snapshots/hanjeok/course-recommendation.md
confidence: medium
contested: true
contradictions: []
---

# Course Generation Policy

Course Generation Policy arranges the original destination and selected alternatives into visit slots.

The MVP policy is intentionally simple: assign each place to the time slot where its congestion profile is lowest, then adjust nearby slots when movement distance is too high.

## Why Not Full Optimization

The initial consumer-service design avoids TSP-style optimization for MVP because the course has roughly four slots. Greedy placement plus local swapping is easier to explain and verify.

## Explanation Use

[[travel-context-layer]] can say that a crowded destination was delayed instead of removed, that a quieter alternative was placed earlier, or that [[weather-aware-travel-recommendation]] changed the explanation for indoor/outdoor suitability.

## Related Pages

- [[congestion-diagnosis]]
- [[alternative-scoring]]
- [[why-this-place-today]]
