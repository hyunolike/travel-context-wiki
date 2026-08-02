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
  - raw/hanjeok-design/design-v3.md
  - raw/harness/course-recommendation.md
confidence: medium
contested: true
contradictions: []
---

# Course Generation Policy

Course Generation Policy arranges the original destination and selected alternatives into visit slots.

The MVP policy is intentionally simple: assign each place to the time slot where its congestion profile is lowest, then adjust nearby slots when movement distance is too high.

## Why Not Full Optimization

The Hanjeok design avoids TSP-style optimization for MVP because the course has roughly four slots. Greedy placement plus local swapping is easier to explain and verify.

## Explanation Use

[[evidence-backed-course-explanation]] can say that a crowded destination was delayed instead of removed, or that a quieter alternative was placed earlier because its predicted congestion was lower in that slot.

## Related Pages

- [[congestion-diagnosis]]
- [[alternative-scoring]]
- [[why-this-course]]

