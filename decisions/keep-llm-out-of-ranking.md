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
  - raw/hanjeok-design/design-v3.md
  - raw/openapi-briefing/2026-openapi-briefing.txt
confidence: medium
contested: false
contradictions: []
---

# Keep LLM Out Of Ranking

## Decision

Hanjeok will not let an LLM decide attraction ranking or course order in MVP.

## Reason

The service needs deterministic behavior, public-data traceability, and reproducible harness results. LLM output is suitable for explanation and synthesis, not for replacing [[alternative-scoring]] or [[course-generation-policy]].

## Consequences

- Backend recommendation tests remain deterministic.
- LLM prompts must consume backend-generated course facts.
- User-facing explanations can be regenerated without changing the saved course.

## Related Pages

- [[evidence-backed-course-explanation]]
- [[why-this-course]]
- [[alternative-scoring]]

