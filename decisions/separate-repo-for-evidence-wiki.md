---
title: Separate Repo For Evidence Wiki
created: 2026-08-03
updated: 2026-08-03
type: decision
tags:
  - evidence-wiki
  - sdd
  - hanjeok
sources:
  - raw/hanjeok-design/design-v3.md
  - raw/harness/course-recommendation.md
confidence: medium
contested: false
contradictions: []
---

# Separate Repo For Evidence Wiki

## Decision

Hanjeok Evidence Wiki lives in a separate Git repository from the Hanjeok product monorepo.

## Reason

The product repo contains frontend, backend, and harness implementation assets. The evidence wiki contains source snapshots, policy synthesis, and LLM-oriented canonical memory. Separating them keeps runtime code reviews smaller and allows evidence updates without touching product code.

## Consequences

- Product code can vendor or fetch generated summaries later.
- Raw source snapshots are versioned independently.
- The wiki has its own harness and Spec Kit workflow.

## Related Pages

- [[evidence-backed-course-explanation]]
- [[raw-derived-data-separation]]
- [[keep-llm-out-of-ranking]]

