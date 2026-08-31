---
title: Travel Context Layer
created: 2026-08-03
updated: 2026-08-19
type: concept
tags:
  - travel-context
  - course-explanation
  - llm-rag
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/service-snapshots/hanjeok/api-contract-v4.md
  - raw/public-tourism-api/2026-openapi-briefing.txt
confidence: high
contested: false
contradictions:
  - "design-v3 lists time slot and weather context as runtime inputs. api-contract-v4 deleted the slot axis and no consumer service produces weather facts. v4 supersedes v3."
---

# Travel Context Layer

Travel Context Layer is the service pattern where a travel service backend makes deterministic recommendations and the LLM wiki explains those recommendations using preserved tourism, congestion, seasonality, and regional-context evidence.

The LLM wiki must not change ranking results. Ranking belongs to the consuming service's backend. The wiki adds policy context, data lineage, congestion reasoning, and user-readable explanation.

## Runtime Use

1. A travel service receives a destination, a visit date, and a radius.
2. The service backend calculates candidates, congestion state, and visit order.
3. The explanation layer loads the canonical pages listed in the service's context bundle.
4. An LLM generates a concise explanation grounded in those pages and the backend's facts.

## Output Boundaries

Allowed:

- Explain why a candidate was selected — which score factors it cleared, and that only quiet candidates are offered at all.
- Explain how the destination's grade was reached, in percentile terms.
- Explain why the visit order is what it is: it minimizes total travel time from a fixed starting point.
- Explain what the reduction rate compares against — the course versus visiting the original destination alone.
- Explain why a fallback was used when congestion coverage is missing.
- Explain public-data compliance decisions.

Not allowed:

- Inventing an attraction the backend did not return.
- Reordering course items, or restating them in an order the backend did not give.
- **Saying the crowded destination was pushed to a later slot.** The original destination is fixed as the first visit; it is never deferred. See [[course-generation-policy]].
- **Giving a time-of-day reason for a visit time.** Visit times come from travel time, not from when a place is quiet.
- Asserting a weather condition. No consumer service supplies one — see [[weather-aware-travel-recommendation]].
- Claiming precise public API facts without source evidence.

## Related Pages

- [[congestion-diagnosis]]
- [[course-generation-policy]]
- [[alternative-scoring]]
- [[raw-derived-data-separation]]
- [[tourapi-korservice2]]
