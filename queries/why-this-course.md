---
title: Why This Course
created: 2026-08-03
updated: 2026-08-03
type: query
tags:
  - course-explanation
  - llm-rag
  - recommendation-policy
sources:
  - raw/hanjeok-design/design-v3.md
  - raw/harness/course-recommendation.md
confidence: medium
contested: false
contradictions: []
---

# Why This Course

This query template explains a generated Hanjeok course using backend facts and wiki context.

## Required Inputs

```json
{
  "destination": "경복궁",
  "visitDate": "2026-08-15",
  "timeSlot": "AFTERNOON",
  "diagnosis": "VERY_CROWDED",
  "alternatives": ["북촌한옥마을", "정동길"],
  "courseItems": []
}
```

## Answer Policy

The answer should:

- summarize the original destination's congestion diagnosis using [[congestion-diagnosis]]
- mention that alternatives were selected by [[alternative-scoring]]
- explain time ordering using [[course-generation-policy]]
- avoid claiming that the LLM selected the course

## Related Pages

- [[evidence-backed-course-explanation]]
- [[keep-llm-out-of-ranking]]
- [[course-generation-policy]]

