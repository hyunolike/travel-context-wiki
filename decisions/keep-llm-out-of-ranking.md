---
title: Keep LLM Out Of Ranking
created: 2026-08-03
updated: 2026-08-03
type: decision
tags:
  - llm-rag
  - recommendation-policy
  - api-compliance
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/public-tourism-api/2026-openapi-briefing.txt
confidence: medium
contested: false
contradictions: []
---

# Keep LLM Out Of Ranking

## Decision

Travel Context Wiki will not let an LLM decide attraction ranking or course order for consuming services.

## Reason

The service needs deterministic behavior, public-data traceability, and reproducible harness results. LLM output is suitable for explanation and synthesis, not for replacing [[alternative-scoring]] or [[course-generation-policy]].

## Consequences

- Backend recommendation tests remain deterministic.
- LLM prompts must consume backend-generated course facts.
- User-facing explanations can be regenerated without changing the saved course.

## Related Pages

- [[travel-context-layer]]
- [[why-this-place-today]]
- [[alternative-scoring]]
