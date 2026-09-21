---
title: Separate Context Wiki From Services
created: 2026-08-03
updated: 2026-09-22
type: decision
tags:
  - travel-context
  - sdd
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/service-snapshots/hanjeok/course-recommendation.md
confidence: medium
contested: false
contradictions: []
---

# Separate Context Wiki From Services

## Decision

Travel Context Wiki lives in a separate Git repository from the travel services that consume it.

## Reason

Service repositories contain frontend, backend, and runtime harness implementation assets. The context wiki contains source snapshots, policy synthesis, tourism/weather/congestion concepts, and LLM-oriented canonical memory. Separating them keeps runtime code reviews smaller and allows evidence updates without touching product code.

## Consequences

- Product code can vendor, fetch, or retrieve generated summaries later. The first consumer took the package route: Hermes Agent, in its own repository, loads `packages/hanjeok/context-bundle.json` as assembled by `scripts/build-bundle.sh`, and needed no change to the Hanjeok repository.
- Raw source snapshots are versioned independently.
- The wiki has its own harness and Spec Kit workflow.

## Related Pages

- [[travel-context-layer]]
- [[raw-derived-data-separation]]
- [[keep-llm-out-of-ranking]]
