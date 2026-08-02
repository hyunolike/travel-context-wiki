---
title: Travel Context Layer
created: 2026-08-03
updated: 2026-08-03
type: concept
tags:
  - travel-context
  - course-explanation
  - llm-rag
  - weather-aware-recommendation
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/public-tourism-api/2026-openapi-briefing.txt
confidence: medium
contested: false
contradictions: []
---

# Travel Context Layer

Travel Context Layer is the service pattern where a travel service backend makes deterministic recommendations and the LLM wiki explains those recommendations using preserved tourism, weather, congestion, seasonality, and regional-context evidence.

The LLM wiki must not change ranking results. Ranking belongs to the consuming service's backend. The wiki adds policy context, data lineage, weather interpretation, seasonal context, congestion reasoning, and user-readable explanation.

## Runtime Use

1. A travel service receives destination, visit date, time slot, radius, weather context, and preferences.
2. The service backend calculates candidates, route order, congestion state, and weather fit.
3. The service retrieves relevant wiki pages such as [[weather-aware-travel-recommendation]], [[raw-derived-data-separation]], and [[tourapi-korservice2]].
4. An LLM generates a concise explanation grounded in the retrieved pages.

## Output Boundaries

Allowed:

- Explain why a candidate was selected.
- Explain why a crowded destination is delayed to a later slot.
- Explain why rain, heat, cold, or seasonality changes the recommended experience.
- Explain why a fallback was used when congestion coverage is missing.
- Explain public-data compliance decisions.

Not allowed:

- Inventing a new attraction not returned by the backend.
- Reordering course items without backend approval.
- Claiming precise public API facts without source evidence.
