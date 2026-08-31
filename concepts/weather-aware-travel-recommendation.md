---
title: Weather Aware Travel Recommendation
created: 2026-08-03
updated: 2026-08-19
type: concept
tags:
  - weather
  - seasonality
  - weather-aware-recommendation
  - travel-context
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
confidence: low
contested: true
contradictions: []
---

# Weather Aware Travel Recommendation

Weather Aware Travel Recommendation adds weather and seasonality context to travel explanations without letting the LLM change backend ranking.

The first implementation may use service-provided weather facts such as condition, precipitation probability, temperature, heat/cold warnings, and indoor/outdoor suitability. Later source records under `raw/weather-api/` and `raw/tourism-research/` should strengthen this page.

## Consumer Status

No running service produces the weather facts this page explains. Hanjeok, the only implemented consumer, has no weather code and no weather section in its design document, so `weather` was removed from `packages/hanjeok/context-bundle.json` on 2026-08-19. The `packages/generic-travel/` package still lists it, but no service implements that package.

This page and `records/weather/rules.json` are kept rather than deleted, for the same reason `raw/` is preserved: the evidence outlives the absence of a consumer. Nothing here may be asserted in an explanation until a backend supplies the facts.

## Explanation Policy

The LLM may explain:

- why rain makes indoor or short-walk alternatives more suitable
- why heat or cold changes recommended visit duration
- why seasonal context changes the user's expectation
- why a backend weather fallback was triggered

The LLM must not:

- invent weather values
- override backend-provided weather classification
- claim research-backed weather behavior without a source under `raw/tourism-research/`

## Related Pages

- [[travel-context-layer]]
- [[why-this-place-today]]
- [[keep-llm-out-of-ranking]]
