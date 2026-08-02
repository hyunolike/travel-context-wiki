---
title: Why This Place Today
created: 2026-08-03
updated: 2026-08-03
type: query
tags:
  - course-explanation
  - llm-rag
  - recommendation-policy
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/service-snapshots/hanjeok/course-recommendation.md
confidence: medium
contested: false
contradictions: []
---

# Why This Place Today

This query template explains why a travel service recommended a place or route for a specific date, time slot, weather condition, and user preference.

## Required Inputs

```json
{
  "destination": "경복궁",
  "visitDate": "2026-08-15",
  "timeSlot": "AFTERNOON",
  "weather": {
    "condition": "RAIN",
    "temperatureC": 27
  },
  "diagnosis": "VERY_CROWDED",
  "alternatives": ["북촌한옥마을", "정동길"],
  "courseItems": []
}
```

## Answer Policy

The answer should:

- summarize the original destination's congestion diagnosis using [[congestion-diagnosis]]
- mention that alternatives were selected by [[alternative-scoring]]
- explain weather fit or weather fallback using [[weather-aware-travel-recommendation]]
- explain time ordering using [[course-generation-policy]]
- avoid claiming that the LLM selected the course

## Related Pages

- [[travel-context-layer]]
- [[weather-aware-travel-recommendation]]
- [[keep-llm-out-of-ranking]]
- [[course-generation-policy]]
