---
title: Evidence-backed Course Explanation
created: 2026-08-03
updated: 2026-08-03
type: concept
tags:
  - evidence-wiki
  - course-explanation
  - llm-rag
  - hanjeok
sources:
  - raw/hanjeok-design/design-v3.md
  - raw/openapi-briefing/2026-openapi-briefing.txt
confidence: medium
contested: false
contradictions: []
---

# Evidence-backed Course Explanation

Evidence-backed Course Explanation is the service pattern where Hanjeok's backend makes deterministic route recommendations and the LLM wiki explains those recommendations using preserved source evidence.

The LLM wiki must not change ranking results. Ranking belongs to [[alternative-scoring]], [[congestion-diagnosis]], and [[course-generation-policy]]. The wiki adds policy context, data lineage, and user-readable reasoning.

## Runtime Use

1. Hanjeok receives destination, visit date, time slot, radius, and preferences.
2. Hanjeok backend diagnoses congestion and builds a course.
3. The service retrieves relevant wiki pages such as [[raw-derived-data-separation]] and [[tourapi-korservice2]].
4. An LLM generates a concise explanation grounded in the retrieved pages.

## Output Boundaries

Allowed:

- Explain why a candidate was selected.
- Explain why a crowded destination is delayed to a later slot.
- Explain why a fallback was used when congestion coverage is missing.
- Explain public-data compliance decisions.

Not allowed:

- Inventing a new attraction not returned by the backend.
- Reordering course items without backend approval.
- Claiming precise public API facts without source evidence.

