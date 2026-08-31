---
title: Course Generation Policy
created: 2026-08-03
updated: 2026-08-19
type: concept
tags:
  - course-generation
  - recommendation-policy
  - course-explanation
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/service-snapshots/hanjeok/course-recommendation.md
  - raw/service-snapshots/hanjeok/api-contract-v4.md
confidence: high
contested: false
contradictions:
  - "design-v3 places each attraction in the time slot where its congestion is lowest. api-contract-v4 removed the slot axis entirely and derives visit times from travel time. v4 supersedes v3 on this point."
  - "design-v3 describes greedy placement plus local swapping. api-contract-v4 replaced it with exhaustive search, and the swap step no longer exists as a concept."
---

# Course Generation Policy

Course Generation Policy fixes the original destination as the starting point and orders the selected alternatives so total travel time is smallest.

At most three alternatives may be selected, so the ordering is an exhaustive search over at most `3! = 6` permutations. It always finds the optimum; nothing is approximated. There is no separate reordering or swap step — the search replaced it.

## Visit Times Are Travel Time, Not Congestion

`timeLabel` on each course item is derived from **departure at 10:00, ninety minutes at each place, plus the measured travel time between them**, accumulated in visit order. It says nothing about when a place is least crowded.

This is the single most dangerous thing to get wrong in an explanation. Until v3 the label did mean "the quietest time in that slot", and an explanation written against that reading would claim a reason the backend never computed. **An explanation must not say a place was scheduled at a given hour because that hour is quieter.** The correct statement is that the order minimizes travel time and the clock follows from it.

The congestion grade still appears per item, because each place carries its own grade for the visit date. The grade explains *why the place is in the course*; it does not explain *what time it sits at*.

## Rule-Based Text Already Exists

`title`, `summary`, and each item's `reason` are Korean rule-based template strings produced by `CourseRoutePolicy` and `CourseTextPolicy`. No sentence in a course response comes from a language model today. That is the gap an explanation layer fills, and it is also the baseline any explanation should be compared against.

## Explanation Use

[[travel-context-layer]] can say that a crowded destination was kept but reordered rather than dropped, that the visit order minimizes travel time, and that the reported reduction rate compares the course against visiting the original destination alone.

## Related Pages

- [[congestion-diagnosis]]
- [[alternative-scoring]]
- [[why-this-place-today]]
