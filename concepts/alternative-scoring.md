---
title: Alternative Scoring
created: 2026-08-03
updated: 2026-08-19
type: concept
tags:
  - recommendation-policy
  - fallback-policy
  - congestion
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/service-snapshots/hanjeok/course-recommendation.md
  - raw/service-snapshots/hanjeok/attractions.fixture.json
  - raw/service-snapshots/hanjeok/api-contract-v4.md
confidence: high
contested: false
contradictions: []
---

# Alternative Scoring

Alternative Scoring ranks related attractions when the original destination is crowded, combining relatedness, quietness, and distance into one number.

The consumer service's concrete formula is:

```text
score = 0.4 * relationScore
      + 0.4 * (1 - concentration / 100)
      + 0.2 * (1 - min(distanceKm, 15) / 15)
```

Results are returned sorted by `score` descending.

**The weights 0.4 / 0.4 / 0.2 are provisional.** They were chosen without supporting data and are expected to move once real usage exists. An explanation may say which factors the score combines; it should not present the weights as a tuned or validated result.

If the related-attraction API does not supply a numeric relatedness score, a consumer service may substitute a binary "is related" weight.

## Only Quiet Candidates Are Returned

The list contains **`RELAXED` and `NORMAL` grades only** — `CROWDED` and `VERY_CROWDED` never appear, and candidates with no congestion coverage are excluded before scoring. This is a filter applied before ranking, not a consequence of the score.

Two things follow for an explanation. It may not describe a returned alternative as busy, because a busy one cannot be in the list. And an empty list means no quiet, covered, related candidate existed — not that the scoring rejected them.

## Two Text Fields, Two Screens

Each alternative carries both a `summary` (what the place is) and a `recommendReason` (why it suits this date). They serve different screens and must not be merged or treated as interchangeable.

## Runtime Boundary

The backend owns this score. [[travel-context-layer]] may explain the resulting score factors, but it must not recalculate or override the ranked list.

## Related Pages

- [[congestion-diagnosis]]
- [[related-attraction-api]]
- [[keep-llm-out-of-ranking]]
