---
title: Alternative Scoring
created: 2026-08-03
updated: 2026-08-03
type: concept
tags:
  - recommendation-policy
  - fallback-policy
  - congestion
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/service-snapshots/hanjeok/course-recommendation.md
  - raw/service-snapshots/hanjeok/attractions.fixture.json
confidence: medium
contested: true
contradictions: []
---

# Alternative Scoring

Alternative Scoring ranks related attractions when the original destination is crowded.

The initial consumer-service policy combines:

- relatedness from [[related-attraction-api]]
- low congestion from [[congestion-diagnosis]]
- distance from the original attraction

The initial design formula is:

```text
score = w1 * relatedness + w2 * quietness + w3 * distance_score
```

If the related-attraction API does not provide a numeric relatedness score, a consumer service may replace `w1` with a binary "is related" weight or remove the term.

## Runtime Boundary

The backend owns this score. [[travel-context-layer]] may explain the resulting score factors, but it must not recalculate or override the ranked list.

## Related Pages

- [[congestion-diagnosis]]
- [[related-attraction-api]]
- [[keep-llm-out-of-ranking]]
