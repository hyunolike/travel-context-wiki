---
title: Weather Aware Travel Recommendation
created: 2026-08-03
updated: 2026-09-22
type: concept
tags:
  - weather
  - seasonality
  - weather-aware-recommendation
  - travel-context
sources:
  - raw/weather-api/kma-vilage-fcst-guide-260623.txt
confidence: low
contested: true
contradictions:
  - "Until 2026-09-22 this page cited raw/service-snapshots/hanjeok/design-v3.md as its only source. That document contains no weather content at all; the citation was removed rather than kept as support."
---

# Weather Aware Travel Recommendation

Weather Aware Travel Recommendation adds weather and seasonality context to travel explanations without letting the LLM change backend ranking.

The first implementation may use service-provided weather facts such as condition, precipitation probability, temperature, and indoor/outdoor suitability. [[kma-short-term-forecast-api]] records the forecast contract those facts would come from: sky state, precipitation type and probability, and hourly and daily temperatures. It carries no heat or cold warning and no suitability judgement, so those two remain facts a backend must supply from a source this wiki does not yet hold. Research under `raw/tourism-research/` would still be needed before any claim about how travellers respond to weather.

## Consumer Status

No running service produces the weather facts this page explains. Hanjeok, the only implemented consumer, has no weather code and no weather section in its design document, so `weather` was removed from `packages/hanjeok/context-bundle.json` on 2026-08-19. The `packages/generic-travel/` package still lists it, but no service implements that package.

Air quality is in the same position. [[air-quality-station-api]] captures where the monitoring stations are, but readings are live data and are not collected here, so the wiki cannot say today's air is good or bad.

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
- [[air-quality-station-api]]
- [[kma-short-term-forecast-api]]
